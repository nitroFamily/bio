{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards  #-}

-- | Create new project

module Bimo.New
    ( NewOpts (..)
    , new)
    where

import Control.Monad.Reader
import Control.Monad.Logger
import Control.Monad.Catch
import Control.Monad.IO.Class
import Path
import Path.IO
import System.FilePath (dropTrailingPathSeparator)
import qualified Data.ByteString as B

import Bimo.Types.Env
import Bimo.Types.Config.Project
import Bimo.Types.Config.Model

data NewOpts
    = NewProject  { projectName  :: String , srtTemplateName :: Maybe String }
    | NewModel    { modelName    :: String }
    | NewTemplate { templateName :: String }
    deriving Show

new :: (MonadIO m, MonadThrow m, MonadLogger m, MonadReader Env m)
    => NewOpts
    -> m ()
new NewProject{..} = do
  dir <- parseRelDir projectName
  checkExists dir createEmptyProject
new NewModel{..} = do
  dir <- parseRelDir modelName
  checkExists dir createEmptyModel
new NewTemplate{..} =
    liftIO $ print templateName

checkExists :: (MonadIO m, MonadThrow m, MonadLogger m, MonadReader Env m)
            => Path Rel Dir
            -> (Path Rel Dir -> m ())
            -> m ()
checkExists dir action = do
  exists <- doesDirExist dir
  if exists
     then throwM . AlreadyExists $ toFilePath dir
     else action dir

createEmptyProject :: (MonadIO m, MonadThrow m, MonadLogger m, MonadReader Env m)
                   => Path Rel Dir
                   -> m ()
createEmptyProject dir = do
  Env{..} <- ask
  createDir dir
  createDir $ dir </> projectModelsDir
  liftIO $ B.writeFile (toFilePath $ dir </> projectConfig) emptyProjectConfig

createEmptyModel :: (MonadIO m, MonadThrow m, MonadLogger m, MonadReader Env m)
                 => Path Rel Dir
                 -> m ()
createEmptyModel model = do
  Env{..} <- ask
  createDir model
  createDir $ model </> modelSrc
  createDir $ model </> modelExec
  let conf = emptyModelConfig $ dropTrailingPathSeparator $ toFilePath model
  liftIO $ B.writeFile (toFilePath $ model </> modelConfig) conf


data NewException
    = AlreadyExists !String
    deriving (Show)

instance Exception NewException


