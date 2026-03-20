{-# LANGUAGE OverloadedStrings #-}

module Integration.ErrorHttpSpec
    ( spec
    ) where

import Network.HTTP.Types (methodGet)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Wai (request, shouldRespondWith, with)

import Lib (unexpectedExceptionTo500Middleware)

spec :: Spec
spec =
    with
        ( pure
            ( unexpectedExceptionTo500Middleware
                (\_ _ -> error "boom: unexpected exception")
            )
        )
        $ do
            describe "unexpectedExceptionTo500Middleware" $ do
                it "returns 500 when an unexpected exception is thrown" $ do
                    request methodGet "/" [] "" `shouldRespondWith` 500
