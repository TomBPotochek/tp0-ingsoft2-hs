{-# LANGUAGE DeriveGeneric #-}

module API.DTO.User
    ( UserDTO(..)
    , toDTO
    ) where

import Data.Aeson (ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

import Domain.User (User(..), UserId(..))

-- HTTP response shape for users.
data UserDTO = UserDTO
  { id :: Int
  , firstName :: Text
  , lastName :: Text
  } deriving (Eq, Show, Generic)

instance ToJSON UserDTO

toDTO :: User -> UserDTO
toDTO user =
  UserDTO
    { id = userIdToInt (userId user)
    , firstName = userFirstName user
    , lastName = userLastName user
    }

userIdToInt :: UserId -> Int
userIdToInt (UserId value) = fromIntegral value
