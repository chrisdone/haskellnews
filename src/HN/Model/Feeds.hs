-- | Download and import feeds from various sources.

module HN.Model.Feeds where

import HN.Data
import HN.Model.Source
import HN.Model
import HN.Monads
import HN.Types

import Control.Applicative
import Network.Curl
import Network.URI
import Snap.App
import System.Locale
import Text.Feed.Import
import Text.Feed.Query
import Text.Feed.Types

-- | Get /r/haskell.
importRedditHaskell :: Model c s (Either String ())
importRedditHaskell = do
  result <- io $ getReddit "haskell"
  case result of
    Left e -> return (Left e)
    Right items -> do
      forM_ items $ \item ->
        exec ["INSERT INTO item"
             ,"(source,published,title,description,link)"
             ,"VALUES"
             ,"(?,?,?,?,?)"]
             (sourceId HaskellReddit
             ,niPublished item
             ,niTitle item
             ,niDescription item
             ,show (niLink item))
      return (Right ())

-- | Get Reddit feed.
getReddit :: String -> IO (Either String [NewItem])
getReddit subreddit = do
  result <- downloadFeed ("http://www.reddit.com/r/" ++ subreddit ++ "/.rss")
  case result of
    Left e -> return (Left e)
    Right e -> return (mapM makeItem (feedItems e))

-- | Make an item from a feed item.
makeItem :: Item -> Either String NewItem
makeItem item =
  NewItem <$> extract "item" (getItemTitle item)
          <*> extract "publish date" (getItemPublishDate item >>= parseRFC822)
          <*> extract "description" (getItemDescription item)
          <*> extract "link" (getItemLink item >>= parseURI)

  where extract label = maybe (Left ("unable to extract " ++ label)) Right

-- | Download and parse a feed.
downloadFeed :: String -> IO (Either String Feed)
downloadFeed uri = do
  result <- downloadString uri
  case result of
    Left e -> return (Left (show e))
    Right str -> case parseFeedString str of
      Nothing -> return (Left ("Unable to parse feed from: " ++ uri))
      Just feed -> return (Right feed)

-- | Download a string from a URI.
downloadString :: String -> IO (Either (CurlCode,String) String)
downloadString uri = do
  withCurlDo $ do
    (code,resp) <- curlGetString_ uri []
    case code of
      CurlOK -> return (Right resp)
      _ -> return (Left (code,resp))

-- | Parse an RFC 822 timestamp.
parseRFC822 :: String -> Maybe ZonedTime
parseRFC822 = parseTime defaultTimeLocale rfc822DateFormat