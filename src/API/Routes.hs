{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes
    ( API
    , api
    ) where

import Servant (JSON, Post, Proxy(..), ReqBody, (:>))

import API.DTO.Product (CreateProductRequest, ProductDTO)

type API = "products" :> ReqBody '[JSON] CreateProductRequest :> Post '[JSON] ProductDTO

api :: Proxy API
api = Proxy
