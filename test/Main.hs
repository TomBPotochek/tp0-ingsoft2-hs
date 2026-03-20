module Main (main) where

import Test.Hspec (hspec)

import qualified App.Handlers.ProductSpec as ProductHandlerSpec
import qualified API.DTO.ProductSpec as ProductSpec

main :: IO ()
main = hspec $ do
    ProductSpec.spec
    ProductHandlerSpec.spec
