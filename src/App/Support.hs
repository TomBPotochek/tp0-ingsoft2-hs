{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module App.Support
    ( 
     Money
    , unMoney
    , pattern ViewMoney
    , moneyFromDouble
    , roundValTo
    ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.OpenApi (ToSchema)
import Data.Scientific (Scientific, base10Exponent, fromFloatDigits, scientific, coefficient)
import qualified Data.Text as Text
import Database.Persist
    ( PersistField (fromPersistValue, toPersistValue)
    , PersistValue (PersistDouble, PersistInt64, PersistRational, PersistText)
    )
import Database.Persist.Sql (PersistFieldSql (sqlType), SqlType (SqlNumeric))
import Data.Text.Read (double)

newtype Money = Money
    { unMoney :: Scientific
    }
    deriving stock (Show, Eq, Ord)
    deriving newtype (Num, Real, Fractional, RealFrac, ToJSON, FromJSON, ToSchema)

pattern ViewMoney :: Scientific -> Money
pattern ViewMoney a <- Money {unMoney = a}

-- because of the no orphan instances constraint, we have to define these instances here instead of in the persistence module, which would be more appropriate
-- the alternative is defining Money in the persistence module, but still, Money is a domain object
instance PersistField Money where
    toPersistValue = PersistRational . toRational . unMoney

    fromPersistValue value =
        case value of
            PersistRational r -> Right (Money (fromRational r))
            PersistDouble d -> Right (Money (fromFloatDigits d))
            PersistInt64 i -> Right (Money (fromIntegral i))
            PersistText t ->
                case double t of
                    Right (d, _) -> Right (Money (fromFloatDigits d))
                    Left err -> Left (Text.pack err)
            anythingElse -> Left $ Text.pack $ "Invalid PersistValue for Money: " ++ show anythingElse

instance PersistFieldSql Money where
    sqlType _ = SqlNumeric 12 2

moneyFromDouble :: Double -> Maybe Money
moneyFromDouble = roundValTo 2

roundValTo :: Int -> Double -> Maybe Money
roundValTo n val
    | val < 0   = Nothing
    | otherwise =
        let factor = 10 ^ n
            x = val * factor
            rounded = (fromIntegral $ if x >= 0 then floor (x + 0.5) else ceiling (x - 0.5)) / factor
        in Just $ Money (fromFloatDigits rounded)