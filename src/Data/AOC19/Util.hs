module Data.AOC19.Util where

import Control.Monad.IO.Class (liftIO)
import Paths_aoc (getDataFileName)
import Text.Trifecta (Parser, Result (..), parseFromFileEx)

parseInput :: Parser a -> FilePath -> IO a
parseInput parser fname =
  do
    fname' <- getDataFileName fname
    parsed <- liftIO $ parseFromFileEx parser fname'
    case parsed of
      Success result -> pure result
      Failure reason -> error (show reason)
