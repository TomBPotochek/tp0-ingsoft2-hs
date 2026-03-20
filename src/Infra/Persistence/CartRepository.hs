{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}

module Infra.Persistence.CartRepository
    ( runCartRepositoryDb
    ) where

import Data.Time (getCurrentTime)
import Database.Persist
    ( Entity (Entity)
    , SelectOpt (Desc)
    , delete
    , getEntity
    , insert
    , selectList
    , (==.)
    )
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool, toSqlKey)
import Polysemy (Embed, InterpreterFor, Members, embed, interpret)
import Polysemy.Reader (Reader, ask)

import App.Effects.CartRepository (CartRepository (..))
import Infra.Persistence.Models
    ( CartItemEntity (..)
    , CartItemEntityId
    , ProductEntity (..)
    , ProductEntityId
    , fromCartItemEntity
    , pattern CartItemEntityAddedAt
    , pattern CartItemEntityId
    , pattern CartItemEntityUserId
    )

runCartRepositoryDb :: Members '[Reader ConnectionPool, Embed IO] r => InterpreterFor CartRepository r
runCartRepositoryDb = interpret $ \case
    GetCartByUserId userId -> do
        pool <- ask
        entities <- embed
            ( runSqlPool @SqlBackend
                ( selectList
                    [CartItemEntityUserId ==. userId]
                    [ Desc CartItemEntityAddedAt
                    , Desc CartItemEntityId
                    ]
                )
                pool :: IO [Entity CartItemEntity]
            )
        pure (map toDomain entities)
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
    DeleteCartItemById userId cartItemId -> do
        pool <- ask
        let cartItemKey = toSqlKey (fromIntegral cartItemId) :: CartItemEntityId
        maybeCartItem <- embed (runSqlPool @SqlBackend (getEntity cartItemKey) pool :: IO (Maybe (Entity CartItemEntity)))
        case maybeCartItem of
            Nothing -> pure False
            Just (Entity _ cartItem)
                | cartItemEntityUserId cartItem /= userId -> pure False
                | otherwise -> do
                    embed (runSqlPool @SqlBackend (delete cartItemKey) pool :: IO ())
                    pure True
    where
        toDomain (Entity key entity) = fromCartItemEntity (key, entity)
