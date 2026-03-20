{-# LANGUAGE DataKinds #-}
module Lib
    ( startApp
  , app
    ) where

import Control.Monad.Logger (runNoLoggingT)
import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString.Lazy.Char8 as L8
import Data.String (fromString)
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (ConnectionPool, runMigration, runSqlPool)
import Data.OpenApi (OpenApi)
import Network.Wai
import Network.Wai.Handler.Warp
import Polysemy (Embed, Sem)
import Polysemy (runM)
import Polysemy.Error (Error, runError, throw)
import Polysemy.Reader (Reader, runReader)
import Servant (Handler, Proxy(..), ServerError, ServerT, err404, errBody, throwError, (:<|>) (..), hoistServer, serve)
import Servant.OpenApi (toOpenApi)
import System.Environment (lookupEnv)
import System.Exit (die)

import API.Routes (API, ProductAPI, api, productApi)
import API.DTO.Product (ProductDTO)
import App.Effects.ProductRepository (ProductRepository)
import App.Handlers.Product (createProductHandler, getProductByIdHandler, listProductsHandler)
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

type AppEffects = '[ProductRepository, Reader ConnectionPool, Error ServerError, Embed IO]

serverSem :: ServerT API (Sem AppEffects)
serverSem = (createProductHandler :<|> (listProductsHandler :<|> getProductByIdServer)) :<|> pure openApiSpec

getProductByIdServer :: Int -> Sem AppEffects ProductDTO
getProductByIdServer productId = do
  maybeProduct <- getProductByIdHandler productId
  case maybeProduct of
    Just foundProduct -> pure foundProduct
    Nothing -> throw notFoundError
  where
    notFoundError = err404 {errBody = L8.pack ("Product with id " ++ show productId ++ " not found")}

semToHandler :: ConnectionPool -> Sem AppEffects a -> Handler a
semToHandler pool sem =
  do
    result <- liftIO $ runM (runError (runReader pool (runProductRepositoryDb sem)))
    either throwError pure result

openApiSpec :: OpenApi
openApiSpec = toOpenApi (productApi :: Proxy ProductAPI)

getConnectionString :: IO ConnectionString
getConnectionString = do
  value <- lookupEnv "DATABASE_URL"
  case value of
    Just url -> pure (fromString url)
    Nothing -> die "Missing required environment variable: DATABASE_URL"
