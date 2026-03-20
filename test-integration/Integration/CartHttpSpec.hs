{-# LANGUAGE OverloadedStrings #-}

module Integration.CartHttpSpec
    ( spec
    ) where

import Network.HTTP.Types (hContentType, methodDelete, methodGet, methodPost)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Wai (request, shouldRespondWith, with)

import Integration.Support (mkIntegrationApp)

spec :: Spec
spec = with mkIntegrationApp $ do
    describe "POST /cart/{userId}/items" $ do
        it "responds with 404 when product does not exist" $ do
            request
                methodPost
                "/cart/123/items"
                [(hContentType, "application/json")]
                "{\"productId\":999999}"
                `shouldRespondWith` 404

        it "responds with 400 for malformed JSON" $ do
            request
                methodPost
                "/cart/123/items"
                [(hContentType, "application/json")]
                "{invalid"
                `shouldRespondWith` 400

    describe "GET /cart/{userId}" $ do
        it "responds with 200" $ do
            request methodGet "/cart/123" [] "" `shouldRespondWith` 200

    describe "DELETE /cart/{userId}" $ do
        it "responds with 204" $ do
            request methodDelete "/cart/123" [] "" `shouldRespondWith` 204

    describe "DELETE /cart/{userId}/items/{cartItemId}" $ do
        it "responds with 404 for a missing cart item" $ do
            request methodDelete "/cart/123/items/999999" [] "" `shouldRespondWith` 404
