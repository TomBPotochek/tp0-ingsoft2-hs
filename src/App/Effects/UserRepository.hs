{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.UserRepository
    ( UserRepository(..)
    , getUsers
    , runUserRepositoryDb
    ) where

import Database.Persist (Entity, Filter, SelectOpt, selectList)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret, makeSem)
import Polysemy.Reader (Reader, ask)

import Domain.User (User)
import Infra.Persistence.Models (UserEntity, toDomainUser)

data UserRepository m a where
  GetUsers :: UserRepository m [User]

makeSem ''UserRepository

runUserRepositoryDb :: Members '[Reader ConnectionPool, Embed IO] r => InterpreterFor UserRepository r
runUserRepositoryDb = interpret $ \case
  GetUsers ->
    do
      pool <- ask
      fmap toDomainUser <$> embed
        (runSqlPool @SqlBackend
          (selectList
            ([] :: [Filter UserEntity])
            ([] :: [SelectOpt UserEntity]))
          pool :: IO [Entity UserEntity])
