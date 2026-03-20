module App.Handlers.Product
    ( createProductHandler
    , getProductByIdHandler
    , listProductsHandler
    ) where

import API.DTO.Product (CreateProductRequest, ProductDTO, toDTO, toNewProduct)
import App.Effects.ProductRepository (ProductRepository, createProduct, getProductById, listProducts)
import Polysemy (Member, Sem)

createProductHandler :: Member ProductRepository r => CreateProductRequest -> Sem r ProductDTO
createProductHandler req = toDTO <$> createProduct (toNewProduct req)

listProductsHandler :: Member ProductRepository r => Sem r [ProductDTO]
listProductsHandler = map toDTO <$> listProducts

getProductByIdHandler :: Member ProductRepository r => Int -> Sem r (Maybe ProductDTO)
getProductByIdHandler productId = fmap toDTO <$> getProductById productId