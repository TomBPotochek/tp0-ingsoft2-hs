{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Infra.Persistence.Models
    ( ProductEntity(..)
    , ProductEntityId
    , CartItemEntity(..)
    , CartItemEntityId
    , migrateAll
    , fromCartItemEntity
    , fromProductEntity
    ) where

import Data.Time (UTCTime)
import Database.Persist.Sql (fromSqlKey)
import Database.Persist.TH

import Domain.CartItem (CartItem (..))
import Domain.Product (Product(..))

-- Persistent schema (Postgres backend will use these entities).
share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
ProductEntity sql=products
    sellerId Int
    title String
    description String
    price Double
    createdAt UTCTime
    updatedAt UTCTime
    deriving Show Eq

CartItemEntity sql=cart_items
    userId Int
    productId ProductEntityId OnDeleteCascade
    title String
    unitPrice Double
    addedAt UTCTime
    deriving Show Eq
|]

fromProductEntity :: (ProductEntityId, ProductEntity) -> Product
fromProductEntity (productKey, productEntity) =
    Product
        { productId = fromIntegral (fromSqlKey productKey)
        , productSellerId = productEntitySellerId productEntity
        , productTitle = productEntityTitle productEntity
        , productDescription = productEntityDescription productEntity
        , productPrice = productEntityPrice productEntity
        , productCreatedAt = productEntityCreatedAt productEntity
        , productUpdatedAt = productEntityUpdatedAt productEntity
        }

fromCartItemEntity :: (CartItemEntityId, CartItemEntity) -> CartItem
fromCartItemEntity (cartItemKey, cartItemEntity) =
    CartItem
        { cartItemId = fromIntegral (fromSqlKey cartItemKey)
        , cartItemUserId = cartItemEntityUserId cartItemEntity
        , cartItemProductId = fromIntegral (fromSqlKey (cartItemEntityProductId cartItemEntity))
        , cartItemTitle = cartItemEntityTitle cartItemEntity
        , cartItemUnitPrice = cartItemEntityUnitPrice cartItemEntity
        , cartItemAddedAt = cartItemEntityAddedAt cartItemEntity
        }
