{-# LANGUAGE DeriveFunctor #-}
{-# OPTIONS_GHC -Wno-incomplete-patterns #-}
module Language.Sprite.L2.Types where

import qualified Language.Fixpoint.Types       as F
import           Language.Sprite.Common

-- | Basic types --------------------------------------------------------------

data Base = TInt | TBool
  deriving (Eq, Ord, Show)

-- | Refined Types ------------------------------------------------------------

data Type r
  = TBase !Base r                               -- Int{r}
  | TFun  !F.Symbol !(Type r) !(Type r)         -- x:s -> t
  deriving (Eq, Ord, Show)

rInt :: RType
rInt = TBase TInt mempty

rBool :: RType
rBool = TBase TBool mempty

type RType = Type F.Reft

-- | Primitive Constants ------------------------------------------------------

data PrimOp
  = BPlus
  | BMinus
  | BTimes
  | BLt
  | BLe
  | BEq
  | BGt
  | BGe
  | BAnd
  | BOr
  | BNot
  deriving (Eq, Ord, Show)

data Prim
  = PInt  !Integer                    -- 0,1,2,...
  | PBool !Bool                       -- true, false
  | PBin  !PrimOp                      -- +,-,==,<=,...
  deriving (Eq, Ord, Show)

---------------------------------------------------------------------------------
-- | Terms ----------------------------------------------------------------------
---------------------------------------------------------------------------------

-- | Bindings -------------------------------------------------------------------

data Bind a
  = Bind !F.Symbol a
  deriving (Eq, Ord, Show, Functor)

bindId :: Bind a -> F.Symbol
bindId (Bind x _) = x

-- | "Immediate" terms (can appear as function args & in refinements) -----------

data Imm a
  = EVar !F.Symbol a
  | ECon !Prim     a
  deriving (Show, Functor)

-- | Variable definition ---------------------------------------------------------

data Decl a
  = Decl  (Bind a) (Expr a)   a             -- plain      "let"
  | RDecl (Bind a) (Expr a)   a             -- recursive "let rec"
  deriving (Show, Functor)

-- | Terms -----------------------------------------------------------------------

data Expr a
  = EImm !(Imm  a)                     a    -- x,y,z,... 1,2,3...
  | EFun !(Bind a) !(Expr a)           a    -- \x -> e
  | EApp !(Expr a) !(Imm  a)           a    -- e v
  | ELet !(Decl a) !(Expr a)           a    -- let/rec x = e1 in e2
  | EAnn !(Expr a) !RType              a    -- e:t
  | EIf  !(Imm  a) !(Expr a) !(Expr a) a    -- if v e1 e2
  deriving (Show, Functor)

instance Label Imm  where
  label (EVar _ l) = l
  label (ECon _ l) = l

instance Label Expr where
  label (EImm _     l) = l
  label (EFun _ _   l) = l
  label (EApp _ _   l) = l
  label (ELet _ _   l) = l
  label (EAnn _ _   l) = l
  label (EIf  _ _ _ l) = l

instance Label Decl where
  label (Decl  _ _ l) = l
  label (RDecl _ _ l) = l

------------------------------------------------------------------------------
declsExpr :: [Decl a] -> Expr a
------------------------------------------------------------------------------
declsExpr [d]    = ELet d (intExpr 0 l)  l where l = label d
declsExpr (d:ds) = ELet d (declsExpr ds) l where l = label d

intExpr :: Integer -> a -> Expr a
intExpr i l = EImm (ECon (PInt i) l) l

boolExpr :: Bool -> a -> Expr a
boolExpr b l = EImm (ECon (PBool b) l) l

------------------------------------------------------------------------------
type SrcImm    = Imm  F.SrcSpan
type SrcBind   = Bind F.SrcSpan
type SrcDecl   = Decl F.SrcSpan
type SrcExpr   = Expr F.SrcSpan

instance F.Subable r => F.Subable (Type r) where
  -- syms   :: a -> [Symbol]
  syms (TBase _ r) = F.syms r

  -- substa :: (Symbol -> Symbol) -> Type r -> Type r
  substa f (TBase b r)  = TBase b (F.substa f r)
  substa f (TFun x s t) = TFun x  (F.substa f s) (F.substa f t)

  -- substf :: (Symbol -> Expr) -> Type r -> Type r
  substf f (TBase b r)  = TBase b (F.substf f r)
  substf f (TFun x s t) = TFun  x (F.substf f s) (F.substf f t)

  -- subst  :: Subst -> a -> a
  subst f (TBase b r)  = TBase b (F.subst f r)
  subst f (TFun x s t) = TFun  x (F.subst f s) (F.subst f t)
