# SPRITE

A tutorial-style implementation of liquid/refinement types for a subset of Ocaml/Reason.

## Install

1. Get Z3

[Download from here](https://github.com/Z3Prover/z3/releases) and make sure `z3` is on your `$PATH`

2. Clone the repository

```sh
git clone git@github.com:ranjitjhala/sprite-lang.git
cd sprite-lang
```

3. Build

Using `stack`

```sh
stack build
```

or

```sh
cabal build
```

Tested with GHC 8.10.7. If you run into LLVM-related errors, especially on an Apple M1 machine, [install llvm@13 using homebrew](https://www.reddit.com/r/haskell/comments/ufgf2a/comment/ioxzcuz/?context=3).

## Run on a single file

```sh
stack exec -- sprite 8 test/L8/pos/listSet.re
```

The `8` indicates the *language level* -- see below.

## Horn VC

When you run `sprite N path/to/file.re`
the generated Horn-VC is saved in `path/to/.liquid/file.re.smt2`.

So, for example:

```sh
stack exec -- sprite 8 test/L8/pos/listSet.re
```

will generate a VC in

```sh
test/L8/pos/.liquid/listSet.re.smt2
```

## Languages

- [x] Lang1: STLC + Annot         (refinements 101)
- [x] Lang2: ""   + Branches      (path-sensitivity)
- [x] Lang3: ""   + *-refinements (inference + qual-fixpoint)
- [x] Lang4: ""   + T-Poly        (type-polymorphism)
- [x] Lang5: ""   + Data          (datatypes & measures)
- [x] Lang6: ""   + R-Poly        (refinement-polymorphism)
- [x] Lang7: ""   + Termination   (metrics + invariants)
- [x] Lang8: ""   + Reflection    (proofs)
