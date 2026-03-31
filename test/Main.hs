module Main (main) where

import Test.Hspec (hspec)


import qualified App.Handlers.ProductSpec as ProductHandlerSpec
import qualified App.Handlers.CartSpec as CartHandlerSpec
import qualified API.DTO.ProductSpec as ProductSpec
import qualified App.SupportSpec

main :: IO ()
main = hspec $ do
    ProductSpec.spec
    ProductHandlerSpec.spec
    CartHandlerSpec.spec
    App.SupportSpec.spec
