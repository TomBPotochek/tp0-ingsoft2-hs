{-# LANGUAGE OverloadedStrings #-}

module Integration.ProductsHttpSpec
    ( spec
    ) where

import Network.HTTP.Types (hContentType, methodDelete, methodGet, methodPost, methodPut)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Wai (request, shouldRespondWith, with, get, post, ResponseMatcher (..))

import Integration.Support (mkIntegrationApp)

import Test.Hspec.Wai.Matcher ((<:>), MatchBody(..))
import qualified Data.ByteString.Lazy as LBS
import Data.List (isInfixOf)

spec :: Spec
spec = with mkIntegrationApp $ do
    let bodyContainsAll :: [LBS.ByteString] -> MatchBody
        bodyContainsAll substrs = MatchBody $ \_ body ->
            let bodyStr = LBS.unpack body
            in if all (\s -> isInfixOf (LBS.unpack s) bodyStr) substrs
                then Nothing
                else Just "Not all expected substrings found in body"

    describe "RFC 7807 error format" $ do
        it "returns RFC 7807 error for bad path (404)" $ do
            get "/not-a-real-path" `shouldRespondWith` "" { matchStatus = 404
                , matchHeaders = ["Content-Type" <:> "application/problem+json"]
                , matchBody = bodyContainsAll ["type","title","status","detail","instance"]
                }

        it "returns RFC 7807 error for malformed JSON (400)" $ do
            request methodPost "/products" [("Content-Type", "application/json")] "{invalid" `shouldRespondWith`
                "" { matchStatus = 400
                   , matchHeaders = ["Content-Type" <:> "application/problem+json"]
                   , matchBody = bodyContainsAll ["type","title","status","detail","instance"]
                   }

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

    describe "DELETE /products/{id}" $ do
        it "responds with 404 for a missing product" $ do
            request methodDelete "/products/999999" [] "" `shouldRespondWith` 404

