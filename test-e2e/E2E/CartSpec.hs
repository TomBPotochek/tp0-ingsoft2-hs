{-# LANGUAGE OverloadedStrings #-}

module E2E.CartSpec
    ( spec
    ) where

import Data.Either (isLeft)
import Servant.Client (ClientEnv)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe, shouldSatisfy)

import API.DTO.Cart (AddCartRequest (..))
import qualified API.DTO.Cart as CartDTO
import API.DTO.Product (CreateProductRequest(..))
import qualified API.DTO.Product as ProductDTO
import E2E.Support (addProductToCartClient, createProductClient, deleteCartItemClient, deleteProductByIdClient, getCartClient, retryClient)

spec :: ClientEnv -> Spec
spec env = do
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
                    let testUserId = ProductDTO.id createdA * 10_000 + ProductDTO.id createdB
                    _ <- retryClient 20 env (addProductToCartClient testUserId (AddCartRequest (ProductDTO.id createdA)))
                    _ <- retryClient 20 env (addProductToCartClient testUserId (AddCartRequest (ProductDTO.id createdB)))
                    cartResult <- retryClient 20 env (getCartClient testUserId)
                    case cartResult of
                        Left err -> expectationFailure ("E2E request failed: " ++ err)
                        Right cart -> do
                            map CartDTO.productId (CartDTO.items cart) `shouldBe` [ProductDTO.id createdB, ProductDTO.id createdA]
                            CartDTO.totalPrice cart `shouldBe` 33.0
                (Left err, _) -> expectationFailure ("E2E setup failed: " ++ err)
                (_, Left err) -> expectationFailure ("E2E setup failed: " ++ err)

    describe "DELETE /cart/{userId}/items/{cartItemId}" $ do
        it "deletes a cart item that belongs to the user" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 11
                    , createProductTitle = "Delete cart item e2e"
                    , createProductDescription = "Created to test cart item deletion"
                    , createProductPrice = 17.5
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    let userId = ProductDTO.id createdProduct * 10_000 + 10
                    addedResult <- retryClient 20 env (addProductToCartClient userId (AddCartRequest (ProductDTO.id createdProduct)))
                    case addedResult of
                        Left addErr -> expectationFailure ("E2E setup failed: " ++ addErr)
                        Right cartItem -> do
                            deleteResult <- retryClient 20 env (deleteCartItemClient userId (CartDTO.id cartItem))
                            case deleteResult of
                                Left deleteErr -> expectationFailure ("E2E request failed: " ++ deleteErr)
                                Right _ -> pure ()

                            cartResult <- retryClient 20 env (getCartClient userId)
                            case cartResult of
                                Left cartErr -> expectationFailure ("E2E request failed: " ++ cartErr)
                                Right cart -> do
                                    CartDTO.items cart `shouldBe` []
                                    CartDTO.totalPrice cart `shouldBe` 0

        it "returns 404 when deleting another user's cart item" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 12
                    , createProductTitle = "Delete wrong user e2e"
                    , createProductDescription = "Created to verify user scoping"
                    , createProductPrice = 18.5
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    let userA = ProductDTO.id createdProduct * 10_000 + 11
                        userB = ProductDTO.id createdProduct * 10_000 + 12
                    addedResult <- retryClient 20 env (addProductToCartClient userA (AddCartRequest (ProductDTO.id createdProduct)))
                    case addedResult of
                        Left addErr -> expectationFailure ("E2E setup failed: " ++ addErr)
                        Right cartItem -> do
                            deleteResult <- retryClient 20 env (deleteCartItemClient userB (CartDTO.id cartItem))
                            deleteResult `shouldSatisfy` isLeft

        it "removes product items from all carts after deleting that product" $ do
            let createRequest = CreateProductRequest
                    { createProductSellerId = 10
                    , createProductTitle = "Cascade cart cleanup"
                    , createProductDescription = "Deleted product should clean carts"
                    , createProductPrice = 13.0
                    }

            createdResult <- retryClient 20 env (createProductClient createRequest)
            case createdResult of
                Left err -> expectationFailure ("E2E setup failed: " ++ err)
                Right createdProduct -> do
                    let userA = ProductDTO.id createdProduct * 10_000 + 3
                        userB = ProductDTO.id createdProduct * 10_000 + 4
                    _ <- retryClient 20 env (addProductToCartClient userA (AddCartRequest (ProductDTO.id createdProduct)))
                    _ <- retryClient 20 env (addProductToCartClient userB (AddCartRequest (ProductDTO.id createdProduct)))

                    deleteResult <- retryClient 20 env (deleteProductByIdClient (ProductDTO.id createdProduct))
                    case deleteResult of
                        Left deleteErr -> expectationFailure ("E2E request failed: " ++ deleteErr)
                        Right _ -> pure ()

                    cartAResult <- retryClient 20 env (getCartClient userA)
                    cartBResult <- retryClient 20 env (getCartClient userB)
                    case (cartAResult, cartBResult) of
                        (Right cartA, Right cartB) -> do
                            CartDTO.items cartA `shouldBe` []
                            CartDTO.items cartB `shouldBe` []
                            CartDTO.totalPrice cartA `shouldBe` 0
                            CartDTO.totalPrice cartB `shouldBe` 0
                        (Left err, _) -> expectationFailure ("E2E request failed: " ++ err)
                        (_, Left err) -> expectationFailure ("E2E request failed: " ++ err)
