{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsHttpSpec
    ( spec
    ) where

import Network.HTTP.Types (hContentType, methodGet, methodPost)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Wai (request, shouldRespondWith, with)

import Integration.Support (mkIntegrationApp)

spec :: Spec
spec = with mkIntegrationApp $ do
    describe "GET /products" $ do
        it "responds with 200" $ do
            request methodGet "/products" [] "" `shouldRespondWith` 200

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
