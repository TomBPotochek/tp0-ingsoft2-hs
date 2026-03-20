{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.ProductRepository
    ( runProductRepositoryDb
    ) where

import Data.Time (getCurrentTime)
import Database.Persist (Entity (Entity), Filter, SelectOpt, getEntity, insert, replace, selectList)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool, toSqlKey)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret)
import Polysemy.Reader (Reader, ask)

import App.Effects.ProductRepository (ProductRepository (..))
import App.ProductCreation (NewProduct (..))
import qualified App.ProductUpdate as ProductUpdate
import Infra.Persistence.Models (ProductEntity (..), ProductEntityId, fromProductEntity)

runProductRepositoryDb :: Members '[Reader ConnectionPool, Embed IO] r => InterpreterFor ProductRepository r
runProductRepositoryDb = interpret $ \case
    CreateProduct newProduct -> do
        pool <- ask
        now <- embed getCurrentTime
        let entity = ProductEntity
                { productEntitySellerId = sellerId newProduct
                , productEntityTitle = title newProduct
                , productEntityDescription = description newProduct
                , productEntityPrice = price newProduct
                , productEntityCreatedAt = now
                , productEntityUpdatedAt = now
                }
        key <- embed (runSqlPool @SqlBackend (insert entity) pool :: IO ProductEntityId)
        pure (fromProductEntity (key, entity))
    ListProducts -> do
        pool <- ask
        entities <- embed (runSqlPool @SqlBackend (selectList ([] :: [Filter ProductEntity]) ([] :: [SelectOpt ProductEntity])) pool :: IO [Entity ProductEntity])
        pure (map toDomain entities)
    GetProductById productId -> do
        pool <- ask
        maybeEntity <- embed (runSqlPool @SqlBackend (getEntity (toSqlKey (fromIntegral productId) :: ProductEntityId)) pool :: IO (Maybe (Entity ProductEntity)))
        pure (toDomain <$> maybeEntity)
    UpdateProductById productId productUpdate -> do
        pool <- ask
        let key = toSqlKey (fromIntegral productId) :: ProductEntityId
        maybeExisting <- embed (runSqlPool @SqlBackend (getEntity key) pool :: IO (Maybe (Entity ProductEntity)))
        case maybeExisting of
            Nothing -> pure Nothing
            Just (Entity _ existing) -> do
                now <- embed getCurrentTime
                let updated = existing { 
                    productEntityTitle = ProductUpdate.title productUpdate
                    , productEntityDescription = ProductUpdate.description productUpdate
                    , productEntityPrice = ProductUpdate.price productUpdate
                        , productEntityUpdatedAt = now
                        }
                embed (runSqlPool @SqlBackend (replace key updated) pool :: IO ())
                pure (Just (fromProductEntity (key, updated)))
  where
    toDomain (Entity key entity) = fromProductEntity (key, entity)
