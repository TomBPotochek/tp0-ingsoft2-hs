{-# LANGUAGE OverloadedStrings #-}

module E2E.ProductsSpec
    ( spec
    ) where

import Servant.Client (ClientEnv)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe)

import API.DTO.Product (CreateProductRequest(..), ProductDTO(..))
import E2E.Support (createProductClient, listProductsClient, retryClient)


spec :: ClientEnv -> Spec
spec env = do
    describe "POST /products" $ do
        it "creates a product and returns 201 with product data" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 1
                    , createProductTitle = "Test Product"
                    , createProductDescription = "A test product"
                    , createProductPrice = 99.99
                    }
            result <- retryClient 20 env (createProductClient request)
            case result of
                Left err -> expectationFailure ("E2E request failed: " ++ err)
                Right createdProduct -> do
                    sellerId createdProduct `shouldBe` 1
                    title createdProduct `shouldBe` "Test Product"
                    description createdProduct `shouldBe` "A test product"
                    price createdProduct `shouldBe` 99.99

    describe "GET /products" $ do
        it "returns all products" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 3
                    , createProductTitle = "List endpoint product"
                    , createProductDescription = "Created for list check"
                    , createProductPrice = 10.50
                    }

            createResult <- retryClient 20 env (createProductClient request)
            case createResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right _ -> pure ()

            listResult <- retryClient 20 env listProductsClient
            case listResult of
                Left err -> expectationFailure ("E2E request failed: " ++ err)
                Right products -> shouldBe (null products) False
