module App.SupportSpec (spec) where

import App.Support (roundValTo, pattern ViewMoney)
import Test.Hspec
import Test.QuickCheck
import Data.Scientific (Scientific)

spec :: Spec
spec = describe "roundValTo" $ do
    it "rounds correctly to 2 decimals (half up, QuickCheck)" $ 
        property $ \(Positive (base :: Integer)) (centsRaw :: Int) (thirdDigitRaw :: Int) ->
            let cents = abs centsRaw `mod` 100
                thirdDigit = abs thirdDigitRaw `mod` 10
                -- Calculate expected cents after rounding
                (finalBase, finalCents) =
                  if thirdDigit >= 5
                  then let newCents = cents + 1
                       in if newCents == 100 then (base + 1, 0) else (base, newCents)
                  else (base, cents)
                expected = read (show finalBase ++ "." ++ (if finalCents < 10 then "0" else "") ++ show finalCents) :: Scientific
                inputStr = show base ++ "." ++ (if cents < 10 then "0" else "") ++ show cents ++ show thirdDigit
                input = read inputStr :: Scientific
                actual = fmap (\(ViewMoney s) -> s) (roundValTo 2 input)
            in actual == Just expected

    it "returns Nothing for negative input" $ do
        roundValTo 2 (-1.0) `shouldBe` Nothing
        roundValTo 0 (-0.01) `shouldBe` Nothing

    it "rounds known edge cases (half up)" $ do
        let cases =
                [ (80.115, 2, 80.12)
                , (80.125, 2, 80.13)
                , (80.135, 2, 80.14)
                , (80.145, 2, 80.15)
                , (80.105, 2, 80.11)
                , (80.155, 2, 80.16)
                , (10.005, 2, 10.01)
                , (10.015, 2, 10.02)
                , (10.025, 2, 10.03)
                , (10.035, 2, 10.04)
                , (10.045, 2, 10.05)
                , (10.055, 2, 10.06)
                , (10.065, 2, 10.07)
                , (10.075, 2, 10.08)
                , (10.085, 2, 10.09)
                , (10.095, 2, 10.10)
                ]
        mapM_ (\(input, n, expected) ->
            let actual = fmap (\(ViewMoney s) -> s) (roundValTo n (input :: Scientific))
            in actual `shouldBe` Just (expected :: Scientific)
            ) cases


genPair :: Gen (Integer, Integer)
genPair = do
    num <- choose (0, 10_000_000 :: Integer)
    denom_exponent <- elements [2, 3, 4, 5, 6]
    return (num, denom_exponent)
