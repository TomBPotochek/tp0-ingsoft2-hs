{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsApiSpec
    ( spec
    ) where

import Data.Either (isLeft)
import Data.List (isInfixOf)
import qualified API.DTO.Product as ProductDTO
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Servant ((:<|>) (..))
import Servant (NoContent (NoContent))
import Servant.Client (BaseUrl (baseUrlPort), ClientEnv, ClientError (FailureResponse), ClientM, client, mkClientEnv, parseBaseUrl, runClientM)
import Test.Hspec (Spec, around, expectationFailure, it, runIO, shouldBe, shouldSatisfy)

import API.DTO.Product (CreateProductRequest (..), ProductDTO (..), UpdateProductRequest (..))
import API.Routes (productApi)
import Integration.Support (withIntegrationApp)

spec :: Spec
spec =
    around withIntegrationApp $ do
        let createProductClient :<|> (listProductsClient :<|> (getProductByIdClient :<|> (updateProductByIdClient :<|> deleteProductByIdClient))) = client productApi
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
            sellerId created `shouldBe` 7
            title created `shouldBe` productTitle

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
            sellerId created `shouldBe` 42
            title created `shouldBe` productTitle

            products <- runOrFail (clientEnv port) listProductsClient
            products `shouldSatisfy` any ((== productTitle) . title)

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
            sellerId found `shouldBe` sellerId created
            title found `shouldBe` title created
            description found `shouldBe` description created
            price found `shouldBe` price created

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
            sellerId updated `shouldBe` sellerId created
            title updated `shouldBe` updateProductTitle updateRequest
            description updated `shouldBe` updateProductDescription updateRequest
            price updated `shouldBe` updateProductPrice updateRequest

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

runOrFail :: ClientEnv -> ClientM a -> IO a
runOrFail env action = do
    result <- runClientM action env
    either failClient pure result

failClient :: ClientError -> IO a
failClient err = expectationFailure ("integration client call failed: " ++ show err) >> error "unreachable"

uniqueSuffix :: IO String
uniqueSuffix = (show :: Integer -> String) . floor <$> getPOSIXTime
