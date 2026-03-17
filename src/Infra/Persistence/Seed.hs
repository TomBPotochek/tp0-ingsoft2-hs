{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.Seed
    ( seedDb
    ) where

import Database.Persist (Filter)
import Database.Persist.Sql (ConnectionPool, deleteWhere, insertMany_, runSqlPool)
import Infra.Persistence.Models (UserEntity (..))

seedDb :: ConnectionPool -> IO ()
seedDb pool = do
    runSqlPool (deleteWhere ([] :: [Filter UserEntity])) pool
    runSqlPool (insertMany_ seedUsers) pool

seedUsers :: [UserEntity]
seedUsers =
    [ UserEntity "Ada" "Lovelace"
    , UserEntity "Alan" "Turing"
    , UserEntity "Grace" "Hopper"
    ]