{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
module Plutus.Contract.Wallet.Utils
where

import Data.Map ( elems )
import Plutus.Contract

import Data.Text ( Text )
import Ledger ( pubKeyAddress, TxOut (txOutValue), TxOutTx (txOutTxOut, txOutTxTx), txOutTxDatum, TxOutRef, Address, DatumHash, Datum(..), Tx (txData), txOutDatum, ChainIndexTxOut)
import Ledger.Value ( Value, flattenValue, toString )
import Data.Monoid
import Control.Monad (void)
import qualified Data.Aeson.Types as Types
import qualified Data.Map as Map
import Data.Aeson (toJSON, encode)
import Ledger.AddressMap (UtxoMap)
import PlutusTx
import Playground.Contract ( TxOutRef )
import Data.Maybe ( isJust, fromJust, catMaybes, mapMaybe )
import Data.Functor ((<&>))
import Control.Lens (review)
import Plutus.Contract.Types
import Plutus.Contract.Constraints (MkTxError(TxOutRefNotFound, TxOutRefWrongType))

--  The functions in this  module are not bounded to the marketplace use case.
--- These functions should probably be provided by the Plutus Library itself.
--


-- Utxo , It's parent transaction and the datum carrried by it resolved to our required data type.
type   ParsedUtxo a =  (TxOutRef,ChainIndexTxOut , a)


-- Transform Utxo Map to list.
-- But include only those utxos that have expected Datum type. Ignore others.
flattenUtxosWithData ::   FromData a =>   Map.Map TxOutRef ChainIndexTxOut   -> [ParsedUtxo a]
flattenUtxosWithData m= mapMaybe doTransform $ Map.toList m
  where
    doTransform (ref,index) =txOutTxData index <&> (ref,index,)

 -- Find All utxos  at address and return It's reference, original transacction and   resolved datum of utxo
 -- The utxos that don't have expected data type are ignored.

utxosWithDataAt ::    ( AsContractError e,FromData a) =>
               Address ->Contract w s e [ParsedUtxo a]
utxosWithDataAt address=do
    utxos<-utxosAt address
    pure  $ flattenUtxosWithData utxos

-- With Filter funciton f, return list containing reference, parent transaction
-- and resolved. data of the utxo.
-- Utxos that don't have expected data type are ignored
filterUtxosWithDataAt ::    ( AsContractError e,FromData a) =>
               (TxOutRef-> TxOutTx -> Bool) -> Address ->Contract w s e [ParsedUtxo a]
filterUtxosWithDataAt f addr =do
    utxos<-utxosAt addr
    let responses =  Map.filterWithKey f  utxos
    pure $ flattenUtxosWithData responses

-- Given TxoutReferences, find thost at given address, and resolve the datum field to expected
-- data type
resolveRefsWithDataAt:: (FromData  a,AsContractError e) => Address  ->[TxOutRef]  -> Contract w s e [ParsedUtxo a]
resolveRefsWithDataAt addr refs= do
    utxos <- utxosAt addr
    let doResolve x =( do
                tx <- Map.lookup x utxos
                d <- txOutTxData tx
                pure (x,tx,d)
          )
    pure $ mapMaybe doResolve  refs

--  resolve UtxoRefs and return them with datum. If the datum is not in expected type, throw error
resolveRefsWithDataAtWithError :: (FromData  a,AsContractError e) => Address  ->[TxOutRef]  -> Contract w s e [ParsedUtxo a]
resolveRefsWithDataAtWithError addr refs =do
  utxos <-utxosAt addr
  mapM  (resolveTxOutRefWithData utxos)  refs


-- Given TxOut Reference, Resolve it's transaction
-- and the datum info expected data type
-- If utxo is not found or datum couldn't be transformed properly, It will throw error.
resolveRefWithDataAt:: (FromData  a,AsContractError e) => Address  ->TxOutRef  -> Contract w s e  (ParsedUtxo a)
resolveRefWithDataAt addr ref = utxosAt addr >>= flip resolveTxOutRefWithData ref

-- From a utxo reference, find out datum in it.
--
resolveTxOutRefWithData::(FromData a,AsContractError e) =>
  UtxoMap -> TxOutRef -> Contract  w s e (ParsedUtxo a)
resolveTxOutRefWithData  utxos ref=  case Map.lookup ref utxos of
    Just tx -> case txOutTxData tx <&> (ref, tx,) of
            Just v -> return v
            Nothing -> throwError  $ review _ConstraintResolutionError   $ TxOutRefWrongType ref
    _       -> throwError  $ review _ConstraintResolutionError   $ TxOutRefNotFound ref

-- Give TxOutRef, get Data in it
txOutRefData :: (FromData a) => UtxoMap  -> TxOutRef -> Maybe a
txOutRefData  dataMap ref=do
    tx <-Map.lookup ref dataMap
    txOutTxData tx


-- Given TxOutTx, resolve Datum in the Utxo to expected type

txOutTxData :: (FromData a)=>TxOutTx -> Maybe a
txOutTxData o =mappedData (txOutTxOut o) $ \dh -> Map.lookup dh $ txData $ txOutTxTx o
    where
    mappedData :: FromData a => TxOut -> (DatumHash -> Maybe Datum) -> Maybe a
    mappedData o f = do
        dh      <- txOutDatum o
        d <- f dh
        fromData $  builtinDataToData  $getDatum d


--------------
-------------- Utility Endpoints
--------------

-- get funds in this wallet
ownFunds ::  Contract w s Text Value
ownFunds = do
    pk    <- ownPubKey
    utxos <- utxosAt $ pubKeyAddress pk
    pure . mconcat . elems $ txOutValue . txOutTxOut <$> utxos

type UtilSchema=
  Endpoint "funds" String

-- don't restrict the return type to UtilSchema so that it can later be merged with other schemas.
utilEndpoints :: HasEndpoint "funds" String s => Promise [Types.Value] s  Text ()
utilEndpoints= void fundsEp

-- fundsEp :: => Contract
--   [Types.Value] s Text Types.Value
fundsEp ::  HasEndpoint "funds" String s => Promise [Types.Value] s  Text Types.Value
fundsEp=
    endpoint @"funds" $ \v -> do
    v<- ownFunds
    tell [ toJSON v]
-- let's hope that in future we can return the json string without having to tell
    return $ toJSON  v

throwNoUtxo::AsContractError e =>Contract w s e a
throwNoUtxo=throwError  $ review _OtherError "No valid Utxo to consume"

otherError :: ( AsContractError e) =>Text -> Contract w s e a
otherError s = throwError  $ review _OtherError s
