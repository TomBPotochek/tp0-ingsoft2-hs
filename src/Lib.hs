{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
module Lib
    ( startApp
  , app
  , unexpectedExceptionTo500Middleware
    ) where

import Control.Exception (SomeException, try)
import Control.Monad.Logger (runNoLoggingT, runStdoutLoggingT)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Char8 as BS8
import Data.Function ((&))
import Data.OpenApi (OpenApi)
import Data.String (fromString)
import Data.Time.Clock (diffUTCTime, getCurrentTime)
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (ConnectionPool, runMigration, runSqlPool)
import Network.Wai
import Network.Wai.Handler.Warp
import Polysemy (Embed, Members, Sem)
import Polysemy (runM)
import Polysemy.Error (Error, runError)
import Polysemy.Reader (Reader, runReader)
import Servant (NoContent (NoContent), Proxy(..), ServerError, ServerT, err400, err404, errBody, errHeaders, errHTTPCode, throwError, hoistServer, serveWithContext, Context(..))
import Servant.Server (defaultErrorFormatters, ErrorFormatters(..), ErrorFormatter)
import Servant.OpenApi (toOpenApi)
import System.Environment (lookupEnv)
import System.Exit (die)
import Text.Read (readMaybe)

import API.Routes (API, ApiRoutes (..), CartByUserRoutes (..), OpenApiAPI, ProductRoutes (..), api)
import App.Effects.CartRepository (CartRepository)
import App.Error (AppError (..))
import App.Effects.ProductRepository (ProductRepository)
import App.Handlers.Cart (addProductToCartHandler, deleteCartHandler, deleteCartItemHandler, getCartHandler)
import App.Handlers.Product (createProductHandler, deleteProductByIdHandler, getProductByIdHandler, listProductsHandler, updateProductByIdHandler)
import Infra.Persistence.CartRepository (runCartRepositoryDb)
import Infra.Persistence.Models (migrateAll)
import Infra.Persistence.ProductRepository (runProductRepositoryDb)
import Infra.Persistence.Seed (seedDb)

startApp :: IO ()
startApp = do
  connStr <- getConnectionString
  environment <- lookupEnv "ENVIRONMENT"
  let isDevelopment = environment == Just "development"
      isProduction = environment == Just "production"
  loggingEnabled <- getLoggingEnabled isProduction
  pool <- if loggingEnabled
    then runStdoutLoggingT $ createPostgresqlPool connStr 10
    else runNoLoggingT $ createPostgresqlPool connStr 10
  if loggingEnabled
    then runStdoutLoggingT $ runSqlPool (runMigration migrateAll) pool
    else runNoLoggingT $ runSqlPool (runMigration migrateAll) pool
  host <- getServerHost
  port <- getServerPort
  when isDevelopment (seedDb pool)
  let settings =
        defaultSettings
          & setHost (fromString host)
          & setPort port
          & setOnExceptionResponse defaultOnExceptionResponse
  runSettings settings (app pool loggingEnabled)


-- Custom error formatter for JSON parse errors
customBodyParserErrorFormatter :: ErrorFormatter
customBodyParserErrorFormatter _typeRep req errStr =
  let detail = "Invalid JSON: " ++ errStr
      instancePath = show $ pathInfo req
  in problemDetails err400 "Bad Request" detail instancePath

-- Generic RFC 7807 error formatter for all other errors
genericProblemErrorFormatter :: ServerError -> String -> Request -> ServerError
genericProblemErrorFormatter baseError detail req =
  problemDetails baseError (statusMessage baseError) detail (show $ pathInfo req)

statusMessage :: ServerError -> String
statusMessage err =
  case errHTTPCode err of
    400 -> "Bad Request"
    404 -> "Not Found"
    405 -> "Method Not Allowed"
    406 -> "Not Acceptable"
    415 -> "Unsupported Media Type"
    _   -> "Internal Server Error"

customErrorFormatters :: ErrorFormatters
customErrorFormatters = defaultErrorFormatters
  { bodyParserErrorFormatter = customBodyParserErrorFormatter
  , urlParseErrorFormatter = \_ req errStr -> genericProblemErrorFormatter err400 errStr req
  , notFoundErrorFormatter = \req -> genericProblemErrorFormatter err404 "Not Found" req
  , headerParseErrorFormatter = \_ req errStr -> genericProblemErrorFormatter err400 errStr req
  }

customContext :: Context '[ErrorFormatters]
customContext = customErrorFormatters :. EmptyContext

app :: ConnectionPool -> Bool -> Application
app pool loggingEnabled =
    (if loggingEnabled then requestLoggingMiddleware else id)
        (unexpectedExceptionTo500Middleware (serveWithContext api customContext (hoistServer api (semToHandler pool) serverSem)))

type AppEffects r = Members '[ProductRepository, CartRepository, Reader ConnectionPool, Error AppError, Embed IO] r

serverSem ::AppEffects r => ServerT API (Sem r)
serverSem =
  ApiRoutes
    { productsRoutes =
        ProductRoutes
          { createProductRoute = createProductHandler
          , listProductsRoute = listProductsHandler
          , getProductByIdRoute = getProductByIdHandler
          , updateProductByIdRoute = updateProductByIdHandler
          , deleteProductByIdRoute = \productId -> deleteProductByIdHandler productId >> pure NoContent
          }
    , cartRoutes = \userId ->
        CartByUserRoutes
          { getCartRoute = getCartHandler userId
          , deleteCartRoute = deleteCartHandler userId
          , addProductToCartRoute = addProductToCartHandler userId
          , deleteCartItemRoute = deleteCartItemHandler userId
          }
    , openApiJsonRoute = pure openApiSpec
    }

-- this sem->handler interpreter purposely doesn't have a top level signature to let the 
-- type system infer it, because it will depend on the order or composition of the interpreters in semToHandler
-- and letting the type be inferred gives flexibility on the order.
-- | Sem program to Servant Handler Interpreter/natural transformation.. 
-- It runs the Sem program by interpreting the effects stack against the db connection pool, 
-- and translating AppErrors into Servant ServerErrors.
semToHandler pool sem =
  do
    result <- liftIO $
      sem
        & runProductRepositoryDb
        & runCartRepositoryDb
        & runReader pool
        & runError
        & runM
    either (throwError . appErrorToServerError) pure result

requestLoggingMiddleware :: Middleware
requestLoggingMiddleware inner req respond = do
  start <- getCurrentTime
  inner req $ \res -> do
    end <- getCurrentTime
    let method = BS8.unpack (requestMethod req)
        path = BS8.unpack (rawPathInfo req)
        status = show (responseStatus res)
        durationMs = realToFrac (diffUTCTime end start) * 1000 :: Double
    putStrLn ("[HTTP] " ++ method ++ " " ++ path ++ " -> " ++ status ++ " (" ++ show durationMs ++ " ms)")
    respond res

unexpectedExceptionTo500Middleware :: Middleware
unexpectedExceptionTo500Middleware inner req respond = do
  result <- try (inner req respond) :: IO (Either SomeException ResponseReceived)
  case result of
    Right received -> pure received
    Left exception -> respond (defaultOnExceptionResponse exception)

getLoggingEnabled :: Bool -> IO Bool
getLoggingEnabled isProduction = do
  value <- lookupEnv "LOG_ENABLED"
  case fmap parseBool value of
    Just (Just b) -> pure b
    _ -> pure (not isProduction)

parseBool :: String -> Maybe Bool
parseBool raw =
  case raw of
    "1" -> Just True
    "0" -> Just False
    "true" -> Just True
    "false" -> Just False
    "yes" -> Just True
    "no" -> Just False
    "on" -> Just True
    "off" -> Just False
    "TRUE" -> Just True
    "FALSE" -> Just False
    "YES" -> Just True
    "NO" -> Just False
    "ON" -> Just True
    "OFF" -> Just False
    _ -> Nothing

appErrorToServerError :: AppError -> ServerError
appErrorToServerError appError =
  case appError of
    ProductNotFound productId ->
      problemDetails
        err404
        "Not Found"
        ("Product with id " ++ show productId ++ " not found")
        ("/products/" ++ show productId)
    CartItemNotFound userId cartItemId ->
      problemDetails
        err404
        "Not Found"
        ("Cart item with id " ++ show cartItemId ++ " not found in cart of user " ++ show userId)
        ("/cart/" ++ show userId ++ "/items/" ++ show cartItemId)
    InvalidInput maybeField detail ->
      problemDetails
        err400
        "Bad Request"
        (formatValidationDetail maybeField detail)
        "/products"

problemDetails :: ServerError -> String -> String -> String -> ServerError
problemDetails baseError problemTitle problemDetail problemInstance =
  baseError
    { errBody =
        encode
          ( object
              [ "type" .= ("about:blank" :: String)
              , "title" .= problemTitle
              , "status" .= statusCode baseError
              , "detail" .= problemDetail
              , "instance" .= problemInstance
              ]
          )
    , errHeaders = ("Content-Type", "application/problem+json") : errHeaders baseError
    }

statusCode :: ServerError -> Int
statusCode = errHTTPCode

formatValidationDetail :: Maybe String -> String -> String
formatValidationDetail maybeField detail =
  case maybeField of
    Nothing -> detail
    Just field -> field ++ ": " ++ detail

openApiSpec :: OpenApi
openApiSpec = toOpenApi (Proxy :: Proxy OpenApiAPI)

getConnectionString :: IO ConnectionString
getConnectionString = do
  value <- lookupEnv "DATABASE_URL"
  case value of
    Just url -> pure (fromString url)
    Nothing -> die "Missing required environment variable: DATABASE_URL"

getServerHost :: IO String
getServerHost = do
  value <- lookupEnv "HOST"
  pure $ maybe "0.0.0.0" id value

getServerPort :: IO Int
getServerPort = do
  value <- lookupEnv "PORT"
  case value >>= readMaybe of
    Just p -> pure p
    Nothing -> pure 1234
