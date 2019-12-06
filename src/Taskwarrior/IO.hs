-- | This modules contains IO actions to interact with the taskwarrior application.
-- The taskwarrior documentation very explicitly disallows accessing the files by itself.
-- So all functions here work via calling the `task` binary which needs to be in the PATH.
module Taskwarrior.IO
  ( getTasks
  , saveTasks
  , createTask
  )
where

import           Taskwarrior.Task               ( Task
                                                , makeTask
                                                )
import           Data.Text                      ( Text )
import qualified Data.Text                     as Text
import qualified Data.ByteString.Lazy          as LBS
import qualified Data.Aeson                    as Aeson
import           System.Process                 ( withCreateProcess
                                                , CreateProcess(..)
                                                , proc
                                                , StdStream(..)
                                                , waitForProcess
                                                )
import           System.IO                      ( hClose )
import           System.Exit                    ( ExitCode(..) )
import           Control.Monad                  ( when )
import           System.Random                  ( getStdRandom
                                                , random
                                                )
import           Data.Time                      ( getCurrentTime )

-- | Uses task export with a given filter like ["description:Milk", "+PENDING"].
getTasks :: [Text] -> IO [Task]
getTasks args =
  withCreateProcess
      ((proc "task" (fmap Text.unpack . (++ ["export"]) $ args))
        { std_out = CreatePipe
        }
      )
    $ \_ stdoutMay _ _ -> do
        stdout <- maybe
          (fail "Couldn‘t create stdout handle for `task export`")
          pure
          stdoutMay
        input <- LBS.hGetContents stdout
        either fail return . Aeson.eitherDecode $ input

-- | Uses task import to save the given tasks.
saveTasks :: [Task] -> IO ()
saveTasks tasks =
  withCreateProcess ((proc "task" ["import"]) { std_in = CreatePipe })
    $ \stdinMay _ _ process -> do
        stdin <- maybe (fail "Couldn‘t create stdin handle for `task import`")
                       pure
                       stdinMay
        LBS.hPut stdin . Aeson.encode $ tasks
        hClose stdin
        exitCode <- waitForProcess process
        when (exitCode /= ExitSuccess) $ fail . show $ exitCode

-- | This will create a Task. I runs in IO to create a UUID and get the currentTime. This will not save the Task to taskwarrior.
-- If you want to create a task, with certain fields and save it, you could do that like this:
-- @
--   newTask <- createTask "Buy Milk"
--   saveTasks [newTask { tags = ["groceries"] }]
-- @
createTask :: Text -> IO Task
createTask description = do
  uuid  <- getStdRandom random
  entry <- getCurrentTime
  pure $ makeTask uuid entry description
