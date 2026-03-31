module App.ProductUpdate
    ( ProductUpdate(..)
    ) where

import App.Support (Money)

-- App-level payload used to update mutable product fields.
data ProductUpdate = ProductUpdate
    { title :: String
    , description :: String
    , price :: Money
    }
    deriving (Show, Eq)
