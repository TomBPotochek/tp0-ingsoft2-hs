{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes
    ( ProductRoutes(..)
    , CartByUserRoutes(..)
    , ApiRoutes(..)
    , ProductAPI
    , CartAPI
    , OpenApiAPI
    , API
    , api
    ) where

import Data.OpenApi (OpenApi)
import GHC.Generics (Generic)
import Servant (Capture, DeleteNoContent, Get, JSON, NamedRoutes, Post, Proxy(..), Put, ReqBody, Summary, (:<|>), type (:-), type (:>))

import API.DTO.Cart (AddCartRequest, CartDTO, CartItemDTO)
import API.DTO.Product (CreateProductRequest, ProductDTO, UpdateProductRequest)

data ProductRoutes mode = ProductRoutes
    { createProductRoute ::
        mode
            :- Summary "Create a new product"
            :> ReqBody '[JSON] CreateProductRequest
            :> Post '[JSON] ProductDTO
    , listProductsRoute ::
        mode
            :- Summary "Retrieve all products"
            :> Get '[JSON] [ProductDTO]
    , getProductByIdRoute ::
        mode
            :- Summary "Retrieve a product by id"
            :> Capture "id" Int
            :> Get '[JSON] ProductDTO
    , updateProductByIdRoute ::
        mode
            :- Summary "Update a product by id"
            :> Capture "id" Int
            :> ReqBody '[JSON] UpdateProductRequest
            :> Put '[JSON] ProductDTO
    , deleteProductByIdRoute ::
        mode
            :- Summary "Delete a product by id"
            :> Capture "id" Int
            :> DeleteNoContent
    }
    deriving (Generic)

data CartByUserRoutes mode = CartByUserRoutes
    { getCartRoute ::
        mode
            :- Summary "Get user's cart"
            :> Get '[JSON] CartDTO
    , deleteCartRoute ::
        mode
            :- Summary "Wipe a user's cart"
            :> DeleteNoContent
    , addProductToCartRoute ::
        mode
            :- "items"
            :> Summary "Add product to user's cart"
            :> ReqBody '[JSON] AddCartRequest
            :> Post '[JSON] CartItemDTO
    , deleteCartItemRoute ::
        mode
            :- "items"
            :> Capture "cartItemId" Int
            :> Summary "Delete an item from user's cart"
            :> DeleteNoContent
    }
    deriving (Generic)

data ApiRoutes mode = ApiRoutes
    { productsRoutes ::
        mode
            :- "products"
            :> NamedRoutes ProductRoutes
    , cartRoutes ::
        mode
            :- "cart"
            :> Capture "userId" Int
            :> NamedRoutes CartByUserRoutes
    , openApiJsonRoute ::
        mode
            :- "openapi.json"
            :> Get '[JSON] OpenApi
    }
    deriving (Generic)

type ProductAPI = "products" :> NamedRoutes ProductRoutes
type CartAPI = "cart" :> Capture "userId" Int :> NamedRoutes CartByUserRoutes
type OpenApiAPI = ProductAPI :<|> CartAPI

type API = NamedRoutes ApiRoutes

api :: Proxy API
api = Proxy
