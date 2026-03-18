module Domain.Product
    ( Product(..)
    ) where

import Data.Time (UTCTime)

data Product = Product
    { productId :: Int
    , productSellerId :: Int
    , productTitle :: String
    , productDescription :: String
    , productPrice :: Double
    , productCreatedAt :: UTCTime
    , productUpdatedAt :: UTCTime
    }
    deriving (Show, Eq)
