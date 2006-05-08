(*****************************************************************************)
(* Theorems for word32 values needed for compile Fact32 example.             *)
(*****************************************************************************)
 
(*****************************************************************************) 
(* START BOILERPLATE                                                         *) 
(*****************************************************************************) 
(****************************************************************************** 
* Load theories 
******************************************************************************) 
(* 
quietdec := true;
loadPath := "../" :: "word32" :: "../dff/" :: !loadPath;
map load
 ["metisLib","intLib","word32Theory","word32Lib",
  "devTheory","compileTheory","compile","vsynth"];
open metisLib word32Theory word32Lib;
open arithmeticTheory intLib pairLib pairTheory PairRules combinTheory
     devTheory composeTheory compileTheory compile vsynth 
     dffTheory tempabsTheory;
val _ = intLib.deprecate_int();
quietdec := false;
*) 
 
(****************************************************************************** 
* Boilerplate needed for compilation 
******************************************************************************) 

(****************************************************************************** 
* Open theories 
******************************************************************************) 
open HolKernel Parse boolLib bossLib; 
open compile metisLib word32Theory word32Lib;
open arithmeticTheory intLib pairLib pairTheory PairRules combinTheory
     devTheory composeTheory compileTheory compile vsynth 
     dffTheory tempabsTheory;
 
(****************************************************************************** 
* Set default parsing to natural numbers rather than integers 
******************************************************************************) 
val _ = intLib.deprecate_int(); 
 
(*****************************************************************************) 
(* END BOILERPLATE                                                           *) 
(*****************************************************************************) 

(*****************************************************************************) 
(* Start new theory "Fact32"                                                 *) 
(*****************************************************************************) 
val _ = new_theory "Fact32"; 


val MultIter_def =
 Define
   `MultIter (m:num,n:num,acc:num) =
       if m = 0 then (0,n,acc) else MultIter(m-1,n,n + acc)`;

val MultIter_ind = fetch "-" "MultIter_ind";

(*****************************************************************************)
(* Create an implementation of a multiplier from MultIter                    *)
(*****************************************************************************)
val Mult_def =
 Define
  `Mult(m,n) = SND(SND(MultIter(m,n,0)))`;

(*****************************************************************************)
(* Verify that MultIter does compute multiplication                          *)
(*****************************************************************************)
val MultIterThm =                 (* proof adapted from similar one from KXS *)
 save_thm
  ("MultIterThm",
   prove
    (``!m n acc. MultIter (m,n,acc) = (0, n, (m * n) + acc)``,
     recInduct MultIter_ind THEN RW_TAC std_ss []
      THEN RW_TAC arith_ss [Once MultIter_def]
      THEN Cases_on `m` 
      THEN FULL_SIMP_TAC arith_ss [MULT]));

(*****************************************************************************)
(* Verify Mult is actually multiplication                                    *)
(*****************************************************************************)
val MultThm =
 store_thm
  ("MultThm",
   ``Mult = UNCURRY $*``,
   RW_TAC arith_ss [FUN_EQ_THM,FORALL_PROD,Mult_def,MultIterThm]);

val Mult32Iter_def = 
 Define
   `Mult32Iter (m,n,acc) =
       if m = 0w then (0w,n,acc) else Mult32Iter(m-1w,n,n + acc)`;

val Mult32Iter_ind = fetch "-" "Mult32Iter_ind";

(*****************************************************************************)
(* Create an implementation of a multiplier from Mult32Iter                  *)
(*****************************************************************************)
val Mult32_def =
 Define
  `Mult32(m,n) = SND(SND(Mult32Iter(m,n,0w)))`;

val MultIterAbs =
 store_thm
  ("MultIterAbs",
   ``!m n acc.
      n < 2 ** WL /\ (m * n) + acc < 2 ** WL
      ==> 
      (MultIter(m,n,acc) = 
       ((w2n ## w2n ## w2n) o Mult32Iter o (n2w ## n2w ## n2w))
        (m,n,acc))``,
    recInduct MultIter_ind THEN RW_TAC std_ss []
     THEN RW_TAC arith_ss [Once MultIter_def,Once Mult32Iter_def]
     THENL
      [CONV_TAC WORD_CONV,
       FULL_SIMP_TAC arith_ss [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def],
       FULL_SIMP_TAC arith_ss [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def],
       FULL_SIMP_TAC arith_ss 
        [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def,MultIterThm]
        THEN `w2n(n2w m) = 0` by PROVE_TAC[WORD_CONV ``w2n 0w``]
        THEN FULL_SIMP_TAC arith_ss [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def]
        THEN Cases_on `n = 0`
        THEN FULL_SIMP_TAC arith_ss []
        THEN `?p. n = p+1` by PROVE_TAC[COOPER_PROVE ``~(n = 0) ==> ?p. n = p+1``]
        THEN FULL_SIMP_TAC std_ss [LEFT_ADD_DISTRIB,MULT_CLAUSES]
        THEN `m < 4294967296` by DECIDE_TAC
        THEN IMP_RES_TAC LESS_MOD
        THEN DECIDE_TAC,
       FULL_SIMP_TAC arith_ss 
        [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def,MultIterThm,RIGHT_SUB_DISTRIB]
        THEN `?p. m = p+1` by PROVE_TAC[COOPER_PROVE ``~(n = 0) ==> ?p. n = p+1``]
        THEN FULL_SIMP_TAC std_ss [RIGHT_ADD_DISTRIB,MULT_CLAUSES]
        THEN `p * n + n - n + (acc + n) < 4294967296` by DECIDE_TAC
        THEN RES_TAC
        THEN RW_TAC arith_ss [GSYM ADD_EVAL,WORD_ADD_SUB]
        THEN RW_TAC arith_ss [ADD_EVAL]]);

val FUN_PAIR_REDUCE =
 store_thm
  ("FUN_PAIR_REDUCE",
   ``((n2w ## f) ((w2n ## g) p) = (FST p, f(g(SND p))))``,
   Cases_on `p`
    THEN RW_TAC std_ss [w2n_ELIM]);

val MultIterAbsCor =
 store_thm
  ("MultIterAbsCor",
   ``!m n acc.
      (m * n) + acc < 2 ** WL
      ==> 
      (Mult32Iter (n2w m, n2w n, n2w acc) = (0w, n2w n, (n2w m) * (n2w n) + (n2w acc)))``,
   RW_TAC std_ss []
    THEN IMP_RES_TAC MultIterAbs
    THEN FULL_SIMP_TAC std_ss [MultIterThm]
    THEN Cases_on `m=0`
    THENL
     [RW_TAC arith_ss [Once Mult32Iter_def,WORD_MULT_CLAUSES,WORD_ADD_CLAUSES],
      `?p. m = p+1` by PROVE_TAC[COOPER_PROVE ``~(n = 0) ==> ?p. n = p+1``]
       THEN FULL_SIMP_TAC std_ss [RIGHT_ADD_DISTRIB,MULT_CLAUSES]
        THEN `n < 2 ** WL` by DECIDE_TAC
        THEN RES_TAC
        THEN POP_ASSUM(ASSUME_TAC o GSYM o AP_TERM ``n2w ## n2w ## n2w``)
        THEN FULL_SIMP_TAC std_ss [FUN_PAIR_REDUCE, w2n_ELIM]
        THEN RW_TAC arith_ss 
              [GSYM MUL_EVAL, GSYM ADD_EVAL, w2n_ELIM,WORD_RIGHT_ADD_DISTRIB,WORD_MULT_CLAUSES]]);

val MultAbs =
 store_thm
  ("MultAbs",
   ``!m n.
      m * n < 2 ** WL
      ==> 
      (Mult(m,n) = w2n(Mult32(n2w m, n2w n)))``,
   RW_TAC arith_ss [Mult_def, Mult32_def,Once MultIterThm]
    THEN RW_TAC arith_ss [MultIterAbsCor,WORD_ADD_CLAUSES,MUL_EVAL,w2n_EVAL]
    THEN PROVE_TAC[MOD_WL_IDEM,LT_WL_def]);

val MultAbsCor1 =
 store_thm
  ("MultAbsCor1",
   ``!m n.
      m * n < 2 ** WL
      ==> 
      (m * n = w2n(Mult32(n2w m, n2w n)))``,
   RW_TAC arith_ss [SIMP_RULE std_ss [MultThm] MultAbs]);

val MultAbsCor2 =
 store_thm
  ("MultAbsCor2",
   ``!m n.
      m * n < 2 ** WL
      ==> 
      (Mult32(n2w m, n2w n) = n2w m * n2w n)``,
   PROVE_TAC[w2n_ELIM,MUL_EVAL,MultAbsCor1]);

val FactIter_def = 
 Define
   `FactIter (n,acc) =
       if n = 0 then (n,acc) else FactIter (n - 1,n * acc)`;

val FactIter_ind = fetch "-" "FactIter_ind";

(*****************************************************************************)
(* Lemma showing how FactIter computes factorial                             *)
(*****************************************************************************)
val FactIterThm =                                       (* proof from KXS *)
 save_thm
  ("FactIterThm",
   prove
    (``!n acc. FactIter (n,acc) = (0, acc * FACT n)``,
     recInduct FactIter_ind THEN RW_TAC arith_ss []
      THEN RW_TAC arith_ss [Once FactIter_def,FACT]
      THEN Cases_on `n` 
      THEN FULL_SIMP_TAC arith_ss [FACT]));

(*****************************************************************************)
(* Implement iterative function as a step to implementing factorial          *)
(*****************************************************************************)
val Fact32Iter_def = 
 Define
   `Fact32Iter (n,acc) =
       if n = 0w then (n,acc) else Fact32Iter(n-1w, Mult32(n,acc))`;

val FACT_0 =
 store_thm
  ("FACT_0",
   ``!n. 0 < FACT n``,
   Induct
    THEN RW_TAC arith_ss [FACT,ADD1,LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB]);

val FACT_LESS_EQ =
 store_thm
  ("FACT_LESS_EQ",
   ``!n. n <= FACT n``,
   Induct
    THEN RW_TAC arith_ss [FACT,ADD1,LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB]
    THEN `0 < FACT n` by PROVE_TAC[FACT_0]
    THEN `?p. FACT n = SUC p` by Cooper.COOPER_TAC
    THEN RW_TAC arith_ss [FACT,ADD1,LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB]);

val FACT_LESS =
 store_thm
  ("FACT_LESS",
   ``!n. (n = 0) \/ (n = 1) \/ (n = 2) \/ n < FACT n``,
   Induct
    THEN RW_TAC arith_ss [FACT,ADD1,LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB]
    THEN CONV_TAC EVAL
    THEN `0 < FACT n` by PROVE_TAC[FACT_0]
    THEN `?p. FACT n = SUC p` by Cooper.COOPER_TAC
    THEN RW_TAC arith_ss [FACT,ADD1,LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB]);

val MULT_LESS_LEMMA =
 store_thm
  ("MULT_LESS_LEMMA",
   ``!n. 0 < n ==>  m <= m * n``,
   Induct
    THEN RW_TAC arith_ss [MULT_CLAUSES]);

val FactIterAbs =
 store_thm
  ("FactIterAbs",
   ``!n acc.
      acc * FACT n < 2 ** WL
      ==> 
      (FactIter(n,acc) = 
       (w2n ## w2n)(Fact32Iter((n2w ## n2w)(n,acc))))``,
    recInduct FactIter_ind THEN RW_TAC std_ss []
     THEN RW_TAC arith_ss [Once FactIter_def,Once Fact32Iter_def]
     THEN FULL_SIMP_TAC arith_ss [FACT]
     THENL
      [CONV_TAC WORD_CONV,
       PROVE_TAC[MOD_WL_IDEM,LT_WL_def,w2n_EVAL],
       FULL_SIMP_TAC arith_ss 
        [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def,FactIterThm]
        THEN `w2n(n2w n) = 0` by PROVE_TAC[WORD_CONV ``w2n 0w``]
        THEN FULL_SIMP_TAC arith_ss [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def]
        THEN Cases_on `acc = 0`
        THEN FULL_SIMP_TAC arith_ss []
        THEN `?p. acc = p+1` by PROVE_TAC[COOPER_PROVE ``~(n = 0) ==> ?p. n = p+1``]
        THEN FULL_SIMP_TAC arith_ss [LEFT_ADD_DISTRIB,RIGHT_ADD_DISTRIB,MULT_CLAUSES]
        THEN Cases_on `n=1`
        THEN FULL_SIMP_TAC arith_ss []
        THEN ASSUME_TAC(EVAL ``2 MOD 4294967296``)        
        THEN `~(n = 2)` by PROVE_TAC[EVAL ``0 = 2``]
        THEN `n < FACT n` by PROVE_TAC[FACT_LESS]
        THEN `n < 4294967296` by DECIDE_TAC
        THEN PROVE_TAC[LESS_MOD],
       `n = SUC(n-1)` by DECIDE_TAC
        THEN `FACT n = n * FACT(n-1)` by PROVE_TAC[FACT]
        THEN `acc * n * FACT (n - 1) < 2 ** WL` by PROVE_TAC[MULT_SYM,MULT_ASSOC]
        THEN RW_TAC arith_ss []
        THEN `1 <= n` by DECIDE_TAC
        THEN `LT_WL 1` by PROVE_TAC[LT_WL_def, EVAL ``1 < 2 ** WL``]
        THEN RW_TAC arith_ss [GSYM WORD_SUB_LT_EQ]
        THEN `n * acc < 2 ** WL` 
              by PROVE_TAC
                  [FACT_0,MULT_LESS_LEMMA,MULT_SYM,
                   DECIDE``m:num <= n /\ n < p ==> m < p``]
        THEN ONCE_REWRITE_TAC [MULT_SYM]
        THEN RW_TAC arith_ss [MultAbsCor1,w2n_ELIM]]);

(*****************************************************************************)
(* Lemma showing how FactIter computes factorial                             *)
(*****************************************************************************)
val FactIterThm =                                       (* proof from KXS *)
 save_thm
  ("FactIterThm",
   prove
    (``!n acc. FactIter (n,acc) = (0, acc * FACT n)``,
     recInduct FactIter_ind THEN RW_TAC arith_ss []
      THEN RW_TAC arith_ss [Once FactIter_def,FACT]
      THEN Cases_on `n` 
      THEN FULL_SIMP_TAC arith_ss [FACT]));

val FactIterAbsCor =
 store_thm
  ("FactIterAbsCor",
   ``!m n acc.
      acc * FACT n < 2 ** WL
      ==>
      (Fact32Iter (n2w n, n2w acc) = (0w, n2w acc * n2w(FACT n)))``,
   RW_TAC std_ss []
    THEN IMP_RES_TAC FactIterAbs
    THEN POP_ASSUM(ASSUME_TAC o GSYM o AP_TERM ``n2w ## n2w``)
    THEN FULL_SIMP_TAC std_ss [FUN_PAIR_REDUCE, w2n_ELIM,FactIterThm,MUL_EVAL]);

(*****************************************************************************)
(* Implement a function Fact32 to compute SND(Fact32Iter (n,1))              *)
(*****************************************************************************)
val Fact32_def =
 Define
  `Fact32 n = SND(Fact32Iter (n,1w))`;

val FactAbs =
 store_thm
  ("FactAbs",
   ``!n. FACT n < 2 ** WL ==> (FACT n = w2n(Fact32(n2w n)))``,
   RW_TAC arith_ss [Fact32_def,Once Fact32Iter_def]
    THENL
     [CONV_TAC WORD_CONV
       THEN `w2n(n2w n) = 0` by PROVE_TAC[WORD_CONV ``w2n 0w``]
       THEN FULL_SIMP_TAC arith_ss [MULT,w2n_EVAL,MOD_WL_def,WL_def,HB_def,word_H_def]
       THEN `n < 4294967296` by PROVE_TAC[DECIDE ``m:num <= n /\ n < p ==> m < p``,FACT_LESS_EQ]
       THEN `n = 0` by PROVE_TAC[LESS_MOD]
       THEN RW_TAC arith_ss [FACT],
      `n < 2 ** WL` by PROVE_TAC[DECIDE ``m:num <= n /\ n < p ==> m < p``,FACT_LESS_EQ]
       THEN RW_TAC arith_ss [MultAbsCor2,MultAbsCor2,WORD_MULT_CLAUSES]
       THEN `LT_WL 1` by PROVE_TAC[LT_WL_def, EVAL ``1 < 2 ** WL``]
       THEN Cases_on `n=0`
       THEN FULL_SIMP_TAC arith_ss []
       THEN `1 <= n` by DECIDE_TAC
       THEN RW_TAC arith_ss [WORD_SUB_LT_EQ]
       THEN `SUC(n-1) = n` by DECIDE_TAC
       THEN `n * FACT(n-1) < 2 ** WL` by PROVE_TAC[FACT]
       THEN RW_TAC arith_ss [FactIterAbsCor,MUL_EVAL]
       THEN `n * FACT(n-1) = FACT n` by PROVE_TAC[FACT]
       THEN RW_TAC arith_ss [w2n_EVAL,MOD_WL_def]]);

(*
|- FACT 12 < 2 ** WL = T : thm 
|- FACT 13 < 2 ** WL = F : thm 
*)
val _ = export_theory();
