{-# LANGUAGE OverloadedStrings #-}

-- | Split some text into links and text.

module Text.Links
 (explodeLinks)
  where

import           Data.Monoid
import           Data.Text (Text)
import qualified Data.Text as T
import           Network.URI

explodeLinks :: Text -> [Either URI Text]
explodeLinks = consume where
  consume t =
    if T.null t
       then []
       else case T.breakOn prefix t of
              (_,"") -> [Right t]
              (before,after) ->
                case T.span allowed after of
                  (murl,rest) -> case parseURI (T.unpack murl) of
                    Nothing -> let leading = before <> prefix
                               in case consume (T.drop 4 after) of
                                    (Right x:xs) -> Right (leading <> x) : xs
                                    xs -> Right leading : xs
                    Just uri -> (if T.null before then id else (Right before :))
                                (Left uri : explodeLinks rest)
  prefix = "http"
  -- Because it's not normal, and it's annoying.
  allowed '(' = False
  allowed ')' = False
  allowed c = isAllowedInURI c
