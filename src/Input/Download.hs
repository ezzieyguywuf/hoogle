{-# LANGUAGE TupleSections #-}

module Input.Download(downloadInput) where

import System.FilePath
import Control.Monad.Extra
import System.Directory
import Data.Conduit.Binary (sinkFile)
import qualified Network.HTTP.Conduit as C
import Network.Connection
import qualified Data.Conduit as C
import General.Util
import General.Timing
import Control.Monad.Trans.Resource
import Control.Exception.Extra


-- | Download all the input files to input/
downloadInput :: Timing -> Bool -> Maybe Bool -> FilePath -> String -> URL -> IO FilePath
downloadInput timing insecure download dir name url = do
    let file = dir </> "input-" ++ name
    exists <- doesFileExist file
    when (not exists && download == Just False) $
        errorIO $ "File is not already downloaded and --download=no given, downloading " ++ url ++ " to " ++ file
    when (not exists || download == Just True) $
        timed timing ("Downloading " ++ url) $ do
            downloadFile insecure (file <.> "part") url
            renameFile (file <.> "part") file
    pure file

downloadFile :: Bool -> FilePath -> String -> IO ()
downloadFile insecure file url = do
    let request = C.parseRequest_ url
    manager <- C.newManager $ C.mkManagerSettings (TLSSettingsSimple insecure False False) Nothing
    runResourceT $ do
        response <- C.http request manager
        C.runConduit $ C.responseBody response C..| sinkFile file
