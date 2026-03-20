{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.ProductRepository
    ( ProductRepository(..)
    , createProduct
    , getProductById
    , listProducts
    ) where

import Polysemy (makeSem)

import App.ProductCreation (NewProduct)
import Domain.Product (Product)

data ProductRepository m a where
    CreateProduct :: NewProduct -> ProductRepository m Product
    ListProducts :: ProductRepository m [Product]
    GetProductById :: Int -> ProductRepository m (Maybe Product)

makeSem ''ProductRepository
