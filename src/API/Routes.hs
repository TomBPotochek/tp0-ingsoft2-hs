{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes
    ( ProductAPI
    , API
    , productApi
    , api
    ) where

import Data.OpenApi (OpenApi)
import Servant (Description, Get, JSON, Post, Proxy(..), ReqBody, Summary, (:<|>), (:>))

import API.DTO.Product (CreateProductRequest, ProductDTO)

type ProductAPI =
    "products"
        :> Summary "Create a new product"
        :> ReqBody '[JSON] CreateProductRequest
        :> Post '[JSON] ProductDTO

type API = ProductAPI :<|> "openapi.json" :> Get '[JSON] OpenApi

productApi :: Proxy ProductAPI
productApi = Proxy

api :: Proxy API
api = Proxy
