{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# OPTIONS_GHC -fno-specialise #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
{-# OPTIONS_GHC -fobject-code #-}

module Plutus.Contracts.NftMarketplace.OnChain.Core.NFT where

import           Control.Lens                   ((&), (.~), (?~), (^.))
import qualified Control.Lens                   as Lens
import qualified Data.Aeson                     as J
import qualified Data.Text                      as T
import qualified Ext.Plutus.Contracts.Auction   as Auction
import qualified GHC.Generics                   as Haskell
import           Ledger
import qualified Ledger.Constraints             as Constraints
import qualified Ledger.Typed.Scripts           as Scripts
import qualified Ledger.Value                   as V
import           Plutus.Contract
import           Plutus.Contract.StateMachine
import qualified Plutus.Contracts.Services.Sale as Sale
import qualified PlutusTx
import qualified PlutusTx.AssocMap              as AssocMap
import           PlutusTx.Prelude               hiding (Semigroup (..))
import           Prelude                        (Semigroup (..))
import qualified Prelude                        as Haskell

-- TODO (?) add tags
type IpfsCid = ByteString
type IpfsCidHash = ByteString
type Auction = (AssetClass, PubKeyHash, Value, Slot)
type Category = [ByteString]
type LotLink = Either Sale.Sale Auction

data NftInfo =
  NftInfo
    { niCurrency    :: !CurrencySymbol
    , niName        :: !ByteString
    , niDescription :: !ByteString
    , niCategory    :: !Category
    , niIssuer      :: !(Maybe PubKeyHash)
    }
  deriving stock (Haskell.Eq, Haskell.Show, Haskell.Generic)
  deriving anyclass (J.ToJSON, J.FromJSON)

PlutusTx.unstableMakeIsData ''NftInfo

PlutusTx.makeLift ''NftInfo

Lens.makeClassy_ ''NftInfo

data NFT =
  NFT
    { nftRecord :: !NftInfo
    , nftLot    :: !(Maybe (IpfsCid, LotLink))
    }
  deriving stock (Haskell.Eq, Haskell.Show, Haskell.Generic)
  deriving anyclass (J.ToJSON, J.FromJSON)

PlutusTx.unstableMakeIsData ''NFT

PlutusTx.makeLift ''NFT

Lens.makeClassy_ ''NFT

data Bundle
  = NoLot  !(AssocMap.Map IpfsCidHash NftInfo)
  | HasLot !(AssocMap.Map IpfsCidHash (IpfsCid, NftInfo)) !LotLink
  deriving stock (Haskell.Eq, Haskell.Show, Haskell.Generic)
  deriving anyclass (J.ToJSON, J.FromJSON)

PlutusTx.unstableMakeIsData ''Bundle

PlutusTx.makeLift ''Bundle

Lens.makeClassyPrisms ''Bundle

data NftBundle =
  NftBundle
    { nbName        :: !ByteString
    , nbDescription :: !ByteString
    , nbCategory    :: !Category
    , nbTokens      :: !Bundle
    }
  deriving stock (Haskell.Eq, Haskell.Show, Haskell.Generic)
  deriving anyclass (J.ToJSON, J.FromJSON)

PlutusTx.unstableMakeIsData ''NftBundle

PlutusTx.makeLift ''NftBundle

Lens.makeClassy_ ''NftBundle

-- ????
type ValueHash = ByteString
type BundleId = [IpfsCidHash]
-- does Crypto.Hash.hashUpdates depend on order?
