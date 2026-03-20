module Infra.Persistence.Seed
    ( seedDb
    ) where

import Data.Time (getCurrentTime, UTCTime)
import Database.Persist.Sql (ConnectionPool, count, insertMany, insertMany_, runSqlPool)
import Database.Persist (Filter)
import Infra.Persistence.Models (ProductEntity (..), CartItemEntity (..), ProductEntityId)

seedDb :: ConnectionPool -> IO ()
seedDb pool = do
    now <- getCurrentTime
    -- Only seed if products table is empty
    productCount <- runSqlPool (count ([] :: [Filter ProductEntity])) pool
    if productCount == 0
      then do
        -- Insert products and capture their IDs
        productIds <- runSqlPool (insertMany (seedProducts now)) pool
        -- Insert carts using actual product IDs
        runSqlPool (insertMany_ (seedCartItems now productIds)) pool
      else
        pure ()  -- Data already exists, skip seeding

seedProducts :: UTCTime -> [ProductEntity]
seedProducts now =
    [ ProductEntity 1 "Mechanical Keyboard" "75% layout, tactile switches" 129.99 now now
    , ProductEntity 1 "Wireless Mouse"       "Ergonomic, 3000 DPI"         49.99  now now
    , ProductEntity 2 "USB-C Hub"            "7-in-1 multiport adapter"    35.00  now now
    , ProductEntity 2 "4K Monitor"           "27\" IPS panel, 144Hz"        299.99 now now
    , ProductEntity 3 "Mechanical Keycaps"  "Cherry profile, PBT material" 89.99  now now
    , ProductEntity 3 "Mouse Pad"            "Large desk mat, cloth surface" 24.99 now now
    ]

seedCartItems :: UTCTime -> [ProductEntityId] -> [CartItemEntity]
seedCartItems now productIds =
    case productIds of
      [kbId, mouseId, hubId, monitorId, capsId, _padId] ->
        [ -- User 1 has keyboard and mouse in cart
          CartItemEntity 1 kbId "Mechanical Keyboard" 129.99 now
        , CartItemEntity 1 mouseId "Wireless Mouse" 49.99 now
        -- User 2 has monitor and hub in cart
        , CartItemEntity 2 monitorId "4K Monitor" 299.99 now
        , CartItemEntity 2 hubId "USB-C Hub" 35.00 now
        , CartItemEntity 2 mouseId "Wireless Mouse" 49.99 now
        -- User 3 has keycaps in cart
        , CartItemEntity 3 capsId "Mechanical Keycaps" 89.99 now
        ]
      _ -> []  -- Safety fallback if product count doesn't match