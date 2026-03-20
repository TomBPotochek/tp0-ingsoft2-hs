{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes
    ( ProductAPI
    , API
    , productApi
    , api
    ) where

import Data.OpenApi (OpenApi)
import Servant (Capture, DeleteNoContent, Get, JSON, Post, Proxy(..), Put, ReqBody, Summary, (:<|>), (:>))

import API.DTO.Product (CreateProductRequest, ProductDTO, UpdateProductRequest)

type ProductAPI =
    "products"
        :>
            ( Summary "Create a new product"
                :> ReqBody '[JSON] CreateProductRequest
                :> Post '[JSON] ProductDTO
                :<|> Summary "Retrieve all products"
                :> Get '[JSON] [ProductDTO]
                :<|> Summary "Retrieve a product by id"
                :> Capture "id" Int
                :> Get '[JSON] ProductDTO
                :<|> Summary "Update a product by id"
                :> Capture "id" Int
                :> ReqBody '[JSON] UpdateProductRequest
                :> Put '[JSON] ProductDTO
                :<|> Summary "Delete a product by id"
                :> Capture "id" Int
                :> DeleteNoContent
            )

type API = ProductAPI :<|> "openapi.json" :> Get '[JSON] OpenApi

productApi :: Proxy ProductAPI
productApi = Proxy

api :: Proxy API
api = Proxy
