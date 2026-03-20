{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
module Lib
    ( startApp
  , app
    ) where

import Control.Monad.Logger (runNoLoggingT)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.String (fromString)
import Data.Function ((&))
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (ConnectionPool, runMigration, runSqlPool)
import Data.OpenApi (OpenApi)
import Network.Wai
import Network.Wai.Handler.Warp
import Polysemy (Embed, Sem, Members)
import Polysemy (runM)
import Polysemy.Error (Error, runError)
import Polysemy.Reader (Reader, runReader)
import Servant (NoContent (NoContent), Proxy(..), ServerError, ServerT, err400, err404, errBody, errHeaders, errHTTPCode, throwError, hoistServer, serve)
import Servant.OpenApi (toOpenApi)
import System.Environment (lookupEnv)
import System.Exit (die)

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
  pool <- runNoLoggingT $ createPostgresqlPool connStr 10
  runNoLoggingT $ runSqlPool (runMigration migrateAll) pool
  shouldSeed <- lookupEnv "ENVIRONMENT"
  case shouldSeed of
    Just "development" -> seedDb pool
    _                  -> pure ()
  run 1234 (app pool)

app :: ConnectionPool -> Application
app pool = serve api (hoistServer api (semToHandler pool) serverSem)

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
    result <- liftIO $ sem
      & runProductRepositoryDb 
      & runCartRepositoryDb
      & runReader pool 
      & runError 
      & runM 
    either (throwError . appErrorToServerError) pure result

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
