module App.ProductCreation
    ( NewProduct(..)
    ) where

import App.Support (Money)

-- App-level payload used by use-cases/repositories to create products.
data NewProduct = NewProduct
    { sellerId :: Int
    , title :: String
    , description :: String
    , price :: Money
    }
    deriving (Show, Eq)
