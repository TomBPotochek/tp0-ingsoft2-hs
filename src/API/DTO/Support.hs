module API.DTO.Support 
  ( dropPrefixFromFields
  ) where

import Data.Char (toLower)
import Data.List (stripPrefix)

dropPrefixFromFields :: String -> String -> String
dropPrefixFromFields prefix fieldName =
    case stripPrefix prefix fieldName of
        Nothing -> fieldName
        Just [] -> []
        Just (x:xs) -> toLower x : xs