module Domain.User
    ( User(..)
    , UserId(..)
    ) where

import Data.Int (Int64)
import Data.Text (Text)

newtype UserId = UserId Int64
  deriving (Eq, Show)

data User = User
  { userId :: UserId
  , userFirstName :: Text
  , userLastName :: Text
  } deriving (Eq, Show)