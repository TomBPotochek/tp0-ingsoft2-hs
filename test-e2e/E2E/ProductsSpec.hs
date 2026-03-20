{-# LANGUAGE OverloadedStrings #-}

module E2E.ProductsSpec
    ( spec
    ) where

import Data.Either (isLeft)
import Servant.Client (ClientEnv)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe, shouldSatisfy)

import API.DTO.Cart (AddCartRequest (..))
import qualified API.DTO.Cart as CartDTO
import API.DTO.Product (CreateProductRequest(..), UpdateProductRequest(..))
import qualified API.DTO.Product as ProductDTO
import E2E.Support (addProductToCartClient, createProductClient, deleteProductByIdClient, getCartClient, getProductByIdClient, listProductsClient, retryClient, updateProductByIdClient)


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
                    ProductDTO.sellerId createdProduct `shouldBe` 1
                    ProductDTO.title createdProduct `shouldBe` "Test Product"
                    ProductDTO.description createdProduct `shouldBe` "A test product"
                    ProductDTO.price createdProduct `shouldBe` 99.99

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
                            ProductDTO.sellerId foundProduct `shouldBe` ProductDTO.sellerId createdProduct
                            ProductDTO.title foundProduct `shouldBe` ProductDTO.title createdProduct
                            ProductDTO.description foundProduct `shouldBe` ProductDTO.description createdProduct
                            ProductDTO.price foundProduct `shouldBe` ProductDTO.price createdProduct

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
                            ProductDTO.sellerId updatedProduct `shouldBe` ProductDTO.sellerId createdProduct
                            ProductDTO.title updatedProduct `shouldBe` updateProductTitle updateRequest
                            ProductDTO.description updatedProduct `shouldBe` updateProductDescription updateRequest
                            ProductDTO.price updatedProduct `shouldBe` updateProductPrice updateRequest

    describe "DELETE /products/{id}" $ do
        it "deletes an existing product" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 6
                    , createProductTitle = "Delete candidate"
                    , createProductDescription = "Will be deleted"
                    , createProductPrice = 18.0
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    deleteResult <- retryClient 20 env (deleteProductByIdClient (ProductDTO.id createdProduct))
                    case deleteResult of
                        Left deleteErr -> expectationFailure ("E2E request failed: " ++ deleteErr)
                        Right _ -> pure ()

                    getResult <- retryClient 20 env (getProductByIdClient (ProductDTO.id createdProduct))
                    getResult `shouldSatisfy` isLeft

    describe "POST /cart/{userId}/items" $ do
        it "creates a cart item with product title/price snapshot" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 7
                    , createProductTitle = "Cart snapshot source"
                    , createProductDescription = "Snapshot description"
                    , createProductPrice = 31.25
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    addResult <- retryClient 20 env (addProductToCartClient 55 (AddCartRequest (ProductDTO.id createdProduct)))
                    case addResult of
                        Left addErr -> expectationFailure ("E2E request failed: " ++ addErr)
                        Right cartItem -> do
                            CartDTO.productId cartItem `shouldBe` ProductDTO.id createdProduct
                            CartDTO.title cartItem `shouldBe` ProductDTO.title createdProduct
                            CartDTO.unitPrice cartItem `shouldBe` ProductDTO.price createdProduct

    describe "GET /cart/{userId}" $ do
        it "returns an empty cart for a user without items" $ do
            cartResult <- retryClient 20 env (getCartClient 404_404)
            case cartResult of
                Left err -> expectationFailure ("E2E request failed: " ++ err)
                Right cart -> do
                    CartDTO.userId cart `shouldBe` 404_404
                    CartDTO.items cart `shouldBe` []
                    CartDTO.totalPrice cart `shouldBe` 0

        it "returns user cart items ordered newest first with totalPrice" $ do
            let createRequestA = CreateProductRequest
                    { createProductSellerId = 8
                    , createProductTitle = "Cart item A"
                    , createProductDescription = "First"
                    , createProductPrice = 11.0
                    }
                createRequestB = CreateProductRequest
                    { createProductSellerId = 9
                    , createProductTitle = "Cart item B"
                    , createProductDescription = "Second"
                    , createProductPrice = 22.0
                    }

            createdAResult <- retryClient 20 env (createProductClient createRequestA)
            createdBResult <- retryClient 20 env (createProductClient createRequestB)

            case (createdAResult, createdBResult) of
                (Right createdA, Right createdB) -> do
                    _ <- retryClient 20 env (addProductToCartClient 66 (AddCartRequest (ProductDTO.id createdA)))
                    _ <- retryClient 20 env (addProductToCartClient 66 (AddCartRequest (ProductDTO.id createdB)))
                    cartResult <- retryClient 20 env (getCartClient 66)
                    case cartResult of
                        Left err -> expectationFailure ("E2E request failed: " ++ err)
                        Right cart -> do
                            map CartDTO.productId (CartDTO.items cart) `shouldBe` [ProductDTO.id createdB, ProductDTO.id createdA]
                            CartDTO.totalPrice cart `shouldBe` 33.0
                (Left err, _) -> expectationFailure ("E2E setup failed: " ++ err)
                (_, Left err) -> expectationFailure ("E2E setup failed: " ++ err)
