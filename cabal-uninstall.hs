module Main where


import System.Environment (getArgs)
import System.Process (system, runInteractiveCommand)
import System.Exit (ExitCode(..))
import System.IO (hGetContents, hFlush, stdout)
import System.Directory (doesDirectoryExist, removeDirectoryRecursive)
import System.FilePath (takeDirectory, dropTrailingPathSeparator)


main :: IO ()
main = do
  input <- getArgs
  case input of
       package:args -> do
         let useForce = parseForceArg args
         res <- directoryOfPackage package
         case (res, useForce) of
              (Left err        , _         ) -> putStr err
              (_               , Nothing   ) -> putStrLn usageInfo
              (Right packageDir, Just force) -> do
                exitcode <- unregisterPackage package force
                case exitcode of
                     ExitFailure _ -> return ()
                     ExitSuccess -> do
                       b <- doesDirectoryExist packageDir
                       if b then removePackageDirectory packageDir
                            else putStrLn "package directory already deleted"
       _ -> putStrLn usageInfo

usageInfo :: String
usageInfo =
  "usage: cabal-uninstall <package-name> [--force]\n\
  \use sudo if the package is installed globally"

internalErrorInfo :: String
internalErrorInfo =
  "internal error: please contact Jan Christiansen (christiansen@monoid-it.de)"

parseForceArg :: [String] -> Maybe Bool
parseForceArg []          = Just False
parseForceArg ["--force"] = Just True
parseForceArg _           = Nothing

directoryOfPackage :: String -> IO (Either String FilePath)
directoryOfPackage package = do
  let command = "ghc-pkg field " ++ package ++ " library-dirs"
  (_, hout, herr, _) <- runInteractiveCommand command
  result <- hGetContents hout
  case result of
       [] -> hGetContents herr >>= return . Left
       _  -> return (packageDir (words result))
 where
  packageDir ["library-dirs:", libDir] =
    Right (takeDirectory (dropTrailingPathSeparator libDir))
  packageDir _ = Left internalErrorInfo

removePackageDirectory :: FilePath -> IO ()
removePackageDirectory packageDir = do
  putStr ("delete library directory " ++ packageDir ++ "? (yes/no)")
  hFlush stdout
  choice <- getLine
  case choice of
       "yes" -> removeDirectoryRecursive packageDir
       _     -> return ()

unregisterPackage :: String -> Bool -> IO ExitCode
unregisterPackage package force = do
  putStrLn "unregistering package"
  system ("ghc-pkg unregister " ++ useForce force ++ package)
 where
  useForce True  = "--force "
  useForce False = ""