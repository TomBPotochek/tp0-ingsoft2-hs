{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module App.Effects.ProductRepository
    ( ProductRepository(..)
    , createProduct
    ) where

import Polysemy (makeSem)

import App.ProductCreation (NewProduct)
import Domain.Product (Product)

data ProductRepository m a where
    CreateProduct :: NewProduct -> ProductRepository m Product

makeSem ''ProductRepository
