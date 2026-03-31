module Domain.CartItem
    ( CartItem(..)
    ) where

import Data.Time (UTCTime)
import App.Support (Money)

data CartItem = CartItem
    { cartItemId :: Int
    , cartItemUserId :: Int
    , cartItemProductId :: Int
    , cartItemTitle :: String
    , cartItemUnitPrice :: Money
    , cartItemAddedAt :: UTCTime
    }
    deriving (Show, Eq)
