{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.ProductRepository
    ( ProductRepository(..)
    , createProduct
    , deleteProductById
    , getProductById
    , listProducts
    , updateProductById
    ) where

import Polysemy (makeSem)

import App.ProductCreation (NewProduct)
import App.ProductUpdate (ProductUpdate)
import Domain.Product (Product)

data ProductRepository m a where
    CreateProduct :: NewProduct -> ProductRepository m Product
    ListProducts :: ProductRepository m [Product]
    GetProductById :: Int -> ProductRepository m (Maybe Product)
    UpdateProductById :: Int -> ProductUpdate -> ProductRepository m (Maybe Product)
    DeleteProductById :: Int -> ProductRepository m Bool

makeSem ''ProductRepository
