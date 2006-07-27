(* ========================================================================= *)
(* FILE          : bsubstScript.sml                                          *)
(* DESCRIPTION   : Block substitution                                        *)
(*                                                                           *)
(* AUTHOR        : (c) Anthony Fox, University of Cambridge                  *)
(* DATE          : 2005-2006                                                 *)
(* ========================================================================= *)

(* interactive use:
  app load ["wordsTheory", "rich_listTheory", "my_listTheory", "armTheory"];
*)

open HolKernel boolLib bossLib;
open Parse Q arithmeticTheory wordsTheory;
open listTheory rich_listTheory my_listTheory armTheory;

val _ = new_theory "bsubst";

(* ------------------------------------------------------------------------- *)

infix \\ << >>

val op \\ = op THEN;
val op << = op THENL;
val op >> = op THEN1;

val _ = set_fixity "::->" (Infixr 325);
val _ = set_fixity "::-<" (Infixr 325);

val BSa_def = xDefine "BSa" `$::-> = $::-`;
val BSb_def = xDefine "BSb" `$::-< = $::-`;

val JOIN_def = new_definition("new_definition",
  `JOIN n x y =
    let lx = LENGTH x and ly = LENGTH y in
    let j = MIN n lx in
       GENLIST
         (\i. if i < n then
                if i < lx then EL i x else EL (i - j) y
              else
                if i - j < ly then EL (i - j) y else EL i x)
         (MAX (j + ly) lx)`);

(* ------------------------------------------------------------------------- *)

val JOIN_lem = prove(`!a b. MAX (SUC a) (SUC b) = SUC (MAX a b)`,
   RW_TAC std_ss [MAX_DEF]);

val JOIN_TAC =
  CONJ_TAC >> RW_TAC list_ss [LENGTH_GENLIST,MAX_DEF,MIN_DEF]
    \\ Cases
    \\ RW_TAC list_ss [MAX_DEF,MIN_DEF,LENGTH_GENLIST,EL_GENLIST,
         ADD_CLAUSES,HD_GENLIST]
    \\ FULL_SIMP_TAC arith_ss [NOT_LESS]
    \\ RW_TAC arith_ss [GENLIST,TL_SNOC,EL_SNOC,NULL_LENGTH,EL_GENLIST,
         LENGTH_TL,LENGTH_GENLIST,LENGTH_SNOC,(GSYM o CONJUNCT2) EL]
    \\ SIMP_TAC list_ss [];

val JOIN = store_thm("JOIN",
  `(!n ys. JOIN n [] ys = ys) /\
   (!xs. JOIN 0 xs [] = xs) /\
   (!x xs y ys. JOIN 0 (x::xs) (y::ys) = y :: JOIN 0 xs ys) /\
   (!n xs y ys. JOIN (SUC n) (x::xs) ys = x :: (JOIN n xs ys))`,
  RW_TAC (list_ss++boolSimps.LET_ss) [JOIN_def,JOIN_lem]
    \\ MATCH_MP_TAC LIST_EQ
    << [
      Cases_on `n` >> RW_TAC arith_ss [LENGTH_GENLIST,EL_GENLIST] \\ JOIN_TAC
        \\ `?p. LENGTH ys = SUC p` by METIS_TAC [ADD1,LESS_ADD_1,ADD_CLAUSES]
        \\ ASM_SIMP_TAC list_ss [HD_GENLIST],
      RW_TAC arith_ss [LENGTH_GENLIST,EL_GENLIST],
      JOIN_TAC, JOIN_TAC]);

(* ------------------------------------------------------------------------- *)

val BSUBST_EVAL = store_thm("BSUBST_EVAL",
  `!a b l m. (a ::- l) m b =
      let na = w2n a and nb = w2n b in
      let d = nb - na in
        if na <= nb /\ d < LENGTH l then EL d l else m b`,
  NTAC 2 wordsLib.Cases_word
    \\ RW_TAC (std_ss++boolSimps.LET_ss) [WORD_LS,BSUBST_def]
    \\ FULL_SIMP_TAC arith_ss []);

val SUBST_BSUBST = store_thm("SUBST_BSUBST",
   `!a b m. (a :- b) m = (a ::- [b]) m`,
  RW_TAC (std_ss++boolSimps.LET_ss) [FUN_EQ_THM,BSUBST_def,SUBST_def]
    \\ Cases_on `a = x`
    \\ ASM_SIMP_TAC list_ss [WORD_LOWER_EQ_REFL]
    \\ ASM_SIMP_TAC arith_ss [WORD_LOWER_OR_EQ,WORD_LO]);

val BSUBST_BSUBST = store_thm("BSUBST_BSUBST",
  `!a b x y m. (a ::- y) ((b ::- x) m) =
     let lx = LENGTH x and ly = LENGTH y in
        if a <=+ b then
          if w2n b - w2n a <= ly then
            if ly - (w2n b - w2n a) < lx then
              (a ::- y ++ BUTFIRSTN (ly - (w2n b - w2n a)) x) m
            else
              (a ::- y) m
          else
            (a ::- y) ((b ::- x) m)
        else (* b <+ a *)
          if w2n a - w2n b < lx then
            (b ::- JOIN (w2n a - w2n b) x y) m
          else
            (b ::- x) ((a ::- y) m)`,
  REPEAT STRIP_TAC \\ SIMP_TAC (bool_ss++boolSimps.LET_ss) []
    \\ Cases_on `a <=+ b`
    \\ FULL_SIMP_TAC std_ss [WORD_NOT_LOWER_EQUAL,WORD_LS,WORD_LO]
    << [
      Cases_on `w2n b <= w2n a + LENGTH y` \\ ASM_SIMP_TAC std_ss []
        \\ `w2n b - w2n a <= LENGTH y` by DECIDE_TAC
        \\ Cases_on `LENGTH x = 0`
        \\ Cases_on `LENGTH y = 0`
        \\ IMP_RES_TAC LENGTH_NIL
        \\ FULL_SIMP_TAC list_ss [FUN_EQ_THM,WORD_LS,BSUBST_def,BUTFIRSTN]
        >> (`w2n a = w2n b` by DECIDE_TAC \\ ASM_SIMP_TAC std_ss [])
        \\ NTAC 2 (RW_TAC std_ss [])
        \\ FULL_SIMP_TAC arith_ss
             [NOT_LESS,NOT_LESS_EQUAL,EL_APPEND1,EL_APPEND2,EL_BUTFIRSTN]
        \\ FULL_SIMP_TAC arith_ss []
        \\ `LENGTH y + w2n a - w2n b <= LENGTH x` by DECIDE_TAC
        \\ FULL_SIMP_TAC arith_ss [LENGTH_BUTFIRSTN],
      REWRITE_TAC [FUN_EQ_THM] \\ RW_TAC arith_ss []
        << [
          RW_TAC (arith_ss++boolSimps.LET_ss) [WORD_LS,BSUBST_def,JOIN_def,
                 EL_GENLIST,LENGTH_GENLIST,MIN_DEF,MAX_DEF]
            \\ FULL_SIMP_TAC arith_ss [],
          FULL_SIMP_TAC arith_ss [NOT_LESS]
            \\ IMP_RES_TAC LENGTH_NIL
            \\ RW_TAC (arith_ss++boolSimps.LET_ss) [WORD_LS,BSUBST_def]
            \\ FULL_SIMP_TAC arith_ss []]]);

(* ------------------------------------------------------------------------- *)

val _ = export_theory();
