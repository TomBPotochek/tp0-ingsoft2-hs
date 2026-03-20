{-# LANGUAGE OverloadedStrings #-}

module Integration.CartApiSpec
    ( spec
    ) where

import Data.Either (isLeft)
import Data.List (isInfixOf)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Servant (NoContent (NoContent))
import Servant.Client (BaseUrl (baseUrlPort), ClientEnv, ClientError (FailureResponse), ClientM, mkClientEnv, parseBaseUrl, runClientM)
import Servant.Client.Generic (AsClientT, genericClient)
import Test.Hspec (Spec, around, expectationFailure, it, runIO, shouldBe, shouldSatisfy)

import API.DTO.Cart (AddCartRequest (..))
import qualified API.DTO.Cart as CartDTO
import API.DTO.Product (CreateProductRequest (..))
import qualified API.DTO.Product as ProductDTO
import API.Routes (ApiRoutes (..), CartByUserRoutes (..), ProductRoutes (..))
import Integration.Support (withIntegrationApp)

spec :: Spec
spec =
    around withIntegrationApp $ do
        let apiClient = genericClient :: ApiRoutes (AsClientT ClientM)
            createProductClient = createProductRoute (productsRoutes apiClient)
            deleteProductByIdClient = deleteProductByIdRoute (productsRoutes apiClient)
            getCartClient userId = getCartRoute (cartRoutes apiClient userId)
            deleteCartClient userId = deleteCartRoute (cartRoutes apiClient userId)
            addProductToCartClient userId request = addProductToCartRoute (cartRoutes apiClient userId) request
            deleteCartItemClient userId cartItemId = deleteCartItemRoute (cartRoutes apiClient userId) cartItemId
        baseUrl <- runIO $ parseBaseUrl "http://localhost"
        manager <- runIO $ newManager defaultManagerSettings
        let clientEnv port = mkClientEnv manager (baseUrl { baseUrlPort = port })

        it "POST /cart/{userId}/items creates a cart item using product snapshot" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 20
                    , createProductTitle = "Snapshot Product " ++ unique
                    , createProductDescription = "Used for cart snapshot"
                    , createProductPrice = 88.8
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            cartItem <- runOrFail (clientEnv port) (addProductToCartClient 123 (AddCartRequest (ProductDTO.id created)))

            CartDTO.productId cartItem `shouldBe` ProductDTO.id created
            CartDTO.title cartItem `shouldBe` ProductDTO.title created
            CartDTO.unitPrice cartItem `shouldBe` ProductDTO.price created

        it "POST /cart/{userId}/items returns 404 when product does not exist" $ \port -> do
            result <- runClientM (addProductToCartClient 123 (AddCartRequest 9_999_999)) (clientEnv port)
            result `shouldSatisfy` isLeft
            case result of
                Left (FailureResponse _ response) ->
                    show response `shouldSatisfy` ("404" `isInfixOf`)
                Left err -> expectationFailure ("expected 404 FailureResponse, got: " ++ show err)
                Right _ -> expectationFailure "expected 404 but request succeeded"

        it "GET /cart/{userId} returns an empty cart for unknown user" $ \port -> do
            cart <- runOrFail (clientEnv port) (getCartClient 999_999)
            CartDTO.userId cart `shouldBe` 999_999
            CartDTO.items cart `shouldBe` []
            CartDTO.totalPrice cart `shouldBe` 0

        it "GET /cart/{userId} returns items ordered by addedAt desc then id desc and totalPrice" $ \port -> do
            unique <- uniqueSuffix
            let createRequestA = CreateProductRequest
                    { createProductSellerId = 30
                    , createProductTitle = "Cart order A " ++ unique
                    , createProductDescription = "First item"
                    , createProductPrice = 10.0
                    }
                createRequestB = CreateProductRequest
                    { createProductSellerId = 31
                    , createProductTitle = "Cart order B " ++ unique
                    , createProductDescription = "Second item"
                    , createProductPrice = 15.5
                    }

            createdA <- runOrFail (clientEnv port) (createProductClient createRequestA)
            createdB <- runOrFail (clientEnv port) (createProductClient createRequestB)
            let testUserId = ProductDTO.id createdA * 10_000 + ProductDTO.id createdB
            _ <- runOrFail (clientEnv port) (addProductToCartClient testUserId (AddCartRequest (ProductDTO.id createdA)))
            _ <- runOrFail (clientEnv port) (addProductToCartClient testUserId (AddCartRequest (ProductDTO.id createdB)))

            cart <- runOrFail (clientEnv port) (getCartClient testUserId)
            CartDTO.userId cart `shouldBe` testUserId
            map CartDTO.productId (CartDTO.items cart) `shouldBe` [ProductDTO.id createdB, ProductDTO.id createdA]
            CartDTO.totalPrice cart `shouldBe` (ProductDTO.price createdA + ProductDTO.price createdB)

        it "DELETE /products/{id} removes that product's items from all carts" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 40
                    , createProductTitle = "Cascade Product " ++ unique
                    , createProductDescription = "Used to verify cart cascade"
                    , createProductPrice = 12.5
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            let userA = ProductDTO.id created * 10_000 + 1
                userB = ProductDTO.id created * 10_000 + 2

            _ <- runOrFail (clientEnv port) (addProductToCartClient userA (AddCartRequest (ProductDTO.id created)))
            _ <- runOrFail (clientEnv port) (addProductToCartClient userB (AddCartRequest (ProductDTO.id created)))

            _ <- runOrFail (clientEnv port) (deleteProductByIdClient (ProductDTO.id created))

            cartA <- runOrFail (clientEnv port) (getCartClient userA)
            cartB <- runOrFail (clientEnv port) (getCartClient userB)

            CartDTO.items cartA `shouldBe` []
            CartDTO.items cartB `shouldBe` []
            CartDTO.totalPrice cartA `shouldBe` 0
            CartDTO.totalPrice cartB `shouldBe` 0

        it "DELETE /cart/{userId}/items/{cartItemId} removes a cart item when it belongs to the user" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 50
                    , createProductTitle = "Delete cart item " ++ unique
                    , createProductDescription = "Used to delete a specific cart item"
                    , createProductPrice = 9.9
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            let userId = ProductDTO.id created * 10_000 + 7
            cartItem <- runOrFail (clientEnv port) (addProductToCartClient userId (AddCartRequest (ProductDTO.id created)))

            deleted <- runOrFail (clientEnv port) (deleteCartItemClient userId (CartDTO.id cartItem))
            deleted `shouldBe` NoContent

            cart <- runOrFail (clientEnv port) (getCartClient userId)
            CartDTO.items cart `shouldBe` []
            CartDTO.totalPrice cart `shouldBe` 0

        it "DELETE /cart/{userId}/items/{cartItemId} returns 404 when item does not belong to user" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 51
                    , createProductTitle = "Delete wrong user " ++ unique
                    , createProductDescription = "Used to verify user scoping"
                    , createProductPrice = 7.7
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            let userA = ProductDTO.id created * 10_000 + 8
                userB = ProductDTO.id created * 10_000 + 9
            cartItem <- runOrFail (clientEnv port) (addProductToCartClient userA (AddCartRequest (ProductDTO.id created)))

            result <- runClientM (deleteCartItemClient userB (CartDTO.id cartItem)) (clientEnv port)
            result `shouldSatisfy` isLeft
            case result of
                Left (FailureResponse _ response) ->
                    show response `shouldSatisfy` ("404" `isInfixOf`)
                Left err -> expectationFailure ("expected 404 FailureResponse, got: " ++ show err)
                Right _ -> expectationFailure "expected 404 but request succeeded"

        it "DELETE /cart/{userId} wipes all items and returns 204" $ \port -> do
            unique <- uniqueSuffix
            let createRequestA = CreateProductRequest
                    { createProductSellerId = 60
                    , createProductTitle = "Wipe cart A " ++ unique
                    , createProductDescription = "First item"
                    , createProductPrice = 3.3
                    }
                createRequestB = CreateProductRequest
                    { createProductSellerId = 61
                    , createProductTitle = "Wipe cart B " ++ unique
                    , createProductDescription = "Second item"
                    , createProductPrice = 4.4
                    }

            createdA <- runOrFail (clientEnv port) (createProductClient createRequestA)
            createdB <- runOrFail (clientEnv port) (createProductClient createRequestB)
            let userId = ProductDTO.id createdA * 10_000 + ProductDTO.id createdB

            _ <- runOrFail (clientEnv port) (addProductToCartClient userId (AddCartRequest (ProductDTO.id createdA)))
            _ <- runOrFail (clientEnv port) (addProductToCartClient userId (AddCartRequest (ProductDTO.id createdB)))

            deleted <- runOrFail (clientEnv port) (deleteCartClient userId)
            deleted `shouldBe` NoContent

            cart <- runOrFail (clientEnv port) (getCartClient userId)
            CartDTO.items cart `shouldBe` []
            CartDTO.totalPrice cart `shouldBe` 0

        it "DELETE /cart/{userId} is idempotent and returns 204 for empty cart" $ \port -> do
            let userId = 8_888_888
            deleted <- runOrFail (clientEnv port) (deleteCartClient userId)
            deleted `shouldBe` NoContent

            cart <- runOrFail (clientEnv port) (getCartClient userId)
            CartDTO.items cart `shouldBe` []
            CartDTO.totalPrice cart `shouldBe` 0

runOrFail :: ClientEnv -> ClientM a -> IO a
runOrFail env action = do
    result <- runClientM action env
    either failClient pure result

failClient :: ClientError -> IO a
failClient err = expectationFailure ("integration client call failed: " ++ show err) >> error "unreachable"

uniqueSuffix :: IO String
uniqueSuffix = (show :: Integer -> String) . floor <$> getPOSIXTime
