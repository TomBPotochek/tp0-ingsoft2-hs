{-# LANGUAGE DeriveGeneric #-}

module API.DTO.Cart
    ( AddCartRequest(..)
    , CartItemDTO(..)
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
import Data.OpenApi (ToSchema)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

import Domain.CartItem (CartItem(..))
import API.DTO.Support (dropPrefixFromFields)

data AddCartRequest = AddCartRequest
    { addCartProductId :: Int
    }
    deriving (Show, Eq, Generic)

instance FromJSON AddCartRequest where
    parseJSON = genericParseJSON addCartInputJSONOptions

instance ToJSON AddCartRequest where
    toJSON = genericToJSON addCartInputJSONOptions

instance ToSchema AddCartRequest

data CartItemDTO = CartItemDTO
    { id :: Int
    , productId :: Int
    , title :: String
    , unitPrice :: Double
    , addedAt :: UTCTime
    }
    deriving (Show, Eq, Generic)

instance FromJSON CartItemDTO
instance ToJSON CartItemDTO
instance ToSchema CartItemDTO

addCartInputJSONOptions :: Options
addCartInputJSONOptions = defaultOptions
    { fieldLabelModifier = dropAddCartPrefix }

dropAddCartPrefix :: String -> String
dropAddCartPrefix = dropPrefixFromFields "addCart"

toDTO :: CartItem -> CartItemDTO
toDTO domainItem =
    CartItemDTO
        { id = cartItemId domainItem
        , productId = cartItemProductId domainItem
        , title = cartItemTitle domainItem
        , unitPrice = cartItemUnitPrice domainItem
        , addedAt = cartItemAddedAt domainItem
        }
