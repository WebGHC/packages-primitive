{-# LANGUAGE MagicHash, UnboxedTuples, TypeFamilies #-}

-- |
-- Module      : Control.Monad.Primitive
-- Copyright   : (c) Roman Leshchinskiy 2009
-- License     : BSD-style
--
-- Maintainer  : Roman Leshchinskiy <rl@cse.unsw.edu.au>
-- Portability : non-portable
-- 
-- Primitive state-transformer monads
--

module Control.Monad.Primitive (
  PrimMonad(..), RealWorld, primitive_,
  primToPrim, primToIO, primToST,
  unsafePrimToPrim, unsafePrimToIO, unsafePrimToST,
  unsafeInlinePrim, unsafeInlineIO, unsafeInlineST,
  touch
) where

import GHC.Prim   ( State#, RealWorld, touch# )
import GHC.Base   ( unsafeCoerce#, realWorld# )
import GHC.IOBase ( IO(..) )
import GHC.ST     ( ST(..) )

-- | Class of primitive state-transformer monads
class Monad m => PrimMonad m where
  -- | State token type
  type PrimState m

  -- | Execute a primitive operation
  primitive :: (State# (PrimState m) -> (# State# (PrimState m), a #)) -> m a


  -- | Expose the internal structure of the monad
  internal :: m a -> State# (PrimState m) -> (# State# (PrimState m), a #)

-- | Execute a primitive operation with no result
primitive_ :: PrimMonad m
              => (State# (PrimState m) -> State# (PrimState m)) -> m ()
{-# INLINE primitive_ #-}
primitive_ f = primitive (\s# -> (# f s#, () #))

instance PrimMonad IO where
  type PrimState IO = RealWorld
  primitive = IO
  internal (IO p) = p

instance PrimMonad (ST s) where
  type PrimState (ST s) = s
  primitive = ST
  internal (ST p) = p

-- | Convert a 'PrimMonad' to another monad with the same state token.
primToPrim :: (PrimMonad m1, PrimMonad m2, PrimState m1 ~ PrimState m2)
        => m1 a -> m2 a
primToPrim m = primitive (internal m)

-- | Convert a 'PrimMonad' with a 'RealWorld' state token to 'IO'
primToIO :: (PrimMonad m, PrimState m ~ RealWorld) => m a -> IO a
primToIO = primToPrim

-- | Convert a 'PrimMonad' to 'ST'
primToST :: PrimMonad m => m a -> ST (PrimState m) a
primToST = primToPrim

-- | Convert a 'PrimMonad' to another monad with a possibly different state
-- token. This operation is highly unsafe!
unsafePrimToPrim :: (PrimMonad m1, PrimMonad m2) => m1 a -> m2 a
unsafePrimToPrim m = primitive (unsafeCoerce# (internal m))

-- | Convert any 'PrimMonad' to 'ST' with an arbitrary state token. This
-- operations is highly unsafe!
unsafePrimToST :: PrimMonad m => m a -> ST s a
unsafePrimToST = unsafePrimToPrim

-- | Convert any 'PrimMonad' to 'IO'. This operation is highly unsafe!
unsafePrimToIO :: PrimMonad m => m a -> IO a
unsafePrimToIO = unsafePrimToPrim

unsafeInlinePrim :: PrimMonad m => m a -> a
{-# INLINE unsafeInlinePrim #-}
unsafeInlinePrim m = unsafeInlineIO (unsafePrimToIO m)

unsafeInlineIO :: IO a -> a
{-# INLINE unsafeInlineIO #-}
unsafeInlineIO m = case internal m realWorld# of (# _, r #) -> r

unsafeInlineST :: ST s a -> a
{-# INLINE unsafeInlineST #-}
unsafeInlineST = unsafeInlinePrim

touch :: PrimMonad m => a -> m ()
touch x = unsafePrimToPrim
        $ (primitive (\s -> case touch# x s of { s' -> (# s', () #) }) :: IO ())

