module Main (main) where

import Test.Hspec (hspec)

import E2E.Support (mkEnv)
import qualified E2E.UsersSpec as UsersSpec

main :: IO ()
main = do
    env <- mkEnv
    hspec (UsersSpec.spec env)