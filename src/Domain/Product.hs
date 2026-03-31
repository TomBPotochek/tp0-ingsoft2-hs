module Domain.Product
    ( Product(..)
    ) where

import Data.Time (UTCTime)
import App.Support (Money)

data Product = Product
    { productId :: Int
    , productSellerId :: Int
    , productTitle :: String
    , productDescription :: String
    , productPrice :: Money
    , productCreatedAt :: UTCTime
    , productUpdatedAt :: UTCTime
    }
    deriving (Show, Eq)
