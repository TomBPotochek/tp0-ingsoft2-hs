{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes
    ( API
    , api
    ) where

import Servant (Get, JSON, Proxy(..), (:>))

import API.DTO.User (UserDTO)

type API = "users" :> Get '[JSON] [UserDTO]

api :: Proxy API
api = Proxy
