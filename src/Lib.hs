{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
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
import Polysemy (Embed, Sem)
import Polysemy (runM)
import Polysemy.Error (Error, runError)
import Polysemy.Reader (Reader, runReader)
import Servant (Handler, Proxy(..), ServerError, ServerT, err400, err404, errBody, errHeaders, errHTTPCode, throwError, (:<|>) (..), hoistServer, serve)
import Servant.OpenApi (toOpenApi)
import System.Environment (lookupEnv)
import System.Exit (die)

import API.Routes (API, ProductAPI, api, productApi)
import App.Error (AppError (..))
import App.Effects.ProductRepository (ProductRepository)
import App.Handlers.Product (createProductHandler, getProductByIdHandler, listProductsHandler, updateProductByIdHandler)
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

type AppEffects = '[ProductRepository, Reader ConnectionPool, Error AppError, Embed IO]

serverSem :: ServerT API (Sem AppEffects)
serverSem = (createProductHandler :<|> (listProductsHandler :<|> (getProductByIdHandler :<|> updateProductByIdHandler))) :<|> pure openApiSpec

semToHandler :: ConnectionPool -> Sem AppEffects a -> Handler a
semToHandler pool sem =
  do
    result <- liftIO $ sem
      & runProductRepositoryDb 
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
openApiSpec = toOpenApi (productApi :: Proxy ProductAPI)

getConnectionString :: IO ConnectionString
getConnectionString = do
  value <- lookupEnv "DATABASE_URL"
  case value of
    Just url -> pure (fromString url)
    Nothing -> die "Missing required environment variable: DATABASE_URL"
