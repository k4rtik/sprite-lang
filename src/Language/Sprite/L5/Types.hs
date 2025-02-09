{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE PatternSynonyms   #-}
{-# LANGUAGE OverloadedStrings #-}

module Language.Sprite.L5.Types where

import qualified Language.Fixpoint.Horn.Types  as H
import qualified Language.Fixpoint.Types       as F
import qualified Language.Fixpoint.Misc        as Misc
import qualified Language.Sprite.Common.Misc   as Misc
import qualified Language.Sprite.Common.UX     as UX
import           Language.Sprite.Common
import qualified Data.Set                      as S
import qualified Data.List                     as L

-- | Basic types --------------------------------------------------------------
newtype TVar = TV F.Symbol
  deriving (Eq, Ord, Show)

instance F.Symbolic TVar where
  symbol (TV a) = a

data Base = TInt | TBool | TVar TVar
  deriving (Eq, Ord, Show)

instance F.PPrint Base where
  pprintTidy _  = UX.tshow

-- | Refined Types ------------------------------------------------------------

data Type r
  = TBase !Base                         r    -- ^ Int{r}
  | TFun  !F.Symbol !(Type r) !(Type r)      -- ^ x:s -> t
  | TAll  !TVar     !(Type r)                -- ^ all a. t
  | TCon  !TyCon    ![Type r]           r    -- ^ C t1...tn
  deriving (Eq, Ord, Show)


rVar :: F.Symbol -> RType
rVar a = TBase (TVar (TV a)) mempty

rInt :: RType
rInt = TBase TInt mempty

rBool :: RType
rBool = TBase TBool mempty

data Reft
  = Known !F.Symbol !H.Pred                     -- ^ Known refinement
  | Unknown                                     -- ^ Unknown, to-be-synth refinement
  deriving (Show)

known :: F.Reft -> Reft
known (F.Reft (v, r)) = KReft v r

pattern KReft v p = Known v (H.Reft p)

instance Semigroup Reft where
  Unknown  <> r              = r
  r        <> Unknown        = r
--  KReft v1 r1 <> KReft v2 r2 = KReft v r where F.Reft (v, r) = F.Reft (v1, r1) <> F.Reft (v2, r2)
  Known v p <> Known v' p'
    | v == v'            = Known v  (p  <> p')
    | v == F.dummySymbol = Known v' (p' <> (p `F.subst1`  (v , F.EVar v')))
    | otherwise          = Known v  (p  <> (p' `F.subst1` (v', F.EVar v )))
--  _           <> _           = error "Semigroup Reft: TBD"

instance Monoid Reft where
  mempty = KReft v r where F.Reft (v, r) = mempty

type RType = Type Reft

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
  = Bind !Ident a
  deriving (Eq, Ord, Show, Functor)

instance F.Symbolic (Bind a) where
  symbol = bindId

bindId :: Bind a -> F.Symbol
bindId (Bind x _) = x

junkSymbol :: F.Symbol
junkSymbol = "_"

-- | Names of things ------------------------------------------------------------
type Ident = F.Symbol                       -- ^ Identifiers
type DaCon = F.Symbol                       -- ^ Data constructors
type TyCon = F.Symbol                       -- ^ Type constructors

-- | "Immediate" terms (can appear as function args & in refinements) -----------

data Imm a
  = EVar !Ident a
  | ECon !Prim  a
  deriving (Show, Functor)

-- | Variable definition ---------------------------------------------------------
data Decl a
  = Decl  (Bind a) (Expr a)   a             -- ^ plain     "let"
  | RDecl (Bind a) (Expr a)   a             -- ^ recursive "let rec"
  deriving (Show, Functor)

-- | Case-Alternatives -----------------------------------------------------------

data Alt a = Alt
  { altDaCon  :: !DaCon                     -- ^ Data constructor
  , altBinds  :: ![Bind a]                  -- ^ Binders x1...xn
  , altExpr   :: !(Expr a)                  -- ^ Body-expr
  , altLabel  :: a                          -- ^ Label
  }
  deriving (Show, Functor)

-- | Terms -----------------------------------------------------------------------
data Expr a
  = EImm !(Imm  a)                      a    -- ^ x,y,z,... 1,2,3...
  | EFun !(Bind a)  !(Expr a)           a    -- ^ \x -> e
  | EApp !(Expr a)  !(Imm  a)           a    -- ^ e v
  | ELet !(Decl a)  !(Expr a)           a    -- ^ let/rec x = e1 in e2
  | EAnn !(Expr a)  !RType              a    -- ^ e:t
  | EIf  !(Imm  a)  !(Expr a) !(Expr a) a    -- ^ if v e1 e2
  | ETLam !TVar     !(Expr a)           a    -- ^ Λ a. e (type abstraction)
  | ETApp !(Expr a) !RType              a    -- ^ e [t]  (type application)
  | ECase !Ident    ![Alt a]            a    -- ^ switch (x) { a1 ... }
  deriving (Show, Functor)

instance Label Bind where
  label (Bind _ l) = l

instance Label Alt where
  label = altLabel

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
  label (ETLam _ _  l) = l
  label (ETApp _ _  l) = l
  label (ECase _ _  l) = l

instance Label Decl where
  label (Decl  _ _ l) = l
  label (RDecl _ _ l) = l

------------------------------------------------------------------------------
-- | Top-level `Program` datatype
------------------------------------------------------------------------------
data Prog a = Prog
  { prQuals :: ![F.Qualifier]
  , prMeas  :: ![(F.Symbol, F.Sort)]
  , prExpr  :: !(Expr a)
  , prData  :: ![Data a]
  }
  deriving (Show, Functor)

data Data a = Data
  { dcName  :: !Ident                 -- ^ name of the datatype
  , dcVars  :: ![Ident]               -- ^ type variables
  , dcCtors :: ![(Bind a, RType)]     -- ^ constructors
  }
  deriving (Show, Functor)

------------------------------------------------------------------------------
declsExpr :: [Decl a] -> Expr a
------------------------------------------------------------------------------
declsExpr [d]    = ELet d (intExpr 0 l)  l where l = label d
declsExpr (d:ds) = ELet d (declsExpr ds) l where l = label d
declsExpr _      = error "impossible"

intExpr :: Integer -> a -> Expr a
intExpr i l = EImm (ECon (PInt i) l) l

boolExpr :: Bool -> a -> Expr a
boolExpr b l = EImm (ECon (PBool b) l) l

------------------------------------------------------------------------------
type SrcImm    = Imm   F.SrcSpan
type SrcBind   = Bind  F.SrcSpan
type SrcDecl   = Decl  F.SrcSpan
type SrcExpr   = Expr  F.SrcSpan
type ElbDecl   = Decl  F.SrcSpan
type ElbExpr   = Expr  F.SrcSpan
type SrcProg   = Prog  F.SrcSpan
type SrcData   = Data  F.SrcSpan
type SrcAlt    = Alt   F.SrcSpan
------------------------------------------------------------------------------

-- | should/need only be defined on "Known" variants. TODO:LIQUID
instance F.Subable Reft where
  syms     (Known v r)  = v : F.syms r
  syms      Unknown     = []
  substa f (Known v r)  = Known (f v) (F.substa f r)
  substa _  Unknown     = Unknown
  substf f (Known v r)  = Known v     (F.substf (F.substfExcept f [v]) r)
  substf _  Unknown     = Unknown
  subst su (Known v r)  = Known v     (F.subst  (F.substExcept su [v]) r)
  subst _   Unknown     = Unknown
  subst1 (Known v r) su = Known v     (F.subst1Except [v] r su)
  subst1  Unknown    _  = Unknown

instance F.Subable r => F.Subable (Type r) where
  -- syms   :: a -> [Symbol]
  syms (TBase _ r)     = F.syms r
  syms (TAll _ t)      = F.syms t
  syms (TFun _ s t)    = F.syms s ++ F.syms t
  syms (TCon _ ts r)   = concatMap F.syms ts ++ F.syms r


  -- substa :: (Symbol -> Symbol) -> Type r -> Type r
  substa f (TBase b r)   = TBase b (F.substa f r)
  substa f (TFun x s t)  = TFun x  (F.substa f s) (F.substa f t)
  substa f (TAll a t)    = TAll a  (F.substa f t)
  substa f (TCon c ts r) = TCon c  (F.substa f <$> ts) (F.substa f r)

  -- substf :: (Symbol -> Expr) -> Type r -> Type r
  substf f (TBase b r)   = TBase b (F.substf f r)
  substf f (TFun x s t)  = TFun  x (F.substf f s) (F.substf f t)
  substf f (TAll a t)    = TAll a  (F.substf f t)
  substf f (TCon c ts r) = TCon c  (F.substf f <$> ts) (F.substf f r)

  -- subst  :: Subst -> a -> a
  subst f (TBase b r)   = TBase b (F.subst f r)
  subst f (TFun x s t)  = TFun  x (F.subst f s) (F.subst f t)
  subst f (TAll a t)    = TAll a  (F.subst f t)
  subst f (TCon c ts r) = TCon c  (F.subst f <$> ts) (F.subst f r)

--------------------------------------------------------------------------------
-- | Substitution --------------------------------------------------------------
--------------------------------------------------------------------------------

substImm :: (F.Subable a) => a -> F.Symbol -> Imm b -> a
substImm thing x y = F.subst su thing
  where
    su          = F.mkSubst [(x, immExpr y)]

subst :: (F.Subable a) => a -> F.Symbol -> F.Symbol -> a
subst thing x y = substImm thing x (EVar y ())


immExpr :: Imm b -> F.Expr
immExpr (EVar x _)             = F.expr x
immExpr (ECon (PInt n) _)      = F.expr n
immExpr (ECon (PBool True) _)  = F.PTrue
immExpr (ECon (PBool False) _) = F.PFalse
immExpr _                      = error "impossible"


--------------------------------------------------------------------------------
-- | Dealing with Type Variables -----------------------------------------------
--------------------------------------------------------------------------------
tsubst :: TVar -> RType -> RType -> RType
tsubst a t = go
  where
    go (TAll b s)
      | a == b        = TAll b s
      | otherwise     = TAll b (go s)
    go (TFun x s1 s2) = TFun x (go s1) (go s2)
    go (TBase b r)    = bsubst a t b r
    go (TCon c ts r)  = TCon c (go <$> ts) r

tsubsts :: [(TVar, RType)] -> RType -> RType
tsubsts ats s = L.foldl' (\s (a, t) -> tsubst a t s) s ats

bsubst :: TVar -> RType -> Base -> Reft -> RType
bsubst a t (TVar v) r
  | v == a     = strengthenTop t r
bsubst _ _ b r = TBase b r

rTypeReft :: RType -> Maybe Reft
rTypeReft (TBase _   r) = Just r
rTypeReft (TCon  _ _ r) = Just r
rTypeReft _             = Nothing

strengthenTop :: RType -> Reft -> RType
strengthenTop t@TFun {} _      = t
strengthenTop t@TAll {} _      = t
strengthenTop (TBase b r) r'   = TBase b (r <> r')
strengthenTop (TCon c ts r) r' = TCon c ts (r <> r')

generalize :: RType -> RType
generalize t = foldr TAll t (freeTVars t)

freeTVars :: RType -> [TVar]
freeTVars = Misc.sortNub . S.toList . go
  where
    go (TAll a t)    = S.delete a (go t)
    go (TFun _ s t)  = S.union (go s) (go t)
    go (TCon _ ts _) = S.unions (go <$> ts)
    go (TBase b _)   = goB b
    goB (TVar a)     = S.singleton a
    goB _            = S.empty

-------------------------------------------------------------------------------
-- | Types and Sorts
-------------------------------------------------------------------------------

baseSort :: Base -> F.Sort
baseSort TInt     = F.intSort
baseSort TBool    = F.boolSort
baseSort (TVar a) = F.FObj (F.symbol a)

rTypeSort :: RType -> F.Sort
rTypeSort (TBase b _)   = baseSort b
rTypeSort (TCon c ts _) = F.fAppTC (fTyCon c) (rTypeSort <$> ts)
rTypeSort t@TFun {}     = rTypeSortFun t
rTypeSort t@TAll {}     = rTypeSortAll t

rTypeSortFun :: RType -> F.Sort
rTypeSortFun = F.mkFFunc 0 . fmap rTypeSort . go []
  where
    go ts (TFun _ t1 t2) = go (t1:ts) t2
    go ts t              = reverse (t:ts)

rTypeSortAll :: RType -> F.Sort
rTypeSortAll s = genSort (rTypeSort t)
  where
    genSort t  = L.foldl' (flip F.FAbs) (F.sortSubst su t) [0..n-1]
    (as, t)    = bkAll s
    su         = F.mkSortSubst $ zip sas (F.FVar <$> [0..])
    sas        = F.symbol <$> as
    n          = length as

bkAll :: RType -> ([TVar], RType)
bkAll (TAll a s) = (a:as, t) where (as, t) = bkAll s
bkAll t          = ([]  , t)

fTyCon :: TyCon -> F.FTycon
fTyCon = F.symbolFTycon . F.dummyLoc
