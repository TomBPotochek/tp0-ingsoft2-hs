module Domain.CartItem
    ( CartItem(..)
    ) where

import Data.Time (UTCTime)

data CartItem = CartItem
    { cartItemId :: Int
    , cartItemUserId :: Int
    , cartItemProductId :: Int
    , cartItemTitle :: String
    , cartItemUnitPrice :: Double
    , cartItemAddedAt :: UTCTime
    }
    deriving (Show, Eq)
