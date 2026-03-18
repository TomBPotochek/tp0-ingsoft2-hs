module API.DTO.ProductSpec
    ( spec
    ) where

import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.Hspec (Spec, describe, it, shouldBe)

import API.DTO.Product (ProductDTO (..), toDTO)
import Domain.Product (Product (..))

spec :: Spec
spec =
    describe "toDTO" $ do
        it "maps every product field to ProductDTO" $ do
            let ts = UTCTime (fromGregorian 2026 3 17) (secondsToDiffTime 0)
                domainProduct = Product
                    { productId = 42
                    , productSellerId = 7
                    , productTitle = "Mechanical Keyboard"
                    , productDescription = "75% layout"
                    , productPrice = 129.99
                    , productCreatedAt = ts
                    , productUpdatedAt = ts
                    }
                expected = ProductDTO
                    { id = 42
                    , sellerId = 7
                    , title = "Mechanical Keyboard"
                    , description = "75% layout"
                    , price = 129.99
                    , createdAt = ts
                    , updatedAt = ts
                    }

            toDTO domainProduct `shouldBe` expected
