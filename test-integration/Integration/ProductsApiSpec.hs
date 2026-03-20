{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsApiSpec
    ( spec
    ) where

import Data.Either (isLeft)
import Data.List (isInfixOf)
import API.DTO.Cart (AddCartRequest (..))
import qualified API.DTO.Cart as CartDTO
import qualified API.DTO.Product as ProductDTO
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Servant (NoContent (NoContent))
import Servant.Client (BaseUrl (baseUrlPort), ClientEnv, ClientError (FailureResponse), ClientM, mkClientEnv, parseBaseUrl, runClientM)
import Servant.Client.Generic (AsClientT, genericClient)
import Test.Hspec (Spec, around, expectationFailure, it, runIO, shouldBe, shouldSatisfy)

import API.DTO.Product (CreateProductRequest (..), UpdateProductRequest (..))
import API.Routes (ApiRoutes (..), CartByUserRoutes (..), ProductRoutes (..))
import Integration.Support (withIntegrationApp)

spec :: Spec
spec =
    around withIntegrationApp $ do
        let apiClient = genericClient :: ApiRoutes (AsClientT ClientM)
            createProductClient = createProductRoute (productsRoutes apiClient)
            listProductsClient = listProductsRoute (productsRoutes apiClient)
            getProductByIdClient = getProductByIdRoute (productsRoutes apiClient)
            updateProductByIdClient = updateProductByIdRoute (productsRoutes apiClient)
            deleteProductByIdClient = deleteProductByIdRoute (productsRoutes apiClient)
            getCartClient userId = getCartRoute (cartRoutes apiClient userId)
            addProductToCartClient userId request = addProductToCartRoute (cartRoutes apiClient userId) request
        baseUrl <- runIO $ parseBaseUrl "http://localhost"
        manager <- runIO $ newManager defaultManagerSettings
        let clientEnv port = mkClientEnv manager (baseUrl { baseUrlPort = port })

        it "POST /products creates a product" $ \port -> do
            unique <- uniqueSuffix
            let productTitle = "Create-only Product " ++ unique
                request = CreateProductRequest
                    { createProductSellerId = 7
                    , createProductTitle = productTitle
                    , createProductDescription = "Created in integration test"
                    , createProductPrice = 19.99
                    }

            created <- runOrFail (clientEnv port) (createProductClient request)
            ProductDTO.sellerId created `shouldBe` 7
            ProductDTO.title created `shouldBe` productTitle

        it "GET /products returns the created product" $ \port -> do
            unique <- uniqueSuffix
            let productTitle = "Integration Product " ++ unique
                request = CreateProductRequest
                    { createProductSellerId = 42
                    , createProductTitle = productTitle
                    , createProductDescription = "Created via in-process Servant client"
                    , createProductPrice = 55.5
                    }

            created <- runOrFail (clientEnv port) (createProductClient request)
            ProductDTO.sellerId created `shouldBe` 42
            ProductDTO.title created `shouldBe` productTitle

            products <- runOrFail (clientEnv port) listProductsClient
            products `shouldSatisfy` any ((== productTitle) . ProductDTO.title)

        it "GET /products/{id} returns the product when it exists" $ \port -> do
            unique <- uniqueSuffix
            let request = CreateProductRequest
                    { createProductSellerId = 9
                    , createProductTitle = "Get-by-id Product " ++ unique
                    , createProductDescription = "Lookup by id"
                    , createProductPrice = 77.7
                    }

            created <- runOrFail (clientEnv port) (createProductClient request)
            found <- runOrFail (clientEnv port) (getProductByIdClient (ProductDTO.id created))
            ProductDTO.id found `shouldBe` ProductDTO.id created
            ProductDTO.sellerId found `shouldBe` ProductDTO.sellerId created
            ProductDTO.title found `shouldBe` ProductDTO.title created
            ProductDTO.description found `shouldBe` ProductDTO.description created
            ProductDTO.price found `shouldBe` ProductDTO.price created

        it "GET /products/{id} returns 404 when the product does not exist" $ \port -> do
            result <- runClientM (getProductByIdClient 9_999_999) (clientEnv port)
            result `shouldSatisfy` isLeft
            case result of
                Left (FailureResponse _ response) ->
                    show response `shouldSatisfy` ("404" `isInfixOf`)
                Left err -> expectationFailure ("expected 404 FailureResponse, got: " ++ show err)
                Right _ -> expectationFailure "expected 404 but request succeeded"

        it "PUT /products/{id} updates an existing product" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 11
                    , createProductTitle = "Original " ++ unique
                    , createProductDescription = "Original description"
                    , createProductPrice = 33.3
                    }
                updateRequest = UpdateProductRequest
                    { updateProductTitle = "Updated " ++ unique
                    , updateProductDescription = "Updated description"
                    , updateProductPrice = 44.4
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            updated <- runOrFail (clientEnv port) (updateProductByIdClient (ProductDTO.id created) updateRequest)

            ProductDTO.id updated `shouldBe` ProductDTO.id created
            ProductDTO.sellerId updated `shouldBe` ProductDTO.sellerId created
            ProductDTO.title updated `shouldBe` updateProductTitle updateRequest
            ProductDTO.description updated `shouldBe` updateProductDescription updateRequest
            ProductDTO.price updated `shouldBe` updateProductPrice updateRequest

        it "PUT /products/{id} returns 404 when the product does not exist" $ \port -> do
            let updateRequest = UpdateProductRequest
                    { updateProductTitle = "No product"
                    , updateProductDescription = "Missing"
                    , updateProductPrice = 1.0
                    }

            result <- runClientM (updateProductByIdClient 9_999_999 updateRequest) (clientEnv port)
            result `shouldSatisfy` isLeft
            case result of
                Left (FailureResponse _ response) ->
                    show response `shouldSatisfy` ("404" `isInfixOf`)
                Left err -> expectationFailure ("expected 404 FailureResponse, got: " ++ show err)
                Right _ -> expectationFailure "expected 404 but request succeeded"

        it "DELETE /products/{id} deletes an existing product" $ \port -> do
            unique <- uniqueSuffix
            let createRequest = CreateProductRequest
                    { createProductSellerId = 12
                    , createProductTitle = "Delete me " ++ unique
                    , createProductDescription = "To be deleted"
                    , createProductPrice = 22.2
                    }

            created <- runOrFail (clientEnv port) (createProductClient createRequest)
            deleted <- runOrFail (clientEnv port) (deleteProductByIdClient (ProductDTO.id created))
            deleted `shouldBe` NoContent

            getAfterDelete <- runClientM (getProductByIdClient (ProductDTO.id created)) (clientEnv port)
            getAfterDelete `shouldSatisfy` isLeft

        it "DELETE /products/{id} returns 404 when the product does not exist" $ \port -> do
            result <- runClientM (deleteProductByIdClient 9_999_999) (clientEnv port)
            result `shouldSatisfy` isLeft
            case result of
                Left (FailureResponse _ response) ->
                    show response `shouldSatisfy` ("404" `isInfixOf`)
                Left err -> expectationFailure ("expected 404 FailureResponse, got: " ++ show err)
                Right _ -> expectationFailure "expected 404 but request succeeded"

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
            _ <- runOrFail (clientEnv port) (addProductToCartClient 321 (AddCartRequest (ProductDTO.id createdA)))
            _ <- runOrFail (clientEnv port) (addProductToCartClient 321 (AddCartRequest (ProductDTO.id createdB)))

            cart <- runOrFail (clientEnv port) (getCartClient 321)
            CartDTO.userId cart `shouldBe` 321
            map CartDTO.productId (CartDTO.items cart) `shouldBe` [ProductDTO.id createdB, ProductDTO.id createdA]
            CartDTO.totalPrice cart `shouldBe` (ProductDTO.price createdA + ProductDTO.price createdB)

runOrFail :: ClientEnv -> ClientM a -> IO a
runOrFail env action = do
    result <- runClientM action env
    either failClient pure result

failClient :: ClientError -> IO a
failClient err = expectationFailure ("integration client call failed: " ++ show err) >> error "unreachable"

uniqueSuffix :: IO String
uniqueSuffix = (show :: Integer -> String) . floor <$> getPOSIXTime
