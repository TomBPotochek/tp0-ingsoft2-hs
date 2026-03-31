module App.Handlers.Cart
    ( getCartHandler
    , deleteCartHandler
    , addProductToCartHandler
    , deleteCartItemHandler
    ) where

import API.DTO.Cart (AddCartRequest (..), CartDTO, CartItemDTO, toCartDTO, toDTO)
import API.DTO.Support (ApiResponse (..))
import App.Effects.CartRepository (CartRepository, addProductToCart, deleteCartByUserId, deleteCartItemById, getCartByUserId)
import App.Error (AppError (CartItemNotFound, ProductNotFound))
import Domain.CartItem (cartItemUnitPrice)
import Servant (NoContent (NoContent))
import Polysemy (Members, Sem)
import Polysemy.Error (Error, throw)

getCartHandler :: Members '[CartRepository] r => Int -> Sem r (ApiResponse CartDTO)
getCartHandler userId = do
    cartItems <- getCartByUserId userId
    let total = realToFrac $ sum (map cartItemUnitPrice cartItems)
    pure (ApiResponse (toCartDTO userId total cartItems))

deleteCartHandler :: Members '[CartRepository] r => Int -> Sem r NoContent
deleteCartHandler userId = do
    deleteCartByUserId userId
    pure NoContent

addProductToCartHandler :: Members '[CartRepository, Error AppError] r => Int -> AddCartRequest -> Sem r (ApiResponse CartItemDTO)
addProductToCartHandler userId request = do
    maybeCartItem <- addProductToCart userId (addCartProductId request)
    case maybeCartItem of
        Just cartItem -> pure (ApiResponse (toDTO cartItem))
        Nothing -> throw (ProductNotFound (addCartProductId request))

deleteCartItemHandler :: Members '[CartRepository, Error AppError] r => Int -> Int -> Sem r NoContent
deleteCartItemHandler userId cartItemId = do
    deleted <- deleteCartItemById userId cartItemId
    if deleted
        then pure NoContent
        else throw (CartItemNotFound userId cartItemId)
