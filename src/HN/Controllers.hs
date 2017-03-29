{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

module HN.Controllers where

import           HN.Monads
import           HN.Model.Items
import           HN.Types
import           HN.Data
import           HN.View.Home as V

import qualified Data.Text as T
import           Snap.App
import           Snap.App.Cache
import           Snap.App.RSS

import qualified Data.Map.Strict as M

-- | Grouped display.
grouped :: Controller Config PState ()
grouped = do
  embeddable <- getStringMaybe "embeddable"
  sources <-    getStringMaybe "sources"
  let ss = selected_sources <$> sources
  viewCached (Grouped (isJust embeddable) ss) $ do
    groups <- forM (maybe [minBound .. maxBound] id ss) $ \source -> do
      items <- model $ getItemsBySource source 10
      return (source,items)
    now <- io getZonedTime
    return $ case embeddable of
               Nothing -> V.grouped now groups
               Just{} -> V.groupedContent now groups

available_sources :: M.Map String Source
available_sources = M.fromList $ Prelude.map (\s -> (show s, s)) [ minBound .. maxBound ]

-- | input is a parameter string like "HaskellCafe/Libraries/Reddit"
selected_sources [] = []
selected_sources s = 
  let (pre, post) = span (/= ' ') s
  in  (maybeToList $ M.lookup pre available_sources) 
      ++ if Prelude.null post then [] else selected_sources $ drop 1 post
  

-- | Mixed display.
mixed :: Controller Config PState ()
mixed = do
  embeddable <- getStringMaybe "embeddable"
  sources <-    getStringMaybe "sources"
  let ss = selected_sources <$> sources
  viewCached (Mixed (isJust embeddable) ss) $ do
    items <- model $ getItemsBySources ss 100
    now <- io getZonedTime
    return $ case embeddable of
                Nothing -> V.mixed now items
                Just{} -> V.mixedContent now items

-- | Output an RSS feed.
feed :: Controller Config PState ()
feed = do
  items <- model $ getItems 30
  outputRSS "Haskell News"
            "http://haskellnews.org/"
            (map (\DItem{..} -> (zonedTimeToUTC iAdded
                                ,"[" <> T.pack (show iSource) <> "] " <> iTitle
                                ,""
                                ,T.pack $ show iLink))
                 items)

-- | Output items after some number in a page fragment.
after :: Controller Config PState ()
after = do
  n <- getInteger "epoch" 0
  when (n /= 0) $ do
    items <- model $ getItemsAfter (fromIntegral n) 100
    unless (null items) $ do
      now <- io getZonedTime
      output $ V.mixedRows now items
