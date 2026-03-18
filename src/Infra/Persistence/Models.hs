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
    , migrateAll
    , fromProductEntity
    ) where

import Data.Time (UTCTime)
import Database.Persist.Sql (fromSqlKey)
import Database.Persist.TH

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
