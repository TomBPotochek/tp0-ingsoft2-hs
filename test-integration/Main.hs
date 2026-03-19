module Main (main) where

import Test.Hspec (hspec)

import qualified Integration.ProductsApiSpec as ProductsApiSpec
import qualified Integration.ProductsHttpSpec as ProductsHttpSpec

main :: IO ()
main = hspec $ do
    ProductsApiSpec.spec
    ProductsHttpSpec.spec
