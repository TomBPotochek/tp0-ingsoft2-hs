module App.Handlers.Product
    ( createProductHandler
    , getProductByIdHandler
    , listProductsHandler
    ) where

import API.DTO.Product (CreateProductRequest, ProductDTO, toDTO, toNewProduct)
import App.Error (AppError (ProductNotFound))
import App.Effects.ProductRepository (ProductRepository, createProduct, getProductById, listProducts)
import Polysemy (Member, Members, Sem)
import Polysemy.Error (Error, throw)

createProductHandler :: Member ProductRepository r => CreateProductRequest -> Sem r ProductDTO
createProductHandler req = toDTO <$> createProduct (toNewProduct req)

listProductsHandler :: Member ProductRepository r => Sem r [ProductDTO]
listProductsHandler = map toDTO <$> listProducts

getProductByIdHandler :: Members '[ProductRepository, Error AppError] r => Int -> Sem r ProductDTO
getProductByIdHandler productId = do
    maybeProduct <- getProductById productId
    case maybeProduct of
        Just foundProduct -> pure (toDTO foundProduct)
        Nothing -> throw (ProductNotFound productId)