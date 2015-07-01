-----------------------------------------------------------------------------
-- |
-- Copyright   : (C) 2015 Dimitri Sabadie
-- License     : BSD3
--
-- Maintainer  : Dimitri Sabadie <dimitri.sabadie@gmail.com>
-- Stability   : experimental
-- Portability : portable
-----------------------------------------------------------------------------

module Data.Spline.Key (
    -- * Key type
    Key(..)
  , keyValue
    -- * interpolation
  , interpolateKeys
  , normalizeSampling
  ) where

import Linear

-- |A 'Key' is a point on the spline with extra information added. It can be,
-- for instance, left and right handles for a 'Bezier' curve, or whatever the
-- interpolation might need.
--
-- @Hold v@ is used to express no interpolation and holds its latest value until
-- the next key.
--
-- @Linear v@ represents a linear interpolation until the next key.
--
-- @Cosine v@ represents a cosine interpolation until the next key.
--
-- @CubicHermite v@ represents a cubic hermitian interpolation until the next
-- key.
--
-- @Bezier l v r@ represents a cubic Bezier interpolation, where 'l' refers
-- to the input – left – tangent of the key and 'r' is the
-- output – right – tangent of the key.
data Key a
  = Hold a
  | Linear a
  | Cosine a
  | CubicHermite a
  | Bezier a a a
    deriving (Eq,Show)

instance Functor Key where
  fmap f k = case k of
    Hold a         -> Hold (f a)
    Linear a       -> Linear (f a)
    Cosine a       -> Cosine (f a)
    CubicHermite a -> CubicHermite (f a)
    Bezier l a r   -> Bezier (f l) (f a) (f r)

-- |Extract the value out of a 'Key'.
keyValue :: Key a -> a
keyValue k = case k of
  Hold a         -> a
  Linear a       -> a
  Cosine a       -> a
  CubicHermite a -> a
  Bezier _ a _   -> a

-- |@interpolateKeys t start end@ interpolates between 'start' and 'end' using
-- 's' as a normalized sampling value.
--
-- Satisfies the following laws:
-- @
--   interpolateKeys 0 start _ = start
--   interpolateKeys 1 _ end   = end
-- @
interpolateKeys :: (Additive a,Floating s) => s -> Key (a s) -> Key (a s) -> a s
interpolateKeys s start end = case start of
    Hold k         -> k
    Linear k       -> lerp s b k
    Cosine k       -> lerp ((1 - cos (s * pi)) * 0.5) b k
    CubicHermite k -> lerp (s * s * (3 - 2 * s)) b k
    Bezier _ k0 r0   -> case end of
      Bezier l1 k1 _ -> interpolateBezier s k0 r0 l1 k1
      _              -> interpolateBezier s k0 r0 r0 b
  where
    b = keyValue end

-- @interpolateBezier s k0 r0 l1 k1@ performs a Bezier interpolation
-- between keys 'k0' and 'k1' using their respectives right and left tangents.
interpolateBezier :: (Additive a,Floating s)
                  => s
                  -> a s
                  -> a s
                  -> a s
                  -> a s
                  -> a s
interpolateBezier s k0 r0 l1 k1 = (u ^+^ v) ^* s
  where
    u = k0 ^+^ (r0 ^-^ k0) ^* s
    v = l1 ^+^ (k1 ^-^ l1) ^* s

-- |Normalize a sampling value by clamping and scaling it between two keys.
--
-- The following laws should be satisfied in order to get a coherent output:
--
-- @
--   sampler :: a s -> s
--
--   sampler (keyValue k1) <= s >= sampler (keyValue k0)
--   0 <= normalizeSampling sampler s k0 k1 <= 1
-- @
normalizeSampling :: (a s -> s) -> s -> Key (a s) -> Key (a s) -> s
normalizeSampling sampler s k0 k1 = (s - s0) / (s1 - s0)
  where
    s0 = sampler (keyValue k0)
    s1 = sampler (keyValue k1)
