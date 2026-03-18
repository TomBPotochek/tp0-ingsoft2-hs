{-# LANGUAGE DeriveGeneric #-}

module API.DTO.Product
    ( ProductDTO(..)
    , CreateProductRequest(..)
    , toNewProduct
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
import Data.Char (toLower)
import Data.List (stripPrefix)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

import App.ProductCreation (NewProduct (..))
import Domain.Product (Product(..))

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

createProductInputJSONOptions :: Options
createProductInputJSONOptions = defaultOptions
    { fieldLabelModifier = dropCreateProductPrefix }

dropCreateProductPrefix :: String -> String
dropCreateProductPrefix fieldName =
    case stripPrefix "createProduct" fieldName of
        Nothing -> fieldName
        Just [] -> []
        Just (x:xs) -> toLower x : xs

toNewProduct :: CreateProductRequest -> NewProduct
toNewProduct input =
    NewProduct
        { sellerId = createProductSellerId input
        , title = createProductTitle input
        , description = createProductDescription input
        , price = createProductPrice input
        }

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
