module App.Handlers.Cart
    ( getCartHandler
    , addProductToCartHandler
    ) where

import API.DTO.Cart (AddCartRequest (..), CartDTO, CartItemDTO, toCartDTO, toDTO)
import App.Effects.CartRepository (CartRepository, addProductToCart, getCartByUserId)
import App.Error (AppError (ProductNotFound))
import Domain.CartItem (cartItemUnitPrice)
import Polysemy (Members, Sem)
import Polysemy.Error (Error, throw)

getCartHandler :: Members '[CartRepository] r => Int -> Sem r CartDTO
getCartHandler userId = do
    cartItems <- getCartByUserId userId
    let total = sum (map cartItemUnitPrice cartItems)
    pure (toCartDTO userId total cartItems)

addProductToCartHandler :: Members '[CartRepository, Error AppError] r => Int -> AddCartRequest -> Sem r CartItemDTO
addProductToCartHandler userId request = do
    maybeCartItem <- addProductToCart userId (addCartProductId request)
    case maybeCartItem of
        Just cartItem -> pure (toDTO cartItem)
        Nothing -> throw (ProductNotFound (addCartProductId request))
