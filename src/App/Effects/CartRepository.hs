{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.CartRepository
    ( CartRepository(..)
    , addProductToCart
    , getCartByUserId
    ) where

import Polysemy (makeSem)

import Domain.CartItem (CartItem)

data CartRepository m a where
    GetCartByUserId :: Int -> CartRepository m [CartItem]
    AddProductToCart :: Int -> Int -> CartRepository m (Maybe CartItem)

makeSem ''CartRepository
