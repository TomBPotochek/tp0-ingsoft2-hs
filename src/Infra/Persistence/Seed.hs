module Infra.Persistence.Seed
    ( seedDb
    ) where

import Data.Time (getCurrentTime, UTCTime)
import Database.Persist.Sql (ConnectionPool, insertMany_, runSqlPool)
import Infra.Persistence.Models (ProductEntity (..))

seedDb :: ConnectionPool -> IO ()
seedDb pool = do
    now <- getCurrentTime
    runSqlPool (insertMany_ (seedProducts now)) pool

seedProducts :: UTCTime -> [ProductEntity]
seedProducts now =
    [ ProductEntity 1 "Mechanical Keyboard" "75% layout, tactile switches" 129.99 now now
    , ProductEntity 1 "Wireless Mouse"       "Ergonomic, 3000 DPI"         49.99  now now
    , ProductEntity 2 "USB-C Hub"            "7-in-1 multiport adapter"    35.00  now now
    ]