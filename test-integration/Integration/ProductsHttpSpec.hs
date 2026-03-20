{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsHttpSpec
    ( spec
    ) where

import Network.HTTP.Types (hContentType, methodGet, methodPost, methodPut)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Wai (request, shouldRespondWith, with)

import Integration.Support (mkIntegrationApp)

spec :: Spec
spec = with mkIntegrationApp $ do
    describe "GET /products" $ do
        it "responds with 200" $ do
            request methodGet "/products" [] "" `shouldRespondWith` 200

    describe "GET /products/{id}" $ do
        it "responds with 404 for a missing product" $ do
            request methodGet "/products/999999" [] "" `shouldRespondWith` 404

    describe "POST /products" $ do
        it "responds with 400 for malformed JSON" $ do
            request
                methodPost
                "/products"
                [(hContentType, "application/json")]
                "{invalid"
                `shouldRespondWith` 400

        it "responds with 400 when required fields are missing" $ do
            request
                methodPost
                "/products"
                [(hContentType, "application/json")]
                "{}"
                `shouldRespondWith` 400

        it "responds with 400 when field types are invalid" $ do
            request
                methodPost
                "/products"
                [(hContentType, "application/json")]
                "{\"sellerId\":\"abc\",\"title\":1,\"description\":true,\"price\":\"x\"}"
                `shouldRespondWith` 400

        it "responds with 400 when business validation fails" $ do
            request
                methodPost
                "/products"
                [(hContentType, "application/json")]
                "{\"sellerId\":1,\"title\":\"   \",\"description\":\"x\",\"price\":9.99}"
                `shouldRespondWith` 400

    describe "PUT /products/{id}" $ do
        it "responds with 404 for a missing product" $ do
            request
                methodPut
                "/products/999999"
                [(hContentType, "application/json")]
                "{\"title\":\"x\",\"description\":\"y\",\"price\":1.0}"
                `shouldRespondWith` 404

        it "responds with 400 when business validation fails" $ do
            request
                methodPut
                "/products/999999"
                [(hContentType, "application/json")]
                "{\"title\":\"   \",\"description\":\"y\",\"price\":1.0}"
                `shouldRespondWith` 400
