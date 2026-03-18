{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.ProductRepository
    ( runProductRepositoryDb
    ) where

import Data.Time (getCurrentTime)
import Database.Persist (insert)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool)
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
