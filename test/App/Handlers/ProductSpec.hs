module App.Handlers.ProductSpec
    ( spec
    ) where

import Data.List (find)
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.Hspec (Spec, describe, it, shouldBe)
import Data.Function ((&))

import API.DTO.Product (CreateProductRequest (..), UpdateProductRequest (..))
import App.Effects.ProductRepository (ProductRepository (..))
import App.Error (AppError (..))
import App.Handlers.Product (createProductHandler, updateProductByIdHandler)
import App.ProductCreation (NewProduct (..))
import qualified App.ProductUpdate
import Domain.Product (Product (..))
import Polysemy (InterpreterFor, Members, Sem, interpret, run)
import Polysemy.Error (Error, runError)
import Polysemy.State (State, get, modify, put, runState)

spec :: Spec
spec = do
    describe "createProductHandler validation" $ do
        it "rejects blank title without touching repository" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 1
                    , createProductTitle = "   "
                    , createProductDescription = "desc"
                    , createProductPrice = 10.0
                    }
                (result, finalState) = runWithInMemoryRepo emptyRepoState (createProductHandler request)

            result `shouldBe` Left (InvalidInput (Just "title") "title must not be blank")
            repoCalls finalState `shouldBe` 0

        it "rejects too-low price without touching repository" $ do
            let request = CreateProductRequest
                    { createProductSellerId = 1
                    , createProductTitle = "Valid"
                    , createProductDescription = "desc"
                    , createProductPrice = 0.0
                    }
                (result, finalState) = runWithInMemoryRepo emptyRepoState (createProductHandler request)

            result `shouldBe` Left (InvalidInput (Just "price") "price must be >= 0.01")
            repoCalls finalState `shouldBe` 0

    describe "updateProductByIdHandler validation" $ do
        it "rejects blank title without touching repository" $ do
            let request = UpdateProductRequest
                    { updateProductTitle = "   "
                    , updateProductDescription = "new"
                    , updateProductPrice = 10.0
                    }
                (result, finalState) = runWithInMemoryRepo seededRepoState (updateProductByIdHandler 1 request)

            result `shouldBe` Left (InvalidInput (Just "title") "title must not be blank")
            repoCalls finalState `shouldBe` 0

        it "rejects too-low price without touching repository" $ do
            let request = UpdateProductRequest
                    { updateProductTitle = "New title"
                    , updateProductDescription = "new"
                    , updateProductPrice = 0.0
                    }
                (result, finalState) = runWithInMemoryRepo seededRepoState (updateProductByIdHandler 1 request)

            result `shouldBe` Left (InvalidInput (Just "price") "price must be >= 0.01")
            repoCalls finalState `shouldBe` 0

data RepoState = RepoState
    { repoProducts :: [Product]
    , nextProductId :: Int
    , repoCalls :: Int
    }
    deriving (Show, Eq)

emptyRepoState :: RepoState
emptyRepoState = RepoState [] 1 0

seededRepoState :: RepoState
seededRepoState =
    RepoState
        [ Product
            { productId = 1
            , productSellerId = 10
            , productTitle = "Existing"
            , productDescription = "Existing description"
            , productPrice = 25.0
            , productCreatedAt = fixedTime
            , productUpdatedAt = fixedTime
            }
        ]
        2
        0

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 3 20) (secondsToDiffTime 0)

runWithInMemoryRepo :: RepoState -> Sem '[ProductRepository, Error AppError, State RepoState] a -> (Either AppError a, RepoState)
runWithInMemoryRepo initialState sem =
    let (finalState, result) =
            sem 
            & runProductRepositoryInMemory 
            & runError 
            & runState initialState 
            & run 
     in (result, finalState)

runProductRepositoryInMemory :: Members '[State RepoState] r => InterpreterFor ProductRepository r
runProductRepositoryInMemory = interpret $ \case
    CreateProduct newProduct -> do
        modify (\st -> st {repoCalls = repoCalls st + 1})
        st <- get
        let newEntity =
                Product
                    { productId = nextProductId st
                    , productSellerId = sellerId newProduct
                    , productTitle = title newProduct
                    , productDescription = description newProduct
                    , productPrice = price newProduct
                    , productCreatedAt = fixedTime
                    , productUpdatedAt = fixedTime
                    }
        put
            st
                { repoProducts = repoProducts st ++ [newEntity]
                , nextProductId = nextProductId st + 1
                }
        pure newEntity
    ListProducts -> do
        modify (\st -> st {repoCalls = repoCalls st + 1})
        repoProducts <$> get
    GetProductById requestedId -> do
        modify (\st -> st {repoCalls = repoCalls st + 1})
        products <- repoProducts <$> get
        pure (find ((== requestedId) . productId) products)
    UpdateProductById requestedId updatePayload -> do
        modify (\st -> st {repoCalls = repoCalls st + 1})
        st <- get
        let maybeExisting = find ((== requestedId) . productId) (repoProducts st)
        case maybeExisting of
            Nothing -> pure Nothing
            Just existing -> do
                let updated =
                        existing
                            { productTitle = App.ProductUpdate.title updatePayload
                            , productDescription = App.ProductUpdate.description updatePayload
                            , productPrice = App.ProductUpdate.price updatePayload
                            , productUpdatedAt = fixedTime
                            }
                    updatedProducts = map (\p -> if productId p == requestedId then updated else p) (repoProducts st)
                put st {repoProducts = updatedProducts}
                pure (Just updated)
    DeleteProductById requestedId -> do
        modify (\st -> st {repoCalls = repoCalls st + 1})
        st <- get
        let exists = any ((== requestedId) . productId) (repoProducts st)
            remaining = filter ((/= requestedId) . productId) (repoProducts st)
        if exists
            then put st {repoProducts = remaining} >> pure True
            else pure False
