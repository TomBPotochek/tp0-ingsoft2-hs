{-# OPTIONS_GHC -Wno-missing-signatures #-}

module App.Handlers.CartSpec
    ( spec
    ) where

import Data.List (find)
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Data.Function ((&))

import API.DTO.Cart (AddCartRequest (..), CartDTO (..), CartItemDTO (..))
import API.DTO.Support (ApiResponse (..))
import App.Effects.CartRepository (CartRepository (..))
import App.Error (AppError (..))
import App.Handlers.Cart (addProductToCartHandler, deleteCartHandler, deleteCartItemHandler, getCartHandler)
import Domain.CartItem (CartItem (..))
import Polysemy (InterpreterFor, Members, Sem, interpret, run)
import Polysemy.Error (Error)
import Polysemy.Error (runError)
import Polysemy.State (State, get, modify, put, runState)
import Servant (NoContent (NoContent))

spec :: Spec
spec = do
    describe "getCartHandler" $ do
        it "returns cart items and computes total from unit prices" $ do
            let initial = seededRepoState
                (result, _) = runWithInMemoryRepo initial (getCartHandler 1)

            fmap (totalPrice . apiResponseData) result `shouldSatisfy` \case
                Right total -> abs (total - 179.98) < 1e-9
                Left _ -> False
            fmap (length . items . apiResponseData) result `shouldBe` Right 2

    describe "addProductToCartHandler" $ do
        it "returns ProductNotFound when the product does not exist" $ do
            let request = AddCartRequest {addCartProductId = 999}
                (result, _) = runWithInMemoryRepo emptyRepoState (addProductToCartHandler 1 request)

            result `shouldBe` Left (ProductNotFound 999)

        it "adds a product and returns the created cart item DTO" $ do
            let request = AddCartRequest {addCartProductId = 1}
                (result, finalState) = runWithInMemoryRepo emptyRepoState (addProductToCartHandler 7 request)

            fmap (productId . apiResponseData) result `shouldBe` Right 1
            fmap (unitPrice . apiResponseData) result `shouldBe` Right 129.99
            length (repoCartItems finalState) `shouldBe` 1

    describe "deleteCartItemHandler" $ do
        it "returns NoContent when deletion succeeds" $ do
            let (result, finalState) = runWithInMemoryRepo seededRepoState (deleteCartItemHandler 1 1)

            result `shouldBe` Right NoContent
            map cartItemId (repoCartItems finalState) `shouldBe` [2, 3]

        it "returns CartItemNotFound when item does not belong to user" $ do
            let (result, _) = runWithInMemoryRepo seededRepoState (deleteCartItemHandler 2 1)

            result `shouldBe` Left (CartItemNotFound 2 1)

    describe "deleteCartHandler" $ do
        it "wipes all items for the requested user only" $ do
            let (result, finalState) = runWithInMemoryRepo seededRepoState (deleteCartHandler 1)

            result `shouldBe` Right NoContent
            map cartItemUserId (repoCartItems finalState) `shouldBe` [2]

data RepoState = RepoState
    { repoCartItems :: [CartItem]
    , knownProducts :: [(Int, String, Double)]
    , nextCartItemId :: Int
    }
    deriving (Show, Eq)

emptyRepoState :: RepoState
emptyRepoState = RepoState [] defaultProducts 1

seededRepoState :: RepoState
seededRepoState =
    RepoState
        [ CartItem 1 1 1 "Mechanical Keyboard" 129.99 fixedTime
        , CartItem 2 1 2 "Wireless Mouse" 49.99 fixedTime
        , CartItem 3 2 3 "USB-C Hub" 35.00 fixedTime
        ]
        defaultProducts
        4

defaultProducts :: [(Int, String, Double)]
defaultProducts =
    [ (1, "Mechanical Keyboard", 129.99)
    , (2, "Wireless Mouse", 49.99)
    , (3, "USB-C Hub", 35.00)
    ]

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 3 20) (secondsToDiffTime 0)

runWithInMemoryRepo initialState sem =
    let (finalState, result) =
            sem
            & runCartRepositoryInMemory
            & runError
            & runState initialState
            & run
     in (result, finalState)

runWithInMemoryRepo :: RepoState -> Sem '[CartRepository, Error AppError, State RepoState] a -> (Either AppError a, RepoState)

runCartRepositoryInMemory :: Members '[State RepoState] r => InterpreterFor CartRepository r
runCartRepositoryInMemory = interpret $ \case
    GetCartByUserId userId -> do
        st <- get
        pure (filter ((== userId) . cartItemUserId) (repoCartItems st))
    DeleteCartByUserId userId ->
        modify (\st -> st {repoCartItems = filter ((/= userId) . cartItemUserId) (repoCartItems st)})
    AddProductToCart userId productIdRequested -> do
        st <- get
        case find (\(pid, _, _) -> pid == productIdRequested) (knownProducts st) of
            Nothing -> pure Nothing
            Just (_, titleValue, unitPriceValue) -> do
                let newItem =
                        CartItem
                            { cartItemId = nextCartItemId st
                            , cartItemUserId = userId
                            , cartItemProductId = productIdRequested
                            , cartItemTitle = titleValue
                            , cartItemUnitPrice = unitPriceValue
                            , cartItemAddedAt = fixedTime
                            }
                put
                    st
                        { repoCartItems = repoCartItems st ++ [newItem]
                        , nextCartItemId = nextCartItemId st + 1
                        }
                pure (Just newItem)
    DeleteCartItemById userId cartItemIdRequested -> do
        st <- get
        case find ((== cartItemIdRequested) . cartItemId) (repoCartItems st) of
            Nothing -> pure False
            Just item
                | cartItemUserId item /= userId -> pure False
                | otherwise -> do
                    put st {repoCartItems = filter ((/= cartItemIdRequested) . cartItemId) (repoCartItems st)}
                    pure True
