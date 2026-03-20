{-# LANGUAGE DeriveGeneric #-}

module API.DTO.Product
    ( ProductDTO(..)
    , CreateProductRequest(..)
    , UpdateProductRequest(..)
    , toNewProduct
    , toProductUpdate
    , toDTO
    ) where

import Data.Aeson
    ( FromJSON(..)
    , Options(..)
    , ToJSON(..)
    , defaultOptions
    , genericParseJSON
    , genericToJSON
    )

import Data.OpenApi (ToSchema)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

import App.ProductCreation (NewProduct (..))
import qualified App.ProductUpdate as ProductUpdate
import Domain.Product (Product(..))
import API.DTO.Support (dropPrefixFromFields)

data ProductDTO = ProductDTO
    { id :: Int
    , sellerId :: Int
    , title :: String
    , description :: String
    , price :: Double
    , createdAt :: UTCTime
    , updatedAt :: UTCTime
    }
    deriving (Show, Eq, Generic)

instance FromJSON ProductDTO
instance ToJSON ProductDTO
instance ToSchema ProductDTO

data CreateProductRequest = CreateProductRequest
    { createProductSellerId :: Int
    , createProductTitle :: String
    , createProductDescription :: String
    , createProductPrice :: Double
    }
    deriving (Show, Eq, Generic)

instance FromJSON CreateProductRequest where
    parseJSON = genericParseJSON createProductInputJSONOptions

instance ToJSON CreateProductRequest where
    toJSON = genericToJSON createProductInputJSONOptions

instance ToSchema CreateProductRequest

data UpdateProductRequest = UpdateProductRequest
    { updateProductTitle :: String
    , updateProductDescription :: String
    , updateProductPrice :: Double
    }
    deriving (Show, Eq, Generic)

instance FromJSON UpdateProductRequest where
    parseJSON = genericParseJSON updateProductInputJSONOptions

instance ToJSON UpdateProductRequest where
    toJSON = genericToJSON updateProductInputJSONOptions

instance ToSchema UpdateProductRequest

createProductInputJSONOptions :: Options
createProductInputJSONOptions = defaultOptions
    { fieldLabelModifier = dropCreateProductPrefix }

dropCreateProductPrefix :: String -> String
dropCreateProductPrefix = dropPrefixFromFields "createProduct"

updateProductInputJSONOptions :: Options
updateProductInputJSONOptions = defaultOptions
    { fieldLabelModifier = dropUpdateProductPrefix }

dropUpdateProductPrefix :: String -> String
dropUpdateProductPrefix = dropPrefixFromFields "updateProduct"

toNewProduct :: CreateProductRequest -> NewProduct
toNewProduct input =
    NewProduct
        { sellerId = createProductSellerId input
        , title = createProductTitle input
        , description = createProductDescription input
        , price = createProductPrice input
        }

toProductUpdate :: UpdateProductRequest -> ProductUpdate.ProductUpdate
toProductUpdate input =
    ProductUpdate.ProductUpdate
        (updateProductTitle input)
        (updateProductDescription input)
        (updateProductPrice input)

toDTO :: Product -> ProductDTO
toDTO domainProduct =
    ProductDTO
        { id = productId domainProduct
        , sellerId = productSellerId domainProduct
        , title = productTitle domainProduct
        , description = productDescription domainProduct
        , price = productPrice domainProduct
        , createdAt = productCreatedAt domainProduct
        , updatedAt = productUpdatedAt domainProduct
        }
