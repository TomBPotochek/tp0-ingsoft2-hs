module App.ProductCreation
    ( NewProduct(..)
    ) where

-- App-level payload used by use-cases/repositories to create products.
data NewProduct = NewProduct
    { sellerId :: Int
    , title :: String
    , description :: String
    , price :: Double
    }
    deriving (Show, Eq)
