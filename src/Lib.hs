{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
module Lib
    ( startApp
  , app
    ) where

import Prelude hiding (log)
import Control.Monad.Logger (runNoLoggingT, runStdoutLoggingT)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Colog.Core.Action (cmap)
import Colog.Core.IO (logStringStdout)
import Colog.Polysemy (Log, log, runLogAction)
import Data.Aeson (encode, object, (.=))
import Data.String (fromString)
import Data.Function ((&))
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (ConnectionPool, runMigration, runSqlPool)
import Data.OpenApi (OpenApi)
import Network.Wai
import Network.Wai.Handler.Warp
import Polysemy (Embed, Member, Members, Sem)
import Polysemy (runM)
import Polysemy.Error (Error, runError)
import Polysemy.Reader (Reader, runReader)
import Servant (NoContent (NoContent), Proxy(..), ServerError, ServerT, err400, err404, errBody, errHeaders, errHTTPCode, throwError, hoistServer, serve)
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
  runSettings (setPort port (setHost (fromString host) defaultSettings)) (app pool loggingEnabled)

app :: ConnectionPool -> Bool -> Application
app pool loggingEnabled = serve api (hoistServer api (semToHandler pool loggingEnabled) serverSem)

data Severity = Debug | Info | Warning | Error
  deriving (Show)

data AppLog = AppLog
  { appLogSeverity :: Severity
  , appLogMessage :: String
  }

renderAppLog :: AppLog -> String
renderAppLog appLog = "[" ++ show (appLogSeverity appLog) ++ "] " ++ appLogMessage appLog

logInfoMsg :: Member (Log AppLog) r => String -> Sem r ()
logInfoMsg msg = log (AppLog Info msg)

type AppEffects r = Members '[Log AppLog, ProductRepository, CartRepository, Reader ConnectionPool, Error AppError, Embed IO] r

serverSem ::AppEffects r => ServerT API (Sem r)
serverSem =
  ApiRoutes
    { productsRoutes =
        ProductRoutes
          { createProductRoute = \req -> logInfoMsg "POST /products" >> createProductHandler req
          , listProductsRoute = logInfoMsg "GET /products" >> listProductsHandler
          , getProductByIdRoute = \productId -> logInfoMsg "GET /products/{id}" >> getProductByIdHandler productId
          , updateProductByIdRoute = \productId req -> logInfoMsg "PUT /products/{id}" >> updateProductByIdHandler productId req
          , deleteProductByIdRoute = \productId -> logInfoMsg "DELETE /products/{id}" >> deleteProductByIdHandler productId >> pure NoContent
          }
    , cartRoutes = \userId ->
        CartByUserRoutes
          { getCartRoute = logInfoMsg "GET /cart/{userId}" >> getCartHandler userId
          , deleteCartRoute = logInfoMsg "DELETE /cart/{userId}" >> deleteCartHandler userId
          , addProductToCartRoute = \req -> logInfoMsg "POST /cart/{userId}/items" >> addProductToCartHandler userId req
          , deleteCartItemRoute = \cartItemId -> logInfoMsg "DELETE /cart/{userId}/items/{cartItemId}" >> deleteCartItemHandler userId cartItemId
          }
    , openApiJsonRoute = pure openApiSpec
    }

-- this sem->handler interpreter purposely doesn't have a top level signature to let the 
-- type system infer it, because it will depend on the order or composition of the interpreters in semToHandler
-- and letting the type be inferred gives flexibility on the order.
-- | Sem program to Servant Handler Interpreter/natural transformation.. 
-- It runs the Sem program by interpreting the effects stack against the db connection pool, 
-- and translating AppErrors into Servant ServerErrors.
semToHandler pool loggingEnabled sem =
  do
    result <- liftIO $
      sem
        & (if loggingEnabled
             then runLogAction @IO (cmap renderAppLog logStringStdout)
             else runLogAction @IO mempty)
        & runProductRepositoryDb
        & runCartRepositoryDb
        & runReader pool
        & runError
        & runM
    either (throwError . appErrorToServerError) pure result

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
