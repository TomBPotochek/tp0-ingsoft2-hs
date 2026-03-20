{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.CartRepository
    ( CartRepository(..)
    , addProductToCart
    , deleteCartByUserId
    , deleteCartItemById
    , getCartByUserId
    ) where

import Polysemy (makeSem)

import Domain.CartItem (CartItem)

data CartRepository m a where
    GetCartByUserId :: Int -> CartRepository m [CartItem]
    DeleteCartByUserId :: Int -> CartRepository m ()
    AddProductToCart :: Int -> Int -> CartRepository m (Maybe CartItem)
    DeleteCartItemById :: Int -> Int -> CartRepository m Bool

makeSem ''CartRepository
