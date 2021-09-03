{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-#LANGUAGE FlexibleContexts#-}
module Plutus.Contract.Wallet.EndpointModels
where

import GHC.Generics (Generic)
import Data.Aeson (ToJSON (toJSON), FromJSON, object, (.=))
import Playground.Contract
import Plutus.Contract.Blockchain.MarketPlace
    ( dsCost,
      Auction(..),
      DirectSale(..),
      Market(mPrimarySaleFee, mSecondarySaleFee, mAuctionFee),
      Price(..),
      SellType(Secondary), marketHundredPercent,Percent,percent)
import Ledger hiding (value,singleton,fee)
import Ledger.Value
import Data.String.Conversions (convertString)
import Ledger.Ada (adaSymbol,adaToken)
import Data.Aeson.Extras
import Plutus.Contract.Wallet.Utils (ParsedUtxo)
import Wallet.Emulator.Wallet (walletPubKey)
import qualified Data.Aeson.Encoding (string)
import qualified Data.Aeson.Extras as JSON
import PlutusTx.Prelude (BuiltinByteString, fromBuiltin)


-- The models in this package are the response types used to tell state.
-- These data classes have much flatter structure compared to the default JSON types of
-- the classes.
-- For example response for Asset class by default is
-- {
--   "unAssetClass":[{"unCurrencySymbol": "abcd...",{"unTokenName":"0xabc..."}}]
-- }
-- but with AssetId, the response is
--{
--  "assCurrency":"abcd...",
--  "assToken": "0xabcd..."
--}
-- It's much readable and is easier to understant in  frontend.


-- instance FromJSON CurrencySymbol where
--   parseJSON =
--     JSON.withObject "CurrencySymbol" $ \object -> do
--       raw <- object .: "unCurrencySymbol"
--       bytes <- JSON.decodeBuiltinByteString raw
--       Haskell.pure $ CurrencySymbol $ PlutusTx.toBuiltin bytes


-- A user involved in a share who's expected to get some  returns.
data Party=Party{
  pPubKeyHash::PubKeyHash ,
  pShare:: Integer
} deriving (Generic,ToJSON,FromJSON,Prelude.Show,ToSchema)

-- represents an AssetClass
data AssetId=AssetId
    {
        assCurrency :: !BuiltinByteString,
        assToken:: !BuiltinByteString
    } deriving(Generic, ToJSON,FromJSON,Prelude.Show,ToSchema )

data MintParams = MintParams
    { mpTokenName :: !TokenName
    , mpAmount    :: !Integer
    } deriving (GHC.Generics.Generic , ToJSON, FromJSON, ToSchema)

data SellParams =SellParams{
        spShare::[Party],
        spItems::[ValueInfo],
        spSaleType :: SellType, -- Primary | Secondary
        spTotalCost  ::ValueInfo
    } deriving(GHC.Generics.Generic,ToJSON ,FromJSON,ToSchema ,Show)



-- Singleton of a Value
data ValueInfo=ValueInfo{
    currency::BuiltinByteString,
    token:: BuiltinByteString,
    value:: Integer
} deriving(Generic,FromJSON,Prelude.Show,ToSchema,Prelude.Eq )

instance ToJSON ValueInfo
  where
    toJSON (ValueInfo c t v) = object [  "currency" .= doConvert c, "token" .= doConvert t,"value".=toJSON v]
      where

        doConvert bs= toJSON $ toText bs

        toText bs= encodeByteString $ fromBuiltin  bs

data PurchaseParam =PurchaseParam
  {
    ppValue:: ValueInfo,
    ppItems:: [TxOutRef]
  } deriving(GHC.Generics.Generic,ToJSON,FromJSON,ToSchema)

data AuctionParam = AuctionParam{
    apParties::[Party],
    apValue::[ValueInfo],
    apMinBid:: ValueInfo,
    apMinIncrement:: Integer,
    apStartTime::POSIXTime,
    apEndTime::POSIXTime
} deriving(GHC.Generics.Generic,ToJSON,FromJSON,ToSchema)

data BidParam=BidParam{
  ref :: TxOutRef,
  bidValue       :: [ValueInfo]
} deriving(Generic,ToJSON,FromJSON,ToSchema)

data ClaimParam=ClaimParam{
  references ::[TxOutRef],
  ignoreUnClaimable :: Bool
} deriving(Generic,ToJSON,FromJSON,ToSchema)

instance ToSchema TxOutRef

data Bidder = Bidder{
      bPubKeyHash :: PubKeyHash,
      bBid  :: Integer,
      bBidReference:: TxOutRef
} deriving (Generic,FromJSON,ToJSON,Prelude.Show,Prelude.Eq)


data AuctionResponse = AuctionResponse{
      arOwner :: PubKeyHash,
      arValue ::[ValueInfo],
      arMinBid:: ValueInfo,
      arMinIncrement:: Integer,
      arDuration::(Extended  POSIXTime,Extended  POSIXTime),
      arBidder :: Bidder,
      arMarketFee:: Integer
}deriving (Generic,FromJSON,ToJSON,Prelude.Show,Prelude.Eq)


data NftsOnSaleResponse=NftsOnSaleResponse{
    cost::ValueInfo ,
    saleType:: SellType,
    fee:: Integer,
    owner:: BuiltinByteString,
    values:: [ValueInfo],
    reference :: TxOutRef
}deriving(Generic,FromJSON,ToJSON,Prelude.Show,Prelude.Eq)

data MarketType=MtDirectSale | MtAuction  deriving (Show, Prelude.Eq,Generic,ToJSON,FromJSON,ToSchema)


data ListMarketRequest  = ListMarketRequest{
    lmUtxoType::MarketType,
    lmByPkHash:: Maybe BuiltinByteString,
    lmOwnPkHash:: Maybe Bool
} deriving (Show, Prelude.Eq,Generic,ToJSON,FromJSON,ToSchema)


assetIdToAssetClass :: AssetId -> AssetClass
assetIdToAssetClass AssetId{assCurrency,assToken}=AssetClass (CurrencySymbol assCurrency, TokenName assToken )

assetIdOf:: AssetClass -> AssetId
assetIdOf (AssetClass (CurrencySymbol c, TokenName t))=AssetId{
    assCurrency = c,
    assToken=t
  }

sellParamToDirectSale :: PubKeyHash -> SellParams->DirectSale
sellParamToDirectSale  pkh (SellParams parties items stype (ValueInfo c t v)) = DirectSale {
                        dsSeller=pkh,
                      dsParties =map toPartyTuple parties,
                      dsAsset  = AssetClass (CurrencySymbol c, TokenName t),
                      dsType=stype,
                      dsCost=v
                      }
  where
    toPartyTuple (Party p s)=(p,s)

aParamToAuction :: PubKeyHash -> AuctionParam -> Auction
aParamToAuction ownerPkh ap  =Auction {
              aParties      =  map (\x -> (pPubKeyHash x,pShare x)) $ apParties ap,
              aOwner        =  ownerPkh,
              aBidder       = ownerPkh,
              aAssetClass   = valueInfoAssetClass (apMinBid  ap),
              aMinBid       = value ( apMinBid  ap),
              aMinIncrement = apMinIncrement  ap,
              aDuration     =  Interval ( LowerBound  (Finite $ apStartTime ap) True) ( UpperBound  (Finite $ apEndTime ap) False),
              aValue        = mconcat $ map valueInfoToValue ( apValue  ap)
          }


directSaleToResponse:: Market -> ParsedUtxo DirectSale  -> NftsOnSaleResponse
directSaleToResponse market (txOutRef,txOutTx,ds@DirectSale{dsAsset ,dsParties,dsType}) =
        NftsOnSaleResponse{
            cost=ValueInfo (unCurrencySymbol $ fst $ unAssetClass  dsAsset ) (unTokenName  $ snd $ unAssetClass  dsAsset) (dsCost ds),
            saleType= dsType,
            fee= if dsType == Secondary  then mPrimarySaleFee  market else mSecondarySaleFee market,
            owner= getPubKeyHash $  dsSeller  ds,
            values= toValueInfo (txOutValue (txOutTxOut  txOutTx)),
            reference=txOutRef
        }

auctionToResponse:: Market -> ParsedUtxo Auction -> AuctionResponse
auctionToResponse market  (ref,TxOutTx tx (TxOut addr value _ ), a) = AuctionResponse{
      arOwner = aOwner a,
      arValue = toValueInfo (aValue a),
      arMinBid = valueInfo (aAssetClass a) (aMinBid a),
      arMinIncrement = aMinIncrement a,
      arDuration =  (lb (ivFrom   (aDuration a)),ub (ivTo (aDuration a))),
      arBidder = Bidder{
                  bPubKeyHash   = aBidder  a,
                  bBid          = assetClassValueOf  value $ aAssetClass a,
                  bBidReference =  ref
              },
      arMarketFee = mAuctionFee market
}
  where
    lb (LowerBound a _ )=a
    ub (UpperBound a _) =a

valueInfoLovelace :: Integer -> ValueInfo
valueInfoLovelace=ValueInfo (unCurrencySymbol adaSymbol) (unTokenName adaToken)

valueInfoAssetClass:: ValueInfo -> AssetClass
valueInfoAssetClass (ValueInfo c t _)= AssetClass (CurrencySymbol c, TokenName t)

toValueInfo::Value ->[ValueInfo]
toValueInfo v=map doMap $ flattenValue v
    where
        doMap (c,t,v)=ValueInfo (unCurrencySymbol c) ( unTokenName t) v

valueInfoToPrice :: ValueInfo -> Price
valueInfoToPrice ValueInfo{currency,token,value}= Price  (CurrencySymbol currency, TokenName token, value)

valueInfoToValue ::ValueInfo -> Value
valueInfoToValue ValueInfo{currency,token,value}= Ledger.Value.singleton (CurrencySymbol currency) (TokenName  token) value

valueInfosToValue :: [ValueInfo] -> Value
valueInfosToValue vinfos= mconcat $ map valueInfoToValue vinfos

valueInfo :: AssetClass  -> Integer -> ValueInfo
valueInfo (AssetClass (c, t)) = ValueInfo (unCurrencySymbol c) ( unTokenName t)

priceToValueInfo::Price ->ValueInfo
priceToValueInfo (Price (c, t, v))=ValueInfo (unCurrencySymbol c) ( unTokenName t) v
