{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-# LANGUAGE TupleSections #-}
module Plutus.Contract.Blockchain.Utils
where
import PlutusTx.Prelude
import Ledger.Value as Value ( Value )
import           Ledger.Contexts          (ScriptContext (..), TxInfo (..))
import Ledger
    ( findDatum,
      findOwnInput,
      ownHash,
      valueLockedBy,
      ScriptContext(ScriptContext, scriptContextTxInfo),
      TxInInfo(TxInInfo, txInInfoResolved),
      TxInfo(TxInfo, txInfoInputs),
      TxOut(..),
      Value,
      Datum(getDatum),
      scriptHashAddress,
      Address, toValidatorHash )
import PlutusTx
import Ledger.Credential
import Ledger.Address (addressCredential)

--  The functions in this  module are not bounded to the marketplace use case.
--- These functions should probably be provided by the Plutus Library itself.


-- address of this validator
{-# INLINABLE ownAddress #-}
ownAddress :: ScriptContext -> Address
ownAddress ctx=scriptHashAddress (ownHash ctx)

-- all the utxos that are being redeemed from this contract in this transaction
{-# INLINABLE  ownInputs #-}
ownInputs:: ScriptContext -> [TxOut]
ownInputs ctx@ScriptContext{scriptContextTxInfo=TxInfo{txInfoInputs}}=
     filter (\x->txOutAddress x==ownAddress ctx) resolved
    where
    resolved=map (\x->txInInfoResolved x) txInfoInputs

-- get List of valid parsed datums  the script in this transaction
{-# INLINABLE ownInputDatums #-}
ownInputDatums :: FromData a => ScriptContext  -> [a]
ownInputDatums ctx= mapMaybe (txOutDatum ctx) $  ownInputs ctx

-- get List of the parsed datums  including the TxOut if datum is valid
{-# INLINABLE ownInputsWithDatum #-}
maybeOwnInputsWithDatum:: FromData a =>  ScriptContext ->[Maybe (TxOut,a)]
maybeOwnInputsWithDatum ctx=map (txOutWithDatum ctx)  ( ownInputs ctx)

ownInputsWithDatum:: FromData a=> ScriptContext  -> [(TxOut,a)]
ownInputsWithDatum ctx= map doValidate (ownInputs ctx)
  where
    doValidate:: FromData a =>  TxOut -> (TxOut,a)
    doValidate txOut = case txOutWithDatum ctx txOut of
      Just a -> a
      _      -> traceError "Datum format in Utxo is not of required type"

-- get input datum for the utxo that is currently being validated
{-# INLINABLE ownInputDatum #-}
ownInputDatum :: FromData a => ScriptContext -> Maybe a
ownInputDatum ctx = do
    txInfo <-findOwnInput ctx
    let txOut= txInInfoResolved txInfo
    txOutDatum ctx txOut

--  given an Utxo, resolve it's datum to our type
{-# INLINABLE txOutDatum #-}
txOutDatum::  FromData a =>  ScriptContext ->TxOut -> Maybe a
txOutDatum ctx txOut =do
            dHash<-txOutDatumHash txOut
            datum<-findDatum dHash (scriptContextTxInfo ctx)
            PlutusTx.fromBuiltinData $ getDatum datum

-- given txOut get resolve it to our type and return it with the txout
{-# INLINABLE txOutWithDatum #-}
txOutWithDatum::  FromData a =>  ScriptContext ->TxOut -> Maybe (TxOut,a)
txOutWithDatum ctx txOut =do
            d<-txOutDatum ctx txOut
            return (txOut,d)

--  value that is being redeemed from this contract in this utxo
{-# INLINABLE ownInputValue #-}
ownInputValue:: ScriptContext -> Value
ownInputValue ctx = case  findOwnInput ctx of
      Just TxInInfo{txInInfoResolved} ->  txOutValue txInInfoResolved

-- total value that will be locked by this contract in this transaction
{-# INLINABLE  ownOutputValue #-}
ownOutputValue :: ScriptContext -> Value
ownOutputValue ctx = valueLockedBy (scriptContextTxInfo ctx) (ownHash ctx)
