{-# LANGUAGE DeriveGeneric #-}

module API.DTO.Cart
    ( AddCartRequest(..)
    , CartDTO(..)
    , CartItemDTO(..)
    , toCartDTO
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

data CartDTO = CartDTO
    { userId :: Int
    , items :: [CartItemDTO]
    , totalPrice :: Double
    }
    deriving (Show, Eq, Generic)

instance FromJSON CartDTO
instance ToJSON CartDTO
instance ToSchema CartDTO

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
        , unitPrice = realToFrac (cartItemUnitPrice domainItem)
        , addedAt = cartItemAddedAt domainItem
        }

toCartDTO :: Int -> Double -> [CartItem] -> CartDTO
toCartDTO cartUserId total cartItems =
    CartDTO
        { userId = cartUserId
        , items = map toDTO cartItems
        , totalPrice = total
        }
