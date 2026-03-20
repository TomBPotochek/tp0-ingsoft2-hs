{-# LANGUAGE OverloadedStrings #-}

module E2E.Support
    ( mkEnv
    , addProductToCartClient
    , deleteCartItemClient
    , getCartClient
    , retryClient
    , createProductClient
    , deleteProductByIdClient
    , getProductByIdClient
    , listProductsClient
    , updateProductByIdClient
    ) where

import System.Environment (lookupEnv)
import Control.Concurrent (threadDelay)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Servant (NoContent)
import Servant.Client (BaseUrl (BaseUrl), ClientEnv, ClientM, Scheme (Http), mkClientEnv, runClientM)
import Servant.Client.Generic (AsClientT, genericClient)

import API.DTO.Cart (AddCartRequest, CartDTO, CartItemDTO)
import API.DTO.Product (CreateProductRequest, ProductDTO, UpdateProductRequest)
import API.Routes (ApiRoutes (..), CartByUserRoutes (..), ProductRoutes (..))

createProductClient :: CreateProductRequest -> ClientM ProductDTO
getProductByIdClient :: Int -> ClientM ProductDTO
listProductsClient :: ClientM [ProductDTO]
updateProductByIdClient :: Int -> UpdateProductRequest -> ClientM ProductDTO
deleteProductByIdClient :: Int -> ClientM NoContent
createProductClient = createProductRoute (productsRoutes apiClient)
getProductByIdClient = getProductByIdRoute (productsRoutes apiClient)
listProductsClient = listProductsRoute (productsRoutes apiClient)
updateProductByIdClient = updateProductByIdRoute (productsRoutes apiClient)
deleteProductByIdClient = deleteProductByIdRoute (productsRoutes apiClient)

addProductToCartClient :: Int -> AddCartRequest -> ClientM CartItemDTO
deleteCartItemClient :: Int -> Int -> ClientM NoContent
getCartClient :: Int -> ClientM CartDTO
getCartClient userId = getCartRoute (cartRoutes apiClient userId)
addProductToCartClient userId request = addProductToCartRoute (cartRoutes apiClient userId) request
deleteCartItemClient userId cartItemId = deleteCartItemRoute (cartRoutes apiClient userId) cartItemId

apiClient :: ApiRoutes (AsClientT ClientM)
apiClient = genericClient

mkEnv :: IO ClientEnv
mkEnv = do
    manager <- newManager defaultManagerSettings
    host <- maybe "app-e2e" (\value -> value) <$> lookupEnv "E2E_HOST"
    port <- maybe 1234 read <$> lookupEnv "E2E_PORT"
    pure (mkClientEnv manager (BaseUrl Http host port ""))

retryClient :: Int -> ClientEnv -> ClientM a -> IO (Either String a)
retryClient retries env action = go retries
  where
    go attemptsLeft = do
        result <- runClientM action env
        case result of
            Right value -> pure (Right value)
            Left err
                | attemptsLeft <= 1 -> pure (Left (show err))
                | otherwise -> do
                    threadDelay 500_000
                    go (attemptsLeft - 1)