{-# LANGUAGE OverloadedStrings #-}

module Infra.Persistence.CartRepository
    ( runCartRepositoryDb
    ) where

import Data.List (sortBy)
import Data.Time (getCurrentTime)
import Database.Persist (Entity (Entity), entityVal, getEntity, insert, selectList)
import Database.Persist.Sql (ConnectionPool, SqlBackend, fromSqlKey, runSqlPool, toSqlKey)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret)
import Polysemy.Reader (Reader, ask)

import App.Effects.CartRepository (CartRepository (..))
import Infra.Persistence.Models (CartItemEntity (..), CartItemEntityId, ProductEntity (..), ProductEntityId, fromCartItemEntity)

runCartRepositoryDb :: Members '[Reader ConnectionPool, Embed IO] r => InterpreterFor CartRepository r
runCartRepositoryDb = interpret $ \case
    GetCartByUserId userId -> do
        pool <- ask
        entities <- embed (runSqlPool @SqlBackend (selectList [] []) pool :: IO [Entity CartItemEntity])
        let filtered = filter ((== userId) . cartItemEntityUserId . entityVal) entities
            ordered = sortBy compareCartItems filtered
        pure (map toDomain ordered)
    AddProductToCart userId productId -> do
        pool <- ask
        let productKey = toSqlKey (fromIntegral productId) :: ProductEntityId
        maybeProduct <- embed (runSqlPool @SqlBackend (getEntity productKey) pool :: IO (Maybe (Entity ProductEntity)))
        case maybeProduct of
            Nothing -> pure Nothing
            Just (Entity _ productEntity) -> do
                now <- embed getCurrentTime
                let cartItem = CartItemEntity
                        { cartItemEntityUserId = userId
                        , cartItemEntityProductId = productKey
                        , cartItemEntityTitle = productEntityTitle productEntity
                        , cartItemEntityUnitPrice = productEntityPrice productEntity
                        , cartItemEntityAddedAt = now
                        }
                cartItemKey <- embed (runSqlPool @SqlBackend (insert cartItem) pool :: IO CartItemEntityId)
                pure (Just (fromCartItemEntity (cartItemKey, cartItem)))
    where
        compareCartItems (Entity keyA itemA) (Entity keyB itemB) =
            compare
                (cartItemEntityAddedAt itemB, fromSqlKey keyB)
                (cartItemEntityAddedAt itemA, fromSqlKey keyA)

        toDomain (Entity key entity) = fromCartItemEntity (key, entity)
