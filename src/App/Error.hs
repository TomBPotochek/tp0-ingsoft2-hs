module App.Error
    ( AppError(..)
    ) where

data AppError
    = ProductNotFound Int
    | CartItemNotFound Int Int
    | InvalidInput (Maybe String) String
    deriving (Show, Eq)
