{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.UserRepository
    ( runUserRepositoryDb
    ) where

import Database.Persist (Entity, Filter, SelectOpt, selectList)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret)
import Polysemy.Reader (Reader, ask)

import App.Effects.UserRepository (UserRepository (..))
import Infra.Persistence.Models (UserEntity, toDomainUser)

runUserRepositoryDb :: Members '[Reader ConnectionPool, Embed IO] r => InterpreterFor UserRepository r
runUserRepositoryDb = interpret $ \case
  GetUsers -> do
    pool <- ask
    fmap toDomainUser <$> embed
      (runSqlPool @SqlBackend
        (selectList
          ([] :: [Filter UserEntity])
          ([] :: [SelectOpt UserEntity]))
        pool :: IO [Entity UserEntity])
