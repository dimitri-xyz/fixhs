-- Module  : Data.FIX.Arbitrary
-- License : LGPL-2.1

module Data.FIX.Arbitrary
    ( arbitraryFIXValues
    , arbitraryFIXGroup
    , arbitraryFIXMessage )
    where

import Data.FIX.Message (
    FIXGroupElement(..), FIXTag(..), FIXValue(..), FIXValues, FIXTags
      , FIXMessage(..), FIXSpec, FIXMessageSpec(..), FIXGroupSpec(..) )
import System.Time ( CalendarTime (..) )
import Data.ByteString ( ByteString )
import qualified Data.ByteString.Char8 as C ( pack )
import qualified Data.Char as C ( isAscii, isAlphaNum )
import qualified Data.LookupTable as LT ( insert, toList, fromList, new )
import Data.Functor ( (<$>) )
import Control.Monad ( replicateM, liftM )
import Test.QuickCheck ( Gen, arbitrary, Arbitrary )

arbitraryFIXValues :: FIXTags -> Gen FIXValues
arbitraryFIXValues tags = 
    let tlist :: [FIXTag]
        tlist = map snd $ LT.toList tags
        arb :: FIXTag -> Gen (Int, FIXValue)
        arb tag = fmap ((,) (tnum tag)) $ arbitraryValue tag
    in
        liftM LT.fromList $ mapM arb tlist

arbitraryFIXGroup :: FIXGroupSpec -> Gen FIXValue
arbitraryFIXGroup spec =
    let ltag = gsLength spec in do
       t <- arbitraryValue ltag
       case t of
        FIXInt l' -> let l = l' `mod` 4 in
           do bodies <- replicateM l arbitraryGBody
              return $ FIXGroup l bodies
        _         -> error $ "do not know " ++ show (tnum ltag)
    where
        arbitraryGBody =
           let stag = gsSeperator spec
               btags = gsBody spec
           in do
               s  <- arbitraryValue stag
               vs <- arbitraryFIXValues btags
               return (FIXGroupElement (tnum stag) s vs)

arbitraryFIXMessage :: FIXSpec -> FIXMessageSpec -> Gen (FIXMessage FIXSpec)
arbitraryFIXMessage context spec = do
        header <- arbitraryFIXValues $ msHeader spec
        body <- arbitraryFIXValues $ msBody spec
        trailer <- arbitraryFIXValues $ msTrailer spec
        return FIXMessage
            { mContext = context
            , mType = msType spec
            , mHeader = header
            , mBody = body
            , mTrailer = trailer }

-- An arbitrary instance of ByteString.
--- we generate a random string out of digits and numbers
--- generated string has length at least 1 and most <max>
instance Arbitrary ByteString where
        arbitrary = do
            l' <- arbitrary :: Gen Int
            let l = 1 + l' `mod` maxLen
            C.pack <$> replicateM l (aChar isAlpha')
            where
                aChar :: (Char -> Bool) -- predicate
                        -> Gen Char     -- random generator
                aChar p = do
                    c <- arbitrary
                    if p c then return c else aChar p

                isAlpha' c = C.isAlphaNum c && C.isAscii c
                maxLen = 15

instance Arbitrary CalendarTime where
        arbitrary = do
            year <- aYear
            month <- aMonth
            day <- aDay
            hour <- aHour
            minute <- aMin
            sec <- aSec
            psec <- aPsec
            return CalendarTime
             { ctYear  = year
             , ctMonth = toEnum month
             , ctDay   = day
             , ctHour  = hour
             , ctMin   = minute
             , ctSec   = sec
             , ctPicosec = psec
             , ctWDay  = toEnum 0
             , ctYDay  = toEnum 0
             , ctTZName = "UTC"
             , ctTZ    = 0
             , ctIsDST = True }
             where
                aYear  = (`mod` 10000) <$> arbitrary
                aMonth =    (`mod` 12) <$> arbitrary
                aHour  =    (`mod` 24) <$> arbitrary
                aDay   =    (`mod` 28) <$> arbitrary
                aMin   =    (`mod` 60) <$> arbitrary
                aSec   =    (`mod` 60) <$> arbitrary
                aPsec  = (`mod` 1000000000000) <$> arbitrary
