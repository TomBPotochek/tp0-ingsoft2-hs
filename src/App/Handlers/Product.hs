module App.Handlers.Product
    ( createProductHandler
    , getProductByIdHandler
    , listProductsHandler
    ) where

import API.DTO.Product (CreateProductRequest (..), ProductDTO, toDTO, toNewProduct)
import App.Error (AppError (..))
import App.Effects.ProductRepository (ProductRepository, createProduct, getProductById, listProducts)
import Data.Char (isSpace)
import Polysemy (Member, Members, Sem)
import Polysemy.Error (Error, throw)

createProductHandler :: Members '[ProductRepository, Error AppError] r => CreateProductRequest -> Sem r ProductDTO
createProductHandler req = do
    validateCreateProductRequest req
    toDTO <$> createProduct (toNewProduct req)

listProductsHandler :: Member ProductRepository r => Sem r [ProductDTO]
listProductsHandler = map toDTO <$> listProducts

getProductByIdHandler :: Members '[ProductRepository, Error AppError] r => Int -> Sem r ProductDTO
getProductByIdHandler productId = do
    maybeProduct <- getProductById productId
    case maybeProduct of
        Just foundProduct -> pure (toDTO foundProduct)
        Nothing -> throw (ProductNotFound productId)

validateCreateProductRequest :: Member (Error AppError) r => CreateProductRequest -> Sem r ()
validateCreateProductRequest req
    | null (trim (createProductTitle req)) =
        throw (InvalidInput (Just "title") "title must not be blank")
    | createProductPrice req < 0.01 =
        throw (InvalidInput (Just "price") "price must be >= 0.01")
    | otherwise = pure ()

trim :: String -> String
trim = f . f
  where
    f = reverse . dropWhile isSpace