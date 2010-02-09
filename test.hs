{-# LANGUAGE NoImplicitPrelude, UnicodeSyntax #-}

module Main where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

-- from base
import Control.Applicative ( (<$>) )
import Control.Concurrent  ( forkIO, threadDelay )
import Control.Exception   ( catch, throwTo, ErrorCall(..) )
import Control.Monad       ( (>>=), (>>), return, fail
                           , mapM_, replicateM, replicateM_
                           )
import Data.Bool           ( Bool )
import Data.Function       ( ($) )
import Data.Int            ( Int )
import Data.Maybe          ( isJust )
import Prelude             ( fromInteger )
import System.IO           ( IO )
import System.Timeout      ( timeout )

-- from base-unicode-symbols
import Data.Function.Unicode ( (∘) )
import Prelude.Unicode       ( (⋅) )

-- from concurrent-extra
-- import qualified Control.Concurrent.Lock  as Lock
import           Control.Concurrent.Event ( Event )
import qualified Control.Concurrent.Event as Event

-- from test-framework
import Test.Framework  ( Test, defaultMain, testGroup )

-- from test-framework-hunit
import Test.Framework.Providers.HUnit ( testCase )

-- from HUnit
import Test.HUnit hiding ( Test )


-------------------------------------------------------------------------------
-- Tests
-------------------------------------------------------------------------------

main ∷ IO ()
main = defaultMain tests

tests ∷ [Test]
tests = [ testGroup "Events"
          [ testCase "set wait a"    ∘ assert $ test_event_1 1 1
          , testCase "set wait b"    ∘ assert $ test_event_1 5 1
          , testCase "set wait c"    ∘ assert $ test_event_1 1 5
          , testCase "set wait d"    ∘ assert $ test_event_1 5 5
          , testCase "conc set wait" ∘ assert $ test_event_2
          , testCase "multi wake"    ∘ assert $ test_event_3 10
          , testCase "exception"     ∘ assert $ test_event_4
          , testCase "wait timeout"  ∘ assert $ test_event_5
          ]
        ]

-- Set an event 's' times then wait for it 'w' times. This should
-- terminate within a few moments.
test_event_1 ∷ Int → Int → IO Bool
test_event_1 s w = within (10 ⋅ a_moment) $ do
                     e ← Event.new
                     replicateM_ s $ Event.set  e
                     replicateM_ w $ Event.wait e

test_event_2 ∷ IO Bool
test_event_2 = within (10 ⋅ a_moment) $ do
                 e1 ← Event.new
                 e2 ← Event.new
                 _ ← forkIO $ helper e1 e2
                 wait_a_moment
                 Event.set  e1
                 Event.wait e2
  where
    helper e1 e2 = do
      Event.wait e1
      Event.set  e2

-- Waking multiple threads with a single Event.
test_event_3 ∷ Int → IO Bool
test_event_3 n = within (10 ⋅ a_moment) $ do
                   e1 ← Event.new
                   es ← replicateM n $ spawnHelper e1
                   wait_a_moment
                   Event.set e1
                   mapM_ Event.wait es
  where
    spawnHelper ∷ Event → IO Event
    spawnHelper e1 = do
      e2 ← Event.new
      _ ← forkIO $ helper e1 e2
      return e2

    helper e1 e2 = do
      Event.wait e1
      Event.set  e2

-- Exception handling while waiting for an Event.
test_event_4 ∷ IO Bool
test_event_4 = within (10 ⋅ a_moment) $ do
                 e1 ← Event.new
                 e2 ← Event.new
                 helperId ← forkIO (helper e1 e2)
                 wait_a_moment
                 throwTo helperId $ ErrorCall "Boo!"
                 Event.wait e2
  where
    helper e1 e2 = do
      let onErr ∷ ErrorCall → IO ()
          onErr _ = Event.set e2
      catch (Event.wait e1) onErr

test_event_5 ∷ IO Bool
test_event_5 = within (10 ⋅ a_moment) $ do
                 e ← Event.new
                 Event.waitTimeout e a_moment

-------------------------------------------------------------------------------
-- Misc
-------------------------------------------------------------------------------

-- Exactly 1 moment. Currently equal to 0.005 seconds.
a_moment ∷ Int
a_moment = 5000

wait_a_moment ∷ IO ()
wait_a_moment = threadDelay a_moment

-- True if the action 'a' evaluates within 't' μs.
within ∷ Int → IO α → IO Bool
within t a = isJust <$> timeout t a
