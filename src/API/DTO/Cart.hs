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
import Data.Scientific (Scientific)
import App.Support (Money, pattern ViewMoney)

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
    , unitPrice :: Scientific
    , addedAt :: UTCTime
    }
    deriving (Show, Eq, Generic)

instance FromJSON CartItemDTO
instance ToJSON CartItemDTO
instance ToSchema CartItemDTO

data CartDTO = CartDTO
    { userId :: Int
    , items :: [CartItemDTO]
    , totalPrice :: Scientific
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

toCartDTO :: Int -> Money -> [CartItem] -> CartDTO
toCartDTO cartUserId total cartItems =
    CartDTO
        { userId = cartUserId
        , items = map toDTO cartItems
        , totalPrice = totalSum
        }
    where
        ViewMoney totalSum = total 
