{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.CartRepository
    ( CartRepository(..)
    , addProductToCart
    ) where

import Polysemy (makeSem)

import Domain.CartItem (CartItem)

data CartRepository m a where
    AddProductToCart :: Int -> Int -> CartRepository m (Maybe CartItem)

makeSem ''CartRepository
