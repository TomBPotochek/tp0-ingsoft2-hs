{-# LANGUAGE OverloadedStrings #-}

module E2E.ProductsSpec
    ( spec
    ) where

import Servant.Client (ClientEnv, client)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe)

import API.Routes (api)
import API.DTO.Product (CreateProductRequest(..), ProductDTO(..))
import E2E.Support (retryClient)

spec :: ClientEnv -> Spec
spec env =
    describe "POST /products" $ do
        it "creates a product and returns 201 with product data" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 1
                    , createProductTitle = "Test Product"
                    , createProductDescription = "A test product"
                    , createProductPrice = 99.99
                    }
                createProductClient = client api
            result <- retryClient 20 env (createProductClient request)
            case result of
                Left err -> expectationFailure ("E2E request failed: " ++ err)
                Right createdProduct -> do
                    sellerId createdProduct `shouldBe` 1
                    title createdProduct `shouldBe` "Test Product"
                    description createdProduct `shouldBe` "A test product"
                    price createdProduct `shouldBe` 99.99
