module App.Error
    ( AppError(..)
    ) where

data AppError
    = -- | The id of the product that was not found.
    ProductNotFound Int
    | -- | The id of the cart item that was not found.
      CartItemNotFound Int Int
    | -- | Invalid input provided.  
      -- The first parameter is an optional string with the 
      -- field name that caused the error (eg during parsing JSON).  
      -- The second parameter is a short description or detail about the invalid input.\n\n
      -- # Examples 
      -- `InvalidInput (Just "price") "Price must be a positive number"`
      InvalidInput (Maybe String) String
    deriving (Show, Eq)
