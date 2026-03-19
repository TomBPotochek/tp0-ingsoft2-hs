{-# LANGUAGE OverloadedStrings #-}

module Integration.Support
    ( withIntegrationApp
    , mkIntegrationApp
    ) where

import Control.Monad.Logger (runNoLoggingT)
import Data.String (fromString)
import Database.Persist.Postgresql (ConnectionString, createPostgresqlPool)
import Database.Persist.Sql (runMigration, runSqlPool)
import Network.Wai (Application)
import qualified Network.Wai.Handler.Warp as Warp
import System.Environment (lookupEnv)

import Infra.Persistence.Models (migrateAll)
import Lib (app)

withIntegrationApp :: (Warp.Port -> IO a) -> IO a
withIntegrationApp action =
    Warp.testWithApplication mkIntegrationApp action

mkIntegrationApp :: IO Application
mkIntegrationApp = do
    connStr <- getIntegrationConnectionString
    pool <- runNoLoggingT (createPostgresqlPool connStr 5)
    runNoLoggingT (runSqlPool (runMigration migrateAll) pool)
    pure (app pool)

getIntegrationConnectionString :: IO ConnectionString
getIntegrationConnectionString = do
    value <- lookupEnv "INTEGRATION_DATABASE_URL"
    pure (fromString (maybe defaultIntegrationDatabaseUrl id value))

defaultIntegrationDatabaseUrl :: String
defaultIntegrationDatabaseUrl = "postgresql://integration_user:integration_pass@localhost:5432/integration_db"
