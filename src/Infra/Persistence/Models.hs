{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Infra.Persistence.Models
    ( UserEntity(..)
    , UserEntityId
    , migrateAll
    , toDomainUser
    ) where

import Data.Text (Text)
import Database.Persist (Entity(..))
import Database.Persist.Sql (fromSqlKey)
import Database.Persist.TH

import Domain.User (User(..), UserId(..))

-- Persistent schema (Postgres backend will use these entities).
share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
UserEntity sql=users
    firstName Text
    lastName Text
    deriving Show Eq
|]

toDomainUser :: Entity UserEntity -> User
toDomainUser (Entity userKey user) =
    User
        { userId = UserId (fromSqlKey userKey)
        , userFirstName = userEntityFirstName user
        , userLastName = userEntityLastName user
        }
