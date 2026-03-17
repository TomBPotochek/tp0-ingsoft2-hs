{-# LANGUAGE DataKinds #-}
module Lib
    ( startApp
    ) where

import Control.Monad.Logger (runNoLoggingT)
import Control.Monad.IO.Class (liftIO)
import Data.String (fromString)
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (ConnectionPool, runMigration, runSqlPool)
import Network.Wai
import Network.Wai.Handler.Warp
import Polysemy (Embed, Sem)
import Polysemy (runM)
import Polysemy.Reader (Reader, runReader)
import Servant (Handler, ServerT, hoistServer, serve)
import System.Environment (lookupEnv)
import System.Exit (die)

import API.DTO.User (toDTO)
import API.Routes (API, api)
import App.Effects.UserRepository (UserRepository, getUsers)
import Infra.Persistence.Models (migrateAll)
import Infra.Persistence.Seed (seedDb)
import Infra.Persistence.UserRepository (runUserRepositoryDb)

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

type AppEffects = '[UserRepository, Reader ConnectionPool, Embed IO]

serverSem :: ServerT API (Sem AppEffects)
serverSem = do
  users <- getUsers
  pure (toDTO <$> users)

semToHandler :: ConnectionPool -> Sem AppEffects a -> Handler a
semToHandler pool sem =
  liftIO $ runM (runReader pool (runUserRepositoryDb sem))

getConnectionString :: IO ConnectionString
getConnectionString = do
  value <- lookupEnv "DATABASE_URL"
  case value of
    Just url -> pure (fromString url)
    Nothing -> die "Missing required environment variable: DATABASE_URL"
