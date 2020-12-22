{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE LambdaCase #-}

module AdventOfCode.Util
  ( Frequencies,
    frequencies,
    frequenciesInt,
    maybeParseByteString,
    commonElems,
    findFirstDup,
    hammingDistance,
    hammingSimilar,
    scan,
    count,
    snoc,
    wigglesum,
    fix',
    adjacencies,
    neighborsOf,
  )
where

import Control.Category ((>>>))
import Control.Comonad.Store (experiment)
import Control.Lens (holesOf)
import Control.Monad ((>=>))
import Data.ByteString (ByteString)
import Data.Function (fix)
import qualified Data.IntMap as IM
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Text.Trifecta (Parser, Result (..), parseByteString)

type Frequencies a = Map a Int

frequencies :: Ord a => [a] -> Frequencies a
frequencies = foldr go Map.empty
  where
    go k = Map.insertWith (+) k 1

frequenciesInt :: Foldable t => t Int -> IM.IntMap Int
frequenciesInt = foldr go IM.empty
  where
    go key = IM.insertWith (+) key 1

maybeParseByteString :: Parser a -> ByteString -> Maybe a
maybeParseByteString p = parseByteString p mempty >>> \case
  Failure _ -> Nothing
  Success res -> Just res

commonElems :: (Eq a) => [a] -> [a] -> Maybe [a]
commonElems (x : xs) (y : ys)
  | x == y = Just [x] <> recur
  | otherwise = recur
  where
    recur = commonElems xs ys
commonElems _ _ = Nothing

hammingDistance :: Eq a => [a] -> [a] -> Maybe Integer
hammingDistance (x : xs) (y : ys)
  | x /= y = (+ 1) <$> recur
  | otherwise = recur
  where
    recur = hammingDistance xs ys
hammingDistance [] [] = Just 0
hammingDistance _ _ = Nothing

hammingSimilar :: Eq a => Integer -> [a] -> [a] -> Bool
hammingSimilar n xs = maybe False (<= n) . hammingDistance xs

findFirstDup :: Ord a => [a] -> Maybe a
findFirstDup = go Set.empty
  where
    go _ [] = Nothing
    go seen (x : xs)
      | x `Set.member` seen = Just x
      | otherwise = go (Set.insert x seen) xs

scan :: Monoid m => [m] -> [m]
scan = scanl mappend mempty

count :: (a -> Bool) -> [a] -> Int
count p = length . filter p

snoc :: [a] -> a -> [a]
snoc xs x = xs ++ [x]

-- http://r6.ca/blog/20121209T182914Z.html
-- https://jaspervdj.be/posts/2012-10-17-wiggling-sums.html
wigglesum :: Traversable t => (a -> [a]) -> t a -> [t a]
wigglesum wiggle = holesOf traverse >=> experiment wiggle

fix' :: Eq a => (a -> a) -> a -> a
fix' f = fix (\g !x -> let fx = f x in if fx == x then x else g fx)

adjacencies :: (Applicative f, Num a, Eq (f a), Traversable f) => [f a]
adjacencies = filter (/= pure 0) $ sequenceA (pure [-1, 0, 1])

neighborsOf :: (Applicative f, Num a, Num (f a), Ord (f a), Traversable f) => f a -> Set (f a)
neighborsOf = Set.fromList . flip map adjacencies . (+)
