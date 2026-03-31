{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE PatternSynonyms #-}
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
import Data.Scientific ( Scientific)
import Data.OpenApi (ToSchema)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

import App.ProductCreation (NewProduct (..))
import qualified App.ProductUpdate as ProductUpdate
import App.Support (pattern ViewMoney, moneyFromScientific)
import Domain.Product (Product(..))
import API.DTO.Support (dropPrefixFromFields)

data ProductDTO = ProductDTO
    { id :: Int
    , sellerId :: Int
    , title :: String
    , description :: String
    , price :: Scientific
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
    , createProductPrice :: Scientific
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
    , updateProductPrice :: Scientific
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

toNewProduct :: CreateProductRequest -> Maybe NewProduct
toNewProduct input = do
    price <- moneyFromScientific (createProductPrice input)
    return $ NewProduct
        { sellerId = createProductSellerId input
        , title = createProductTitle input
        , description = createProductDescription input
        , price = price
        }

toProductUpdate :: UpdateProductRequest -> Maybe ProductUpdate.ProductUpdate
toProductUpdate input = do
    price <- moneyFromScientific (updateProductPrice input)
    return $ ProductUpdate.ProductUpdate
        (updateProductTitle input)
        (updateProductDescription input)
        price

toDTO :: Product -> ProductDTO
toDTO domainProduct =
    ProductDTO
        { id = productId domainProduct
        , sellerId = productSellerId domainProduct
        , title = productTitle domainProduct
        , description = productDescription domainProduct
        , price = realToFrac (productPrice domainProduct)
        , createdAt = productCreatedAt domainProduct
        , updatedAt = productUpdatedAt domainProduct
        }
