{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ViewPatterns #-}

module App.Support
    ( 
     Money
    , unMoney
    , pattern ViewMoney
    , moneyFromScientific
    , roundValTo
    ) where

import Data.Fixed (Centi)
import qualified Data.Text as Text
import Database.Persist
    ( PersistField (fromPersistValue, toPersistValue)
    , PersistValue (PersistDouble, PersistInt64, PersistRational, PersistText)
    )
import Database.Persist.Sql (PersistFieldSql (sqlType), SqlType (SqlNumeric))
import Data.Text.Read (double)
import Data.Scientific

newtype Money = Money
    { unMoney :: Centi
    }
    deriving stock (Show, Eq, Ord)
    deriving newtype (Num, Real, Fractional, RealFrac)

unMoneyToScientific :: Money -> Scientific
unMoneyToScientific (Money c) = fromRational (toRational c)

pattern ViewMoney :: Scientific -> Money
pattern ViewMoney a <- (unMoneyToScientific -> a)
{-# COMPLETE ViewMoney #-}

-- because of the no orphan instances constraint, we have to define these instances here instead of in the persistence module, which would be more appropriate
-- the alternative is defining Money in the persistence module, but still, Money is a domain object
instance PersistField Money where
    toPersistValue = PersistRational . toRational . unMoney

    -- see https://hackage-content.haskell.org/package/persistent/docs/Database-Persist-Types.html#t:PersistValue
    fromPersistValue value =
        case value of
            PersistRational r -> Right (Money (fromRational r))
            PersistDouble d -> Right (Money (realToFrac d))
            PersistInt64 i -> Right (Money (fromIntegral i))
            PersistText t ->
                case double t of
                    Right (d, _) -> Right (Money (realToFrac d))
                    Left err -> Left (Text.pack err)
            anythingElse -> Left $ Text.pack $ "Invalid PersistValue for Money: " ++ show anythingElse

instance PersistFieldSql Money where
    sqlType _ = SqlNumeric 12 2

moneyFromScientific :: Scientific -> Maybe Money
moneyFromScientific = roundValTo 2

roundValTo :: Int -> Scientific -> Maybe Money
roundValTo n val
    | val < 0   = Nothing
    | n < 0   = Nothing
    | otherwise =
        let factor = 10 ^ n :: Integer
            maxVal = 9999999999.99 :: Scientific  -- matches sqltype=numeric(12,2)
            capped = min val maxVal
            scaled = capped * fromInteger factor
            roundedInt = floor (scaled + 0.5)
            rounded = fromInteger roundedInt / fromInteger factor
        in Just (Money rounded)