{-# LANGUAGE OverloadedStrings #-}

module Language.Sprite.L4.Prims  where

import qualified Data.Maybe                  as Mb
import qualified Data.Map                    as M
import qualified Language.Fixpoint.Types     as F
import qualified Language.Sprite.Common.UX   as UX
import           Language.Sprite.L4.Types
import           Language.Sprite.L4.Parse

-- | Primitive Types --------------------------------------------------

constTy :: F.SrcSpan -> Prim -> RType
constTy _ (PInt  n)     = TBase TInt  (known $ F.exprReft (F.expr n))
constTy _ (PBool True)  = TBase TBool (known $ F.propReft F.PTrue)
constTy _ (PBool False) = TBase TBool (known $ F.propReft F.PFalse)
constTy l (PBin  o)     = binOpTy l o


binOpTy :: F.SrcSpan -> PrimOp -> RType
binOpTy l o = Mb.fromMaybe err (M.lookup o binOpEnv)
  where
    err     = UX.panicS ("Unknown PrimOp: " ++ show o) l

bTrue :: Base -> RType
bTrue b = TBase b mempty

binOpEnv :: M.Map PrimOp RType
binOpEnv = M.fromList
  [ (BPlus , mkTy "x:int => y:int => int[v|v=x+y]")
  , (BMinus, mkTy "x:int => y:int => int[v|v=x-y]")
  , (BTimes, mkTy "x:int => y:int => int[v|v=x*y]")

  , (BLt   , mkTy "x:int => y:int => bool[v|v <=> (x <  y)]")
  , (BLe   , mkTy "x:int => y:int => bool[v|v <=> (x <= y)]")
  , (BGt   , mkTy "x:int => y:int => bool[v|v <=> (x >  y)]")
  , (BGe   , mkTy "x:int => y:int => bool[v|v <=> (x >= y)]")
  , (BEq   , mkTy "x:int => y:int => bool[v|v <=> (x == y)]")

  , (BAnd  , mkTy "x:bool => y:bool => bool[v|v <=> (x && y)]")
  , (BOr   , mkTy "x:bool => y:bool => bool[v|v <=> (x || y)]")
  , (BNot  , mkTy "x:bool => bool[v|v <=> not x]")
  ]

mkTy :: String -> RType
mkTy = rebind . parseWith rtype "prims"


rebind :: RType -> RType
rebind t@TBase {}   = t
rebind (TAll a t)   = TAll a (rebind t)
rebind (TFun x s t) = TFun x' s' t'
  where
    x' = F.mappendSym "spec#" x
    s' = subst (rebind s) x x'
    t' = subst (rebind t) x x'
