{-# LANGUAGE NoImplicitPrelude, UnicodeSyntax #-}

module Utils where

--------------------------------------------------------------------------------
-- Imports
--------------------------------------------------------------------------------

-- from base:
import Control.Concurrent.MVar ( MVar, takeMVar, putMVar )
import Control.Exception       ( SomeException(SomeException)
                               , blocked, block, unblock
                               , throwIO
                               )
import Control.Monad           ( Monad, return, (>>=), (>>), fail )
import Data.Bool               ( Bool(False, True), otherwise )
import Data.Function           ( ($) )
import Data.Functor            ( Functor, (<$) )
import Data.IORef              ( IORef, readIORef, writeIORef )
import Prelude                 ( ($!) )
import System.IO               ( IO )

-- from base-unicode-symbols:
import Data.Function.Unicode   ( (∘) )


--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------

-- | Strict function composition.
(∘!) ∷ (β → γ) → (α → β) → (α → γ)
f ∘! g = (f $!) ∘ g

void ∷ Functor f ⇒ f α → f ()
void = (() <$)

ifM ∷ Monad m ⇒ m Bool → m α → m α → m α
ifM c t e = c >>= \b → if b then t else e

anyM ∷ Monad m ⇒ (α → m Bool) → [α] → m Bool
anyM p = anyM_p
    where
      anyM_p []     = return False
      anyM_p (x:xs) = ifM (p x) (return True) (anyM_p xs)

throwInner ∷ SomeException → IO α
throwInner (SomeException e) = throwIO e

purelyModifyMVar ∷ MVar α → (α → α) → IO ()
purelyModifyMVar mv f = block $ takeMVar mv >>= putMVar mv ∘! f

modifyIORefM ∷ IORef α → (α → IO (α, β)) → IO β
modifyIORefM r f = do (y, z) ← readIORef r >>= f
                      writeIORef r y
                      return z

modifyIORefM_ ∷ IORef α → (α → IO α) → IO ()
modifyIORefM_ r f = readIORef r >>= f >>= writeIORef r

{-|
/Strictly/ delete the first element of the list which satisfies the predicate.

This function strictly constructs the list up until the point of the deleted element.
-}
deleteFirstWhich' ∷ (α → Bool) → [α] → [α]
deleteFirstWhich' p = deleteFirstWhich'_p
    where
      deleteFirstWhich'_p []      = []
      deleteFirstWhich'_p (x:xs)
                      | p x       = xs
                      | otherwise = (x:) $! deleteFirstWhich'_p xs

{-|
@blockedApply a f@ applies @f@ in a blocked state to @a@ which is executed in
the blocked state of the current thread.

Handy in case @f@ is a fork which needs to install an exception handler before
executing @a@.
-}
blockedApply :: IO α → (IO α → IO β) → IO β
blockedApply a f = ifM blocked
                       (f a)
                       (block $ f $ unblock a)


-- The End ---------------------------------------------------------------------
