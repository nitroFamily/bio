{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}

module Bimo.Model where

import Data.Yaml
import qualified Data.ByteString as B
import Control.Monad
import Control.Monad.Reader
import Control.Monad.Logger
import Control.Monad.Catch
import Control.Monad.IO.Class
import Path
import Path.IO
import System.FilePath (dropTrailingPathSeparator)

import Bimo.Types.Env
import Bimo.Types.Config.Model

import Bimo.Config
import Bimo.Path

readModelConfig :: (MonadIO m, MonadThrow m)
                => Path Abs File
                -> m Model
readModelConfig p = do
    unlessFileExists p $ throwM $ NotFoundModelConfig p
    readYamlConfig p

createEmptyModel :: (MonadIO m, MonadThrow m, MonadReader Env m)
                 => Maybe String
                 -> Maybe String
                 -> Path Abs Dir
                 -> m ()
createEmptyModel cat lang modelDir = do
    Env{..} <- ask
    createDir modelDir
    createDir $ modelDir </> modelSrc
    createDir $ modelDir </> modelExec
    let name = dropTrailingPathSeparator $ toFilePath modelDir
        conf = emptyModelConfig name cat lang
    liftIO $ B.writeFile (toFilePath $ modelDir </> modelConfig) conf

copyModel :: (MonadIO m, MonadThrow m, MonadCatch m, MonadReader Env m)
          => Path Abs Dir
          -> Path Abs Dir
          -> m ()
copyModel src dst = do
    ensureDir dst
    copyDirRecur src dst

getModelLibPath :: (MonadIO m, MonadThrow m, MonadReader Env m)
             => Path Abs Dir
             -> m (String, Path Abs Dir)
getModelLibPath pathToModelDir = do
    mConf     <- asks modelConfig
    mDir      <- asks modelsDir
    execDir   <- asks modelExec
    Model{..} <- readModelConfig $ pathToModelDir </> mConf
    exec      <- parseRelFile modelName
    name      <- parseRelDir modelName
    cat       <- parseRelDir category

    let execFile = pathToModelDir </> execDir </> exec
        dstDir   = mDir </> cat </> name

    whenDirExists dstDir $ throwM $ ModelAlreadyExists dstDir
    unlessFileExists execFile $ throwM $ NotFoundModelExec execFile

    return (category, dstDir)

data ModelException
    = NotFoundModelConfig !(Path Abs File)
    | NotFoundModelExec !(Path Abs File)
    | ModelAlreadyExists !(Path Abs Dir)

instance Exception ModelException

instance Show ModelException where
    show (NotFoundModelConfig path) =
        "Not found model config: " ++ show path
    show (NotFoundModelExec path) =
        "Not found model exec: " ++ show path ++ " " ++ "Build model before add"
    show (ModelAlreadyExists path) =
        "Model with this name already exists in category: " ++ show path
