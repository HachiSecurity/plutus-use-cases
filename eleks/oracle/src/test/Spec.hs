{-# LANGUAGE OverloadedStrings #-}
module Main(main) where

import qualified Spec.MutualBet
import qualified Spec.Oracle
import           Test.Tasty
import           Test.Tasty.Hedgehog       (HedgehogTestLimit (..))

import Data.Default
import Ledger.Index
import Plutus.Trace

-- With `||`:
-- ( Sum {getSum = 9539}
-- , ExBudget {exBudgetCPU = ExCPU 1124168956, exBudgetMemory = ExMemory 3152700}
-- )

-- With `if then else`:
-- ( Sum {getSum = 3531}
-- , ExBudget {exBudgetCPU = ExCPU 698345767, exBudgetMemory = ExMemory 2069978}
-- )
main :: IO ()
main = print =<< writeScriptsTo
        (ScriptsConfig "." (Scripts UnappliedValidators))
        "updateOracleTrace"
        Spec.Oracle.updateOracleTrace
        def

-- | Number of successful tests for each hedgehog property.
--   The default is 100 but we use a smaller number here in order to speed up
--   the test suite.
--
limit :: HedgehogTestLimit
limit = HedgehogTestLimit (Just 5)

tests :: TestTree
tests = localOption limit $ testGroup "use cases" [
    Spec.MutualBet.tests
    ,
    Spec.Oracle.tests
    ]
