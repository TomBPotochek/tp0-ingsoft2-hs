{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.ProductRepository
    ( runProductRepositoryDb
    ) where

import Data.Time (getCurrentTime)
import Database.Persist (Entity (Entity), Filter, SelectOpt, getEntity, insert, selectList)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool, toSqlKey)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret)
import Polysemy.Reader (Reader, ask)

import App.Effects.ProductRepository (ProductRepository (..))
import App.ProductCreation (NewProduct (..))
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
  where
    toDomain (Entity key entity) = fromProductEntity (key, entity)
