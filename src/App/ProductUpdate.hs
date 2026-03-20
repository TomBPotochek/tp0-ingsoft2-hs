module App.ProductUpdate
    ( ProductUpdate(..)
    ) where

-- App-level payload used to update mutable product fields.
data ProductUpdate = ProductUpdate
    { title :: String
    , description :: String
    , price :: Double
    }
    deriving (Show, Eq)
