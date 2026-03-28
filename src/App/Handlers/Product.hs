module App.Handlers.Product
    ( createProductHandler
    , deleteProductByIdHandler
    , getProductByIdHandler
    , listProductsHandler
    , updateProductByIdHandler
    ) where

import API.DTO.Product (CreateProductRequest (..), ProductDTO, UpdateProductRequest (..), toDTO, toNewProduct, toProductUpdate)
import API.DTO.Support (ApiResponse (..))
import App.Error (AppError (..))
import App.Effects.ProductRepository (ProductRepository, createProduct, deleteProductById, getProductById, listProducts, updateProductById)
import Data.Char (isSpace)
import Polysemy (Member, Members, Sem)
import Polysemy.Error (Error, throw)

createProductHandler :: Members '[ProductRepository, Error AppError] r => CreateProductRequest -> Sem r (ApiResponse ProductDTO)
createProductHandler req = do
    validateCreateProductRequest req
    ApiResponse . toDTO <$> createProduct (toNewProduct req)

listProductsHandler :: Member ProductRepository r => Sem r (ApiResponse [ProductDTO])
listProductsHandler = ApiResponse . map toDTO <$> listProducts

getProductByIdHandler :: Members '[ProductRepository, Error AppError] r => Int -> Sem r (ApiResponse ProductDTO)
getProductByIdHandler productId = do
    maybeProduct <- getProductById productId
    case maybeProduct of
        Just foundProduct -> pure (ApiResponse (toDTO foundProduct))
        Nothing -> throw (ProductNotFound productId)

updateProductByIdHandler :: Members '[ProductRepository, Error AppError] r => Int -> UpdateProductRequest -> Sem r (ApiResponse ProductDTO)
updateProductByIdHandler productId req = do
    validateUpdateProductRequest req
    maybeUpdated <- updateProductById productId (toProductUpdate req)
    case maybeUpdated of
        Just updatedProduct -> pure (ApiResponse (toDTO updatedProduct))
        Nothing -> throw (ProductNotFound productId)

deleteProductByIdHandler :: Members '[ProductRepository, Error AppError] r => Int -> Sem r ()
deleteProductByIdHandler productId = do
    deleted <- deleteProductById productId
    if deleted
        then pure ()
        else throw (ProductNotFound productId)

validateCreateProductRequest :: Member (Error AppError) r => CreateProductRequest -> Sem r ()
validateCreateProductRequest req
    | null (trim (createProductTitle req)) =
        throw (InvalidInput (Just "title") "title must not be blank")
    | createProductPrice req < 0.01 =
        throw (InvalidInput (Just "price") "price must be >= 0.01")
    | otherwise = pure ()

validateUpdateProductRequest :: Member (Error AppError) r => UpdateProductRequest -> Sem r ()
validateUpdateProductRequest req
    | null (trim (updateProductTitle req)) =
        throw (InvalidInput (Just "title") "title must not be blank")
    | updateProductPrice req < 0.01 =
        throw (InvalidInput (Just "price") "price must be >= 0.01")
    | otherwise = pure ()

trim :: String -> String
trim = f . f
  where
    f = reverse . dropWhile isSpace