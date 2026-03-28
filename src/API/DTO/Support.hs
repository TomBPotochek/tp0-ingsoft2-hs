{-# LANGUAGE DeriveGeneric #-}

module API.DTO.Support
  ( dropPrefixFromFields
  , ApiResponse(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Options(..)
  , ToJSON(..)
  , defaultOptions
  , fieldLabelModifier
  , genericParseJSON
  , genericToJSON
  )
import Data.Char (toLower)
import Data.List (stripPrefix)
import Data.OpenApi (NamedSchema(..), SchemaOptions, ToSchema(..), genericDeclareNamedSchema)
import qualified Data.OpenApi as OpenApi
import Data.Proxy (Proxy(..))
import GHC.Generics (Generic)

data ApiResponse a = ApiResponse
  { apiResponseData :: a
  }
  deriving (Show, Eq, Generic)

instance FromJSON a => FromJSON (ApiResponse a) where
  parseJSON = genericParseJSON apiResponseJSONOptions

instance ToJSON a => ToJSON (ApiResponse a) where
  toJSON = genericToJSON apiResponseJSONOptions

instance ToSchema a => ToSchema (ApiResponse a) where
-- we set the first arg of NamedSchema to Nothing to avoid having "ApiResponse" as the name of the schema in the generated OpenAPI spec, 
-- since it's just a wrapper and doesn't need a named schema
  declareNamedSchema _ = do
    NamedSchema _ schema <- genericDeclareNamedSchema apiResponseSchemaOptions (Proxy :: Proxy (ApiResponse a))
    pure (NamedSchema Nothing schema)

apiResponseJSONOptions :: Options
apiResponseJSONOptions = defaultOptions
  { fieldLabelModifier = dropPrefixFromFields "apiResponse" }

apiResponseSchemaOptions :: SchemaOptions
apiResponseSchemaOptions = OpenApi.defaultSchemaOptions
  { OpenApi.fieldLabelModifier = dropPrefixFromFields "apiResponse" }

dropPrefixFromFields :: String -> String -> String
dropPrefixFromFields prefix fieldName =
    case stripPrefix prefix fieldName of
        Nothing -> fieldName
        Just [] -> []
        Just (x:xs) -> toLower x : xs