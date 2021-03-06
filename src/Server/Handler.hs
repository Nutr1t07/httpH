{-# LANGUAGE OverloadedStrings #-}
module Server.Handler where

import           Codec.Compression.GZip (compress)
import           Control.ExceptT        (ExceptT, except)
import           Data.ByteString        (ByteString)
import qualified Data.ByteString        as BS
import qualified Data.ByteString.Lazy   as BL
import Server.Type
    ( Error(..),
      HeaderName(..),
      Header(..),
      Response(..) )
import           Utils.Misc             (parseGMTTime)

-- A initial response should have these headers included: Date, Content-Type
getHeaderHandler :: Header -> Response -> ExceptT Error IO Response

getHeaderHandler (Header IfModifiedSince date) resp = do
  let guard x = case  parseGMTTime x of
                 Just y -> return y
                 _      -> except (Error 500 "Incorrect date format")

  lastModLit <- case (lookupHeader LastModified $ resp_headers resp) of              
                  Just x -> return x
                  _      -> except (Error 500 "LastModified not found in Response")

  resp_date <- guard lastModLit
  req_date <- guard date

  if req_date < resp_date
    then return resp
    else except (Error 304 "")

-- enable gzip compression as default
getHeaderHandler (Header AcceptEncoding encoding) resp =
  if BS.null $ snd $ BS.breakSubstring "gzip" encoding
    then return  resp
    else do
      let retBody = BL.toStrict $ compress (BL.fromStrict $ resp_body resp)
      let headers = Header ContentEncoding "gzip" : (resp_headers resp)
      return resp { resp_body= retBody, resp_headers = headers}

getHeaderHandler _ resp = return resp


lookupHeader :: HeaderName -> [Header] -> Maybe ByteString
lookupHeader _ [] = Nothing
lookupHeader hdrName ((Header name val):hdrs) = if name == hdrName
  then Just val
  else lookupHeader hdrName hdrs