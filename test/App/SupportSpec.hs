module App.SupportSpec (spec) where

import App.Support (roundValTo, pattern ViewMoney)
import Test.Hspec
import Test.QuickCheck
import Data.Maybe (fromJust)

spec :: Spec
spec = describe "roundValTo" $ do
    it "rounds to n decimal places (property)" $ property $ \(NonNegative d) (NonNegative n') ->
        let n = n' `mod` 6  -- limit to reasonable decimal places
            val = d / 1000000  -- keep values small
            result = roundValTo n val
        in case result of
            Nothing -> val < 0
            Just (ViewMoney s) ->
                let str = show (fromRational (toRational s) :: Double)
                    afterDot = dropWhile (/= '.') str
                in n == 0 || length (drop 1 afterDot) <= n


    it "matches round half up for 2 decimals (diagnostic)" $ 
        forAll (choose (0, 10000 :: Double)) $ \x ->
            let expected =
                    let str = showFFloat3 x
                        (whole, frac) = break (=='.') str
                        fracDigits = take 3 $ drop 1 frac ++ repeat '0'
                        d2 = read (take 2 fracDigits) :: Int
                        d3 = read [fracDigits !! 2] :: Int
                        up = if d3 >= 5 then 1 else 0
                        rounded =
                            fromIntegral (read whole :: Int) + (fromIntegral (d2 + up)) / 100
                    in rounded
                result = roundValTo 2 x
                actual = fmap (\(ViewMoney s) -> fromRational (toRational s) :: Double) result
            in counterexample (
                "Input:    " ++ show x ++
                "\nExpected (half up): " ++ show expected ++
                "\nActual:   " ++ show actual ++
                "\nRaw result: " ++ show result
            ) (actual == Just expected)

    it "returns Nothing for negative input" $ do
        roundValTo 2 (-1.0) `shouldBe` Nothing
        roundValTo 0 (-0.01) `shouldBe` Nothing


-- Helper for fixed-point string formatting
showFFloat3 :: Double -> String
showFFloat3 v =
    let str = show (fromRational (toRational v) :: Double)
        (whole, frac) = break (=='.') str
        fracDigits = take 3 $ drop 1 frac ++ repeat '0'
    in whole ++ "." ++ fracDigits
      where
        showFFloat :: Maybe Int -> Double -> String -> String
        showFFloat (Just n) v s =
            let str = show (fromRational (toRational v) :: Double)
                (whole, frac) = break (=='.') str
                fracDigits = take n $ drop 1 frac ++ repeat '0'
            in whole ++ "." ++ fracDigits ++ s
        showFFloat Nothing v s = show v ++ s


