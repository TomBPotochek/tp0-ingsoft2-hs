module Main (main) where

import Test.Hspec (hspec)

import qualified API.DTO.ProductSpec as ProductSpec

main :: IO ()
main = hspec ProductSpec.spec
