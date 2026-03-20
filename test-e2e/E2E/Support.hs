{-# LANGUAGE OverloadedStrings #-}

module E2E.Support
    ( mkEnv
    , addProductToCartClient
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
import Servant ((:<|>) (..))
import Servant.Client (BaseUrl (BaseUrl), ClientEnv, ClientM, Scheme (Http), client, mkClientEnv, runClientM)

import API.DTO.Cart (AddCartRequest, CartItemDTO)
import API.DTO.Product (CreateProductRequest, ProductDTO, UpdateProductRequest)
import API.Routes (cartApi, productApi)

-- productClients :: (CreateProductRequest -> ClientM ProductDTO) :<|> ClientM [ProductDTO]
-- productClients = client productApi

createProductClient :: CreateProductRequest -> ClientM ProductDTO
getProductByIdClient :: Int -> ClientM ProductDTO
listProductsClient :: ClientM [ProductDTO]
updateProductByIdClient :: Int -> UpdateProductRequest -> ClientM ProductDTO
deleteProductByIdClient :: Int -> ClientM NoContent
createProductClient :<|> (listProductsClient :<|> (getProductByIdClient :<|> (updateProductByIdClient :<|> deleteProductByIdClient))) = client productApi

addProductToCartClient :: Int -> AddCartRequest -> ClientM CartItemDTO
addProductToCartClient = client cartApi

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