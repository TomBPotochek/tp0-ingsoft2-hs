{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsApiSpec
    ( spec
    ) where

import Network.HTTP.Client (defaultManagerSettings, newManager)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Servant ((:<|>) (..))
import Servant.Client (BaseUrl (baseUrlPort), ClientEnv, ClientError, ClientM, client, mkClientEnv, parseBaseUrl, runClientM)
import Test.Hspec (Spec, around, expectationFailure, it, runIO, shouldBe, shouldSatisfy)

import API.DTO.Product (CreateProductRequest (..), ProductDTO (..))
import API.Routes (productApi)
import Integration.Support (withIntegrationApp)

spec :: Spec
spec =
    around withIntegrationApp $ do
        let createProductClient :<|> listProductsClient = client productApi
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

runOrFail :: ClientEnv -> ClientM a -> IO a
runOrFail env action = do
    result <- runClientM action env
    either failClient pure result

failClient :: ClientError -> IO a
failClient err = expectationFailure ("integration client call failed: " ++ show err) >> error "unreachable"

uniqueSuffix :: IO String
uniqueSuffix = (show :: Integer -> String) . floor <$> getPOSIXTime
