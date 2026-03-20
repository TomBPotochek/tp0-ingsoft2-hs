{-# LANGUAGE OverloadedStrings #-}

module E2E.ProductsSpec
    ( spec
    ) where

import Servant.Client (ClientEnv)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe)

import API.DTO.Product (CreateProductRequest(..), ProductDTO(..), UpdateProductRequest(..))
import qualified API.DTO.Product as ProductDTO
import E2E.Support (createProductClient, getProductByIdClient, listProductsClient, retryClient, updateProductByIdClient)


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

    describe "GET /products/{id}" $ do
        it "returns the product for an existing id" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 4
                    , createProductTitle = "Get endpoint product"
                    , createProductDescription = "Created for id lookup"
                    , createProductPrice = 12.34
                    }

            createdResult <- retryClient 20 env (createProductClient request)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    foundResult <- retryClient 20 env (getProductByIdClient (ProductDTO.id createdProduct))
                    case foundResult of
                        Left fetchErr -> expectationFailure ("E2E request failed: " ++ fetchErr)
                        Right foundProduct -> do
                            ProductDTO.id foundProduct `shouldBe` ProductDTO.id createdProduct
                            sellerId foundProduct `shouldBe` sellerId createdProduct
                            title foundProduct `shouldBe` title createdProduct
                            description foundProduct `shouldBe` description createdProduct
                            price foundProduct `shouldBe` price createdProduct

    describe "PUT /products/{id}" $ do
        it "updates a product and returns updated data" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 5
                    , createProductTitle = "Before update"
                    , createProductDescription = "Old description"
                    , createProductPrice = 20.0
                    }
                updateRequest = UpdateProductRequest
                    { updateProductTitle = "After update"
                    , updateProductDescription = "New description"
                    , updateProductPrice = 25.5
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    updatedResult <- retryClient 20 env (updateProductByIdClient (ProductDTO.id createdProduct) updateRequest)
                    case updatedResult of
                        Left updateErr -> expectationFailure ("E2E request failed: " ++ updateErr)
                        Right updatedProduct -> do
                            ProductDTO.id updatedProduct `shouldBe` ProductDTO.id createdProduct
                            sellerId updatedProduct `shouldBe` sellerId createdProduct
                            title updatedProduct `shouldBe` updateProductTitle updateRequest
                            description updatedProduct `shouldBe` updateProductDescription updateRequest
                            price updatedProduct `shouldBe` updateProductPrice updateRequest
