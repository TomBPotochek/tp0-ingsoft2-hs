module App.Handlers.Cart
    ( addProductToCartHandler
    ) where

import API.DTO.Cart (AddCartRequest (..), CartItemDTO, toDTO)
import App.Effects.CartRepository (CartRepository, addProductToCart)
import App.Error (AppError (ProductNotFound))
import Polysemy (Members, Sem)
import Polysemy.Error (Error, throw)

addProductToCartHandler :: Members '[CartRepository, Error AppError] r => Int -> AddCartRequest -> Sem r CartItemDTO
addProductToCartHandler userId request = do
    maybeCartItem <- addProductToCart userId (addCartProductId request)
    case maybeCartItem of
        Just cartItem -> pure (toDTO cartItem)
        Nothing -> throw (ProductNotFound (addCartProductId request))
