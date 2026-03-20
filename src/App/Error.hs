module App.Error
    ( AppError(..)
    ) where

data AppError
    = ProductNotFound Int
    deriving (Show, Eq)
