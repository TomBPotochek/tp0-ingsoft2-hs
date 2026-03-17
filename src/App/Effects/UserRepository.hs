{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.UserRepository
    ( UserRepository(..)
    , getUsers
    ) where

import Polysemy (makeSem)

import Domain.User (User)

data UserRepository m a where
  GetUsers :: UserRepository m [User]

makeSem ''UserRepository
