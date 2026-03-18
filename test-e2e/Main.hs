module Main (main) where

import Test.Hspec (hspec)

import E2E.Support (mkEnv)
import qualified E2E.ProductsSpec as ProductsSpec

main :: IO ()
main = do
    env <- mkEnv
    hspec (ProductsSpec.spec env)