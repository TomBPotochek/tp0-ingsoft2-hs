module Main (main) where

import Test.Hspec (hspec)

import qualified Integration.CartApiSpec as CartApiSpec
import qualified Integration.CartHttpSpec as CartHttpSpec
import qualified Integration.ProductsApiSpec as ProductsApiSpec
import qualified Integration.ProductsHttpSpec as ProductsHttpSpec

main :: IO ()
main = hspec $ do
    ProductsApiSpec.spec
    ProductsHttpSpec.spec
    CartApiSpec.spec
    CartHttpSpec.spec
