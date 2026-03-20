module App.Error
    ( AppError(..)
    ) where

data AppError
    = ProductNotFound Int
    | InvalidInput (Maybe String) String
    deriving (Show, Eq)
