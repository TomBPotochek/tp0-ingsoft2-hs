{-# LANGUAGE OverloadedStrings #-}

module E2E.UsersSpec
    ( spec
    ) where

import Servant.Client (ClientEnv, ClientM, client)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldSatisfy)

import API.DTO.User (UserDTO (..))
import API.Routes (api)
import E2E.Support (retryClient)

spec :: ClientEnv -> Spec
spec env =
    describe "GET /users" $ do
        it "returns seeded users in development environment" $ do
            result <- retryClient 20 env getUsersClient
            case result of
                Left err -> expectationFailure ("E2E request failed: " ++ err)
                Right users -> users `shouldSatisfy` any ((== "Ada") . firstName)

getUsersClient :: ClientM [UserDTO]
getUsersClient = client api