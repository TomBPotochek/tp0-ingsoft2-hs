module App.Handlers.Product
    ( createProductHandler
    , listProductsHandler
    ) where

import API.DTO.Product (CreateProductRequest, ProductDTO, toDTO, toNewProduct)
import App.Effects.ProductRepository (ProductRepository, createProduct, listProducts)
import Polysemy (Member, Sem)

createProductHandler :: Member ProductRepository r => CreateProductRequest -> Sem r ProductDTO
createProductHandler req = toDTO <$> createProduct (toNewProduct req)

listProductsHandler :: Member ProductRepository r => Sem r [ProductDTO]
listProductsHandler = map toDTO <$> listProducts