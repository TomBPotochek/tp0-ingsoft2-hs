{-# LANGUAGE OverloadedStrings #-}

module E2E.Support
    ( mkEnv
    , retryClient
    , createProductClient
    , listProductsClient
    ) where

import System.Environment (lookupEnv)
import Control.Concurrent (threadDelay)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Servant ((:<|>) (..))
import Servant.Client (BaseUrl (BaseUrl), ClientEnv, ClientM, Scheme (Http), client, mkClientEnv, runClientM)

import API.DTO.Product (CreateProductRequest, ProductDTO)
import API.Routes (productApi)

-- productClients :: (CreateProductRequest -> ClientM ProductDTO) :<|> ClientM [ProductDTO]
-- productClients = client productApi

createProductClient :: CreateProductRequest -> ClientM ProductDTO
listProductsClient :: ClientM [ProductDTO]
createProductClient :<|> listProductsClient = client productApi

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