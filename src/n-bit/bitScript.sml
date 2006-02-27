(* ========================================================================= *)
(* FILE          : bitScript.sml                                             *)
(* DESCRIPTION   : Support for bitwise operations over the natural numbers.  *)
(* AUTHOR        : (c) Anthony Fox, University of Cambridge                  *)
(* DATE          : 2000-2005                                                 *)
(* ========================================================================= *)

(* interactive use:
  load "logrootTheory";
*)

open HolKernel Parse boolLib bossLib;
open Q simpLib numLib arithmeticTheory logrootTheory prim_recTheory;

val _ = new_theory "bit";

(* ------------------------------------------------------------------------- *)

fun Def s = curry Definition.new_definition s o Parse.Term;

val DIV2_def        = Def "DIV2_def"
                          `DIV2 n = n DIV 2`;

val TIMES_2EXP_def  = Def "TIMES_2EXP_def"
                          `TIMES_2EXP x n = n * 2 ** x`;

val DIV_2EXP_def    = Def "DIV_2EXP_def"
                          `DIV_2EXP x n = n DIV 2 ** x`;

val MOD_2EXP_def    = Def "MOD_2EXP_def"
                          `MOD_2EXP x n = n MOD 2 ** x`;

val DIVMOD_2EXP_def = Def "DIVMOD_2EXP_def"
                          `DIVMOD_2EXP x n = (n DIV 2 ** x,n MOD 2 ** x)`;

val SBIT_def        = Def "SBIT_def"
                          `SBIT b n = if b then 2 ** n else 0`;

val BITS_def        = Def "BITS_def"
                          `BITS h l n = MOD_2EXP (SUC h-l) (DIV_2EXP l n)`;

val BITV_def        = Def "BITV_def"
                          `BITV n b = BITS b b n`;

val BIT_def         = Def "BIT_def"
                          `BIT b n = (BITS b b n = 1)`;

val SLICE_def       = Def "SLICE_def"
                          `SLICE h l n = MOD_2EXP (SUC h) n - MOD_2EXP l n`;

val LSB_def         = Def "LSB_def"
                          `LSB = BIT 0`;

val BIT_REVERSE_def =
  Prim_rec.new_recursive_definition
  {name = "BIT_REVERSE_def",
   def = ``(BIT_REVERSE 0 x = 0)
        /\ (BIT_REVERSE (SUC n) x =
              (BIT_REVERSE n x) * 2 + SBIT (BIT n x) 0)``,
   rec_axiom = prim_recTheory.num_Axiom};

val BITWISE_def =
 Prim_rec.new_recursive_definition
  {name = "BITWISE_def",
   def = ``(BITWISE 0 op x y = 0)
        /\ (BITWISE (SUC n) op x y =
              BITWISE n op x y + SBIT (op (BIT n x) (BIT n y)) n)``,
   rec_axiom = prim_recTheory.num_Axiom};

val BIT_MODIFY_def =
 Prim_rec.new_recursive_definition
  {name = "BIT_MODIFY_def",
   def = ``(BIT_MODIFY 0 f x = 0)
        /\ (BIT_MODIFY (SUC n) f x =
              BIT_MODIFY n f x + SBIT (f n (BIT n x)) n)``,
   rec_axiom = prim_recTheory.num_Axiom};

val SIGN_EXTEND_def =
  Def "SIGN_EXTEND_def"
      `SIGN_EXTEND l h n =
         let m = n MOD 2 ** l in
         if BIT (l - 1) n then 2 ** h - 2 ** l + m else m`;

val LOG2_def = Def "LOG2_def" `LOG2 = LOG 2`;

val LOG2_UNIQUE = save_thm("LOG2_UNIQUE",
  (REWRITE_RULE [GSYM LOG2_def] o INST [`a` |-> `2`]) LOG_UNIQUE);

(* ------------------------------------------------------------------------- *)

infix \\ << >>

val op \\ = op THEN;
val op << = op THENL;
val op >> = op THEN1;

val LEFT_REWRITE_TAC =
  GEN_REWRITE_TAC (RATOR_CONV o DEPTH_CONV) empty_rewrites;

val POP_LAST_TAC = POP_ASSUM (K ALL_TAC);

(* ------------------------------------------------------------------------- *)

val DIVMOD_2EXP = save_thm("DIVMOD_2EXP",
  REWRITE_RULE [GSYM DIV_2EXP_def,GSYM MOD_2EXP_def] DIVMOD_2EXP_def);

val SUC_SUB = save_thm("SUC_SUB",SIMP_CONV arith_ss [ADD1] ``SUC a - a``);

(* |- !n r. r < n ==> ((n + r) DIV n = 1) *)
val DIV_MULT_1 = save_thm("DIV_MULT_1",
  (GEN_ALL o SIMP_RULE arith_ss [] o INST [`q` |-> `1`] o SPEC_ALL
           o CONV_RULE (ONCE_DEPTH_CONV RIGHT_IMP_FORALL_CONV)) DIV_MULT);

(* |- !m. ~(m = 0) ==> ?p. m = SUC p *)
val NOT_ZERO_ADD1 = save_thm("NOT_ZERO_ADD1",
  (GEN_ALL o REWRITE_RULE [GSYM NOT_ZERO_LT_ZERO,GSYM ADD1,ADD] o
   SPECL [`m`,`0`]) LESS_ADD_1);

val ZERO_LT_TWOEXP = save_thm("ZERO_LT_TWOEXP",
  GEN_ALL (REDUCE_RULE (SPECL [`n`,`1`] ZERO_LESS_EXP)));

val TWOEXP_NOT_ZERO = save_thm("TWOEXP_NOT_ZERO",
  REWRITE_RULE [GSYM NOT_ZERO_LT_ZERO] ZERO_LT_TWOEXP);

val th = (SPEC_ALL o REWRITE_RULE [ZERO_LT_TWOEXP] o SPEC `2 ** n`) DIVISION;

(* |- !n k. k MOD 2 ** n < 2 ** n *)
val MOD_2EXP_LT = save_thm("MOD_2EXP_LT", (GEN_ALL o CONJUNCT2) th);

(* |- !n k. k = k DIV 2 ** n * 2 ** n + k MOD 2 ** n *)
val TWOEXP_DIVISION = save_thm("TWOEXP_DIVISION", (GEN_ALL o CONJUNCT1) th);

local
  val sp2 = GEN `a` o GEN `b` o fst o EQ_IMP_RULE o
            SPEC_ALL o SIMP_RULE std_ss [] o SPEC `2`
in
  val TWOEXP_MONO  = save_thm("TWOEXP_MONO",  sp2 LT_EXP_ISO)
  val TWOEXP_MONO2 = save_thm("TWOEXP_MONO2", sp2 LE_EXP_ISO)
end;

val EXP_SUB_LESS_EQ = store_thm("EXP_SUB_LESS_EQ",
  `!a b. 2 ** (a - b) <= 2 ** a`,
  RW_TAC bool_ss [SUB_LESS_EQ,TWOEXP_MONO2]);

(* ------------------------------------------------------------------------- *)

val BITS_THM = save_thm("BITS_THM",
  REWRITE_RULE [DIV_2EXP_def,MOD_2EXP_def] BITS_def);

val BITSLT_THM = store_thm("BITSLT_THM",
  `!h l n. BITS h l n < 2 ** (SUC h-l)`,
  RW_TAC bool_ss [BITS_THM,ZERO_LT_TWOEXP,DIVISION]);

val DIV_MULT_LEM = prove(
  `!m n. 0 < n ==> m DIV n * n <= m`,
  RW_TAC std_ss [LESS_EQ_EXISTS] \\ EXISTS_TAC `m MOD n`
    \\ RW_TAC std_ss [GSYM DIVISION]);

(* |- !x n. n DIV 2 ** x * 2 ** x <= n *)
val DIV_MULT_LESS_EQ = GEN_ALL (SIMP_RULE bool_ss [ZERO_LT_TWOEXP]
  (SPECL [`n`,`2 ** x`] DIV_MULT_LEM));

val MOD_2EXP_LEM = prove(
  `!n x. n MOD 2 ** x = n - n DIV 2 ** x * 2 ** x`,
  RW_TAC arith_ss [DIV_MULT_LESS_EQ,GSYM ADD_EQ_SUB,
    ZERO_LT_TWOEXP,GSYM DIVISION]);

val DIV_MULT_LEM2 = prove(
  `!a b p. a DIV 2 ** (b + p) * 2 ** (p + b) <= a DIV 2 ** b * 2 ** b`,
  RW_TAC bool_ss [SPECL [`a DIV 2 ** b`,`2 ** p`] DIV_MULT_LEM,
    EXP_ADD,MULT_ASSOC,GSYM DIV_DIV_DIV_MULT,ZERO_LT_TWOEXP,LESS_MONO_MULT]);

val MOD_EXP_ADD = prove(
  `!a b p. a MOD 2 ** (b + p) =
      a MOD 2 ** b + (a DIV 2 ** b) MOD 2 ** p * 2 ** b`,
  REPEAT STRIP_TAC
    \\ SIMP_TAC bool_ss [MOD_2EXP_LEM,RIGHT_SUB_DISTRIB,DIV_DIV_DIV_MULT,
         ZERO_LT_TWOEXP,GSYM MULT_ASSOC,GSYM EXP_ADD]
    \\ ASSUME_TAC ( (GSYM o SPECL [`a DIV 2 ** (b + p) * 2 ** (p + b)`,
         `a DIV 2 ** b * 2 ** b`]) LESS_EQ_ADD_SUB)
    \\ ASM_SIMP_TAC arith_ss [DIV_MULT_LEM2,DIV_MULT_LEM,
         ZERO_LT_TWOEXP,SUB_ADD]);

val DIV_MOD_MOD_DIV2 = (SIMP_RULE std_ss [ZERO_LT_TWOEXP,GSYM EXP_ADD] o
  SPECL [`a`,`2 ** b`,`2 ** p`]) DIV_MOD_MOD_DIV;

val DIV_MOD_MOD_DIV3 = prove(
  `!a b c. (a DIV 2 ** b) MOD 2 ** (c - b) = (a MOD 2 ** c) DIV 2 ** b`,
  REPEAT STRIP_TAC \\ Cases_on `c <= b`
    << [
      POP_ASSUM (fn th =>
             REWRITE_TAC [REWRITE_RULE [GSYM SUB_EQ_0] th,EXP,MOD_1]
               \\ ASSUME_TAC (MATCH_MP TWOEXP_MONO2 th))
        \\ ASSUME_TAC (SPECL [`c`,`a`] MOD_2EXP_LT)
        \\ IMP_RES_TAC LESS_LESS_EQ_TRANS
        \\ ASM_SIMP_TAC bool_ss [LESS_DIV_EQ_ZERO],
      RULE_ASSUM_TAC (REWRITE_RULE [NOT_LESS_EQUAL])
        \\ IMP_RES_TAC LESS_ADD
        \\ POP_ASSUM (fn th => SIMP_TAC arith_ss [SYM th,DIV_MOD_MOD_DIV2])]);

val BITS_THM2 = store_thm("BITS_THM2",
  `!h l n. BITS h l n = (n MOD 2 ** SUC h) DIV 2 ** l`,
  RW_TAC bool_ss [BITS_THM,DIV_MOD_MOD_DIV3]);

val BITS_COMP_LEM = prove(
  `!h1 l1 h2 l2 n. h2 + l1 <= h1 ==>
    (((n DIV 2 ** l1) MOD 2 ** (h1 - l1) DIV 2 ** l2) MOD 2 ** (h2 - l2) =
      (n DIV 2 ** (l2 + l1)) MOD 2 ** ((h2 + l1) - (l2 + l1)))`,
  REPEAT STRIP_TAC
    \\ REWRITE_TAC [SPECL [`(n DIV 2 ** l1) MOD 2 ** (h1 - l1)`,
         `l2`,`h2`] DIV_MOD_MOD_DIV3]
    \\ IMP_RES_TAC LESS_EQUAL_ADD
    \\ POP_ASSUM (fn th => SIMP_TAC arith_ss
         [EXP_ADD,MOD_MULT_MOD,ZERO_LT_TWOEXP,th])
    \\ REWRITE_TAC [DIV_MOD_MOD_DIV2]
    \\ SIMP_TAC arith_ss [DIV_DIV_DIV_MULT,ZERO_LT_TWOEXP,GSYM EXP_ADD]
    \\ REWRITE_TAC [SIMP_RULE arith_ss []
         (SPECL [`n`,`l1 + l2`,`h2 + l1`] DIV_MOD_MOD_DIV3)]);

val BITS_COMP_THM = store_thm("BITS_COMP_THM",
  `!h1 l1 h2 l2 n. h2 + l1 <= h1 ==>
     (BITS h2 l2 (BITS h1 l1 n) = BITS (h2+l1) (l2+l1) n)`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC LESS_EQ_MONO
    \\ FULL_SIMP_TAC bool_ss [BITS_THM,GSYM ADD_CLAUSES,BITS_COMP_LEM]);

val BITS_DIV_THM = store_thm("BITS_DIV_THM",
  `!h l x n. (BITS h l x) DIV 2 ** n = BITS h (l + n) x`,
  RW_TAC bool_ss [BITS_THM2,EXP_ADD,ZERO_LT_TWOEXP,DIV_DIV_DIV_MULT]);

val BITS_LT_HIGH = store_thm("BITS_LT_HIGH",
  `!h l n. n < 2 ** SUC h ==> (BITS h l n = n DIV 2 ** l)`,
  RW_TAC bool_ss [BITS_THM2,LESS_MOD]);

(* ------------------------------------------------------------------------- *)

val BITS_ZERO = store_thm("BITS_ZERO",
  `!h l n. h < l ==> (BITS h l n = 0)`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC LESS_ADD_1
    \\ POP_ASSUM (fn th => REWRITE_TAC [th])
    \\ ASSUME_TAC ((REWRITE_RULE [EXP,SUB,SUB_EQUAL_0] o
         ONCE_REWRITE_RULE [SUB_PLUS] o REWRITE_RULE [ADD1] o
         SPECL [`h`,`h + 1 + p`,`n`]) BITSLT_THM)
    \\ FULL_SIMP_TAC arith_ss []);

val BITS_ZERO2 = store_thm("BITS_ZERO2",
  `!h l. BITS h l 0 = 0`,
  RW_TAC bool_ss [BITS_THM2,ZERO_MOD,ZERO_DIV,ZERO_LT_TWOEXP]);

(* |- !h n. BITS h 0 n = n MOD 2 ** SUC h *)
val BITS_ZERO3 = save_thm("BITS_ZERO3",
  (GEN_ALL o SIMP_RULE bool_ss [CONJUNCT1 EXP,DIV_1] o
   SPECL [`h`,`0`]) BITS_THM2);

val BITS_ZERO4 = store_thm("BITS_ZERO4",
  `!h l n. l <= h ==> (BITS h l (a * 2 ** l) = BITS (h - l) 0 a)`,
  RW_TAC arith_ss [BITS_THM,MULT_DIV,ZERO_LT_TWOEXP,SUB]);

val BITS_ZEROL = store_thm("BITS_ZEROL",
  `!h a. a < 2 ** SUC h ==> (BITS h 0 a = a)`,
  RW_TAC bool_ss [BITS_ZERO3,LESS_MOD]);

val BIT_ZERO = store_thm("BIT_ZERO",
  `!b. ~BIT b 0`, REWRITE_TAC [BIT_def,BITS_ZERO2,DECIDE ``~(0 = 1)``]);

val BIT_B = store_thm("BIT_B",
  `!b. BIT b (2 ** b)`,
  SIMP_TAC arith_ss [BIT_def,BITS_THM,DIVMOD_ID,ZERO_LT_TWOEXP,SUC_SUB]);

val BIT_B_NEQ = store_thm("BIT_B_NEQ",
  `!a b. ~(a = b) ==> ~BIT a (2 ** b)`,
  NTAC 3 STRIP_TAC
    \\ REWRITE_TAC [BIT_def,BITS_THM,SUC_SUB,EXP_1]
    \\ IMP_RES_TAC (DECIDE ``!(a:num) b. ~(a = b) ==> (a < b) \/ (b < a)``)
    << [
      IMP_RES_TAC LESS_ADD_1
        \\ ASM_SIMP_TAC std_ss [ONCE_REWRITE_RULE [MULT_COMM] MULT_DIV,
             EXP_ADD,MOD_EQ_0,ZERO_LT_TWOEXP],
      IMP_RES_TAC TWOEXP_MONO \\ ASM_SIMP_TAC std_ss [LESS_DIV_EQ_ZERO]]);

(* ------------------------------------------------------------------------- *)

val BITS_COMP_THM2 = store_thm("BITS_COMP_THM2",
  `!h1 l1 h2 l2 n. BITS h2 l2 (BITS h1 l1 n) =
      BITS (MIN h1 (h2 + l1)) (l2 + l1) n`,
  RW_TAC bool_ss [MIN_DEF,REWRITE_RULE [GSYM NOT_LESS] BITS_COMP_THM]
    \\ Cases_on `h2 = 0` >> FULL_SIMP_TAC arith_ss [BITS_ZERO,BITS_ZERO2]
    \\ RULE_ASSUM_TAC (REWRITE_RULE [NOT_ZERO_LT_ZERO])
    \\ Cases_on `h1 < l1` >> FULL_SIMP_TAC arith_ss [BITS_ZERO,BITS_ZERO2]
    \\ RULE_ASSUM_TAC (ONCE_REWRITE_RULE [ADD_COMM])
    \\ IMP_RES_TAC SUB_RIGHT_LESS
    \\ POP_ASSUM (fn th => ASSUME_TAC
           (MATCH_MP TWOEXP_MONO (ONCE_REWRITE_RULE [GSYM LESS_MONO_EQ] th)))
    \\ ASSUME_TAC (SPECL [`h1`,`l1`,`n`] BITSLT_THM)
    \\ Cases_on `h1 = l1`
    << [
      FULL_SIMP_TAC arith_ss [SYM ONE,SUC_SUB]
        \\ `BITS h1 l1 n < 2 ** SUC h2` by IMP_RES_TAC LESS_TRANS
        \\ ASM_SIMP_TAC arith_ss [BITS_LT_HIGH,BITS_DIV_THM],
      `~(h1 <= l1)` by DECIDE_TAC
        \\ POP_ASSUM (fn th => RULE_ASSUM_TAC
               (SIMP_RULE bool_ss [th,SUB_LEFT_SUC]))
        \\ `BITS h1 l1 n < 2 ** SUC h2` by IMP_RES_TAC LESS_TRANS
        \\ ASM_SIMP_TAC arith_ss [BITS_LT_HIGH,BITS_DIV_THM]]);

(* ------------------------------------------------------------------------- *)

val NOT_MOD2_LEM = store_thm("NOT_MOD2_LEM",
  `!n. ~(n MOD 2 = 0) = (n MOD 2 = 1)`, RW_TAC arith_ss [MOD_2]);

val NOT_MOD2_LEM2 = store_thm("NOT_MOD2_LEM2",
  `!n a. ~(n MOD 2 = 1) = (n MOD 2 = 0)`, RW_TAC bool_ss [GSYM NOT_MOD2_LEM]);

val ODD_MOD2_LEM = store_thm("ODD_MOD2_LEM",
 `!n. ODD n = ((n MOD 2) = 1)`, RW_TAC arith_ss [ODD_EVEN,MOD_2]);

val BIT_OF_BITS_THM = Q.store_thm (
"BIT_OF_BITS_THM",
`!n h l a. l + n <= h ==> (BIT n (BITS h l a) = BIT (l + n) a)`,
RW_TAC arith_ss [BIT_def, BITS_COMP_THM]);

val BIT_SHIFT_THM = Q.store_thm (
"BIT_SHIFT_THM",
`!n a s. BIT (n + s) (a * 2 ** s) = BIT n a`,
RW_TAC std_ss [BIT_def, BITS_def,MOD_2EXP_def, DIV_2EXP_def] \\
RW_TAC arith_ss [SUC_SUB, EXP_ADD] \\
metisLib.METIS_TAC [GSYM DIV_DIV_DIV_MULT, ZERO_LT_TWOEXP,
                    MULT_DIV, MULT_SYM]);

val BIT_SHIFT_THM2 = Q.store_thm (
"BIT_SHIFT_THM2",
`!n a s. s <= n ==> (BIT n (a * 2 ** s) = BIT (n - s) a)`,
RW_TAC arith_ss [GSYM (Q.SPECL [`n-s`, `a`, `s`] BIT_SHIFT_THM)]);

val BIT_SHIFT_THM3 = Q.store_thm (
"BIT_SHIFT_THM3",
`!n a s. (n < s) ==> ~BIT n (a * 2 ** s)`,
RW_TAC std_ss [BIT_def, BITS_def,MOD_2EXP_def, DIV_2EXP_def] \\
RW_TAC arith_ss [SUC_SUB, NOT_MOD2_LEM2, GSYM EVEN_MOD2] \\
RW_TAC arith_ss [DIV_P, ZERO_LT_TWOEXP] \\
Q.EXISTS_TAC `a * 2 ** (s - n)` \\ Q.EXISTS_TAC `0` \\
RW_TAC std_ss [ZERO_LT_TWOEXP,GSYM MULT_ASSOC, GSYM EXP_ADD, EVEN_MULT] \\
ASM_SIMP_TAC arith_ss [EVEN_EXP])

val BIT_OF_BITS_THM2 = store_thm("BIT_OF_BITS_THM2",
  `!h l x n.  h < l + x ==> ~BIT x (BITS h l n)`,
  RW_TAC arith_ss [MIN_DEF,BIT_def,BITS_COMP_THM2,BITS_ZERO]);

(* ------------------------------------------------------------------------- *)

val DIV_MULT_THM = store_thm("DIV_MULT_THM",
  `!x n. n DIV 2 ** x * 2 ** x = n - n MOD 2 ** x`,
  RW_TAC arith_ss [DIV_MULT_LESS_EQ,MOD_2EXP_LEM,SUB_SUB]);

val DIV_MULT_THM2 = save_thm("DIV_MULT_THM2",
  ONCE_REWRITE_RULE [MULT_COMM]
    (REWRITE_RULE [EXP_1] (SPEC `1` DIV_MULT_THM)));

val LESS_EQ_EXP_MULT = store_thm("LESS_EQ_EXP_MULT",
  `!a b. a <= b ==> ?p. 2 ** b = p * 2 ** a`,
  REPEAT STRIP_TAC
    \\ IMP_RES_TAC LESS_EQUAL_ADD
    \\ RULE_ASSUM_TAC (ONCE_REWRITE_RULE [SIMP_RULE arith_ss []
         (SPEC `2` (GSYM EXP_INJECTIVE))])
    \\ EXISTS_TAC `2 ** p`
    \\ FULL_SIMP_TAC arith_ss [EXP_ADD,MULT_COMM]);

val LESS_EXP_MULT = SIMP_PROVE bool_ss [LESS_IMP_LESS_OR_EQ,LESS_EQ_EXP_MULT]
  ``!a b. a < b ==> ?p. 2 ** b = p * 2 ** a``;

(* ------------------------------------------------------------------------- *)

val SLICE_LEM1 = prove(
  `!a x y. a DIV 2 ** (x + y) * 2 ** (x + y) =
       a DIV 2 ** x * 2 ** x - (a DIV 2 ** x) MOD 2 ** y * 2 ** x`,
  REPEAT STRIP_TAC
    \\ REWRITE_TAC [EXP_ADD]
    \\ SUBST_OCCS_TAC [([2],SPECL [`2 ** x`,`2 ** y`] MULT_COMM)]
    \\ SIMP_TAC bool_ss [ZERO_LT_TWOEXP,GSYM DIV_DIV_DIV_MULT,MULT_ASSOC,
         SPECL [`y`,`a DIV 2 ** x`] DIV_MULT_THM,RIGHT_SUB_DISTRIB]);

val SLICE_LEM2 = prove(
  `!a x y. n MOD 2 ** (x + y) =
           n MOD 2 ** x + (n DIV 2 ** x) MOD 2 ** y * 2 ** x`,
  REPEAT STRIP_TAC
    \\ SIMP_TAC bool_ss [DIV_MULT_LESS_EQ,MOD_2EXP_LEM,SLICE_LEM1,
         RIGHT_SUB_DISTRIB,SUB_SUB,SUB_LESS_EQ]
    \\ Cases_on `n = n DIV 2 ** x * 2 ** x`
    >> POP_ASSUM (fn th => SIMP_TAC arith_ss [SYM th])
    \\ ASSUME_TAC (REWRITE_RULE [GSYM NOT_LESS] DIV_MULT_LESS_EQ)
    \\ IMP_RES_TAC LESS_CASES_IMP
    \\ RW_TAC bool_ss [SUB_RIGHT_ADD]
    \\ PROVE_TAC [GSYM NOT_LESS_EQUAL]);

val SLICE_LEM3 = prove(
  `!n h l. l < h ==> n MOD 2 ** SUC l <= n MOD 2 ** h`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC LESS_ADD_1
    \\ POP_ASSUM (fn th => REWRITE_TAC [th])
    \\ REWRITE_TAC [GSYM ADD1,GSYM ADD_SUC,GSYM (CONJUNCT2 ADD)]
    \\ SIMP_TAC arith_ss [SLICE_LEM2]);

val SLICE_THM = store_thm("SLICE_THM",
  `!n h l. SLICE h l n = BITS h l n * 2 ** l`,
  REPEAT STRIP_TAC
    \\ REWRITE_TAC [SLICE_def,BITS_def,MOD_2EXP_def,DIV_2EXP_def]
    \\ Cases_on `h < l`
    << [
      IMP_RES_TAC SLICE_LEM3
        \\ POP_ASSUM (fn th => ASSUME_TAC (SPEC `n` th))
        \\ IMP_RES_TAC LESS_OR
        \\ IMP_RES_TAC SUB_EQ_0
        \\ ASM_SIMP_TAC arith_ss [EXP,MOD_1,MULT_CLAUSES],
      REWRITE_TAC [DIV_MOD_MOD_DIV3]
        \\ RULE_ASSUM_TAC (REWRITE_RULE [NOT_LESS])
        \\ SUBST_OCCS_TAC
             [([1],SPECL [`l`,`n MOD 2 ** SUC h`] TWOEXP_DIVISION)]
        \\ IMP_RES_TAC LESS_EQUAL_ADD
        \\ POP_ASSUM (fn th => SUBST_OCCS_TAC [([2],th)])
        \\ SIMP_TAC bool_ss [ADD_SUC,ADD_SUB,MOD_MULT_MOD,
             ZERO_LT_TWOEXP,EXP_ADD]]);

val SLICELT_THM = store_thm("SLICELT_THM",
  `!h l n. SLICE h l n < 2 ** SUC h`,
  REPEAT STRIP_TAC \\ ASSUME_TAC (SPECL [`SUC h`,`n`] MOD_2EXP_LT)
    \\ RW_TAC arith_ss [SLICE_def,MOD_2EXP_def,ZERO_LT_TWOEXP,SUB_RIGHT_LESS]);

val BITS_SLICE_THM = store_thm("BITS_SLICE_THM",
  `!h l n. BITS h l (SLICE h l n) = BITS h l n`,
  RW_TAC bool_ss [SLICELT_THM,BITS_LT_HIGH,ZERO_LT_TWOEXP,SLICE_THM,MULT_DIV]);

val BITS_SLICE_THM2 = store_thm("BITS_SLICE_THM2",
  `!h l n. h <= h2 ==> (BITS h2 l (SLICE h l n) = BITS h l n)`,
  REPEAT STRIP_TAC \\ LEFT_REWRITE_TAC [BITS_THM]
    \\ SIMP_TAC bool_ss [SLICE_THM,ZERO_LT_TWOEXP,MULT_DIV]
    \\ `SUC h - l <= SUC h2 - l` by DECIDE_TAC
    \\ IMP_RES_TAC TWOEXP_MONO2 \\ POP_LAST_TAC
    \\ ASSUME_TAC (SPECL [`h`,`l`,`n`] BITSLT_THM)
    \\ IMP_RES_TAC LESS_LESS_EQ_TRANS
    \\ ASM_SIMP_TAC bool_ss [LESS_MOD]);

val SLICE_ZERO_THM = save_thm("SLICE_ZERO_THM",
  (GEN_ALL o REWRITE_RULE [MULT_RIGHT_1,EXP] o
   SPECL [`n`,`h`,`0`]) SLICE_THM);

val MOD_2EXP_MONO = store_thm("MOD_2EXP_MONO",
  `!n h l. l <= h ==> n MOD 2 ** l <= n MOD 2 ** SUC h`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC LESS_EQ_EXISTS
    \\ ASM_SIMP_TAC arith_ss [SUC_ADD_SYM,SLICE_LEM2]);

val SLICE_COMP_THM = store_thm("SLICE_COMP_THM",
  `!h m l n. (SUC m) <= h /\ l <= m ==>
      (SLICE h (SUC m) n + SLICE m l n = SLICE h l n)`,
  RW_TAC bool_ss [SLICE_def,MOD_2EXP_def,MOD_2EXP_MONO,
    GSYM LESS_EQ_ADD_SUB,SUB_ADD]);

val SLICE_COMP_RWT = store_thm("SLICE_COMP_RWT",
  `!h m' m l n. l <= m /\ (m' = m + 1) /\ m < h ==>
             (SLICE h m' n + SLICE m l n = SLICE h l n)`,
  RW_TAC arith_ss [SLICE_COMP_THM,GSYM ADD1]);

val SLICE_ZERO = store_thm("SLICE_ZERO",
  `!h l n. h < l ==> (SLICE h l n = 0)`,
  RW_TAC arith_ss [SLICE_THM,BITS_ZERO]);

(* ------------------------------------------------------------------------- *)

val BITS_SUM = store_thm("BITS_SUM",
  `!h l a b. b < 2 ** l ==>
     (BITS h l (a * 2 ** l + b) = BITS h l (a * 2 ** l))`,
  RW_TAC bool_ss [BITS_THM,DIV_MULT,MULT_DIV,ZERO_LT_TWOEXP]);

val BITS_SUM2 = store_thm("BITS_SUM2",
  `!h l a b. BITS h l (a * 2 ** SUC h + b) = BITS h l b`,
  RW_TAC bool_ss [BITS_THM2,MOD_TIMES,ZERO_LT_TWOEXP]);

val SLICE_TWOEXP = prove(
  `!h l a n. SLICE (h + n) (l + n) (a * 2 ** n) = (SLICE h l a) * 2 ** n`,
  REPEAT STRIP_TAC
    \\ SUBST1_TAC (SPECL [`l`,`n`] ADD_COMM)
    \\ RW_TAC bool_ss [(GSYM o CONJUNCT2) ADD,SLICE_THM,BITS_THM,
         MULT_DIV,EXP_ADD,GSYM DIV_DIV_DIV_MULT,ZERO_LT_TWOEXP]
    \\ SIMP_TAC arith_ss []);

val SPEC_SLICE_TWOEXP =
  (GEN_ALL o SIMP_RULE arith_ss [] o DISCH `n <= l /\ n <= h` o
   SPECL [`h - n`,`l - n`,`a`,`n`]) SLICE_TWOEXP;

val SLICE_COMP_THM2 = store_thm("SLICE_COMP_THM2",
  `!h l x y n.
      h <= x /\ y <= l ==>
        (SLICE h l (SLICE x y n) = SLICE h l n)`,
  REPEAT STRIP_TAC
    \\ Cases_on `h < l` >> ASM_SIMP_TAC bool_ss [SLICE_ZERO]
    \\ `y <= h` by DECIDE_TAC
    \\ SUBST1_TAC (SPECL [`n`,`x`,`y`] SLICE_THM)
    \\ ASM_SIMP_TAC bool_ss [SPEC_SLICE_TWOEXP]
    \\ ASM_SIMP_TAC arith_ss [ONCE_REWRITE_RULE [MULT_COMM] SLICE_THM,
         BITS_COMP_THM2,MIN_DEF]
    \\ ASM_SIMP_TAC arith_ss [GSYM EXP_ADD]);

(* ------------------------------------------------------------------------- *)

val lem  = prove(`!c a b. (a = b) ==> (a DIV c = b DIV c)`, RW_TAC arith_ss []);
val lem2 = prove(`!a b c. a * (b * c) = a * c * b`, SIMP_TAC arith_ss []);

val lem3 = prove(
  `!a m n. n <= m ==> (a * 2 ** m DIV 2 ** n = a * 2 ** (m - n))`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC LESS_EQUAL_ADD
    \\ ASM_SIMP_TAC std_ss [EXP_ADD,MULT_DIV,ZERO_LT_TWOEXP,lem2]);

(* |- !a m n. n < m ==> (a * 2 ** m DIV 2 ** n = a * 2 ** (m - n)) *)
val lem4 = SIMP_PROVE std_ss [LESS_IMP_LESS_OR_EQ,lem3]
  ``!a m n. n < m ==> (a * 2 ** m DIV 2 ** n = a * 2 ** (m - n))``;

val BIT_COMP_THM3 = store_thm("BIT_COMP_THM3",
  `!h m l n.  SUC m <= h /\ l <= m ==>
         (BITS h (SUC m) n * 2 ** (SUC m - l) + BITS m l n = BITS h l n)`,
  REPEAT STRIP_TAC
    \\ IMP_RES_TAC (REWRITE_RULE [SLICE_THM] SLICE_COMP_THM)
    \\ POP_LAST_TAC
    \\ POP_ASSUM (fn th => ASSUME_TAC (GEN `l'`
         (MATCH_MP (SPEC `2 ** l` lem) (SPEC `n` th))))
    \\ POP_ASSUM (fn th => ASSUME_TAC
         (ONCE_REWRITE_RULE [ADD_COMM] (SPEC `l` th)))
    \\ `l < SUC m` by ASM_SIMP_TAC arith_ss []
    \\ FULL_SIMP_TAC arith_ss [lem4,ADD_DIV_ADD_DIV,MULT_DIV,ZERO_LT_TWOEXP]);

(* ------------------------------------------------------------------------- *)

val NOT_BIT = store_thm("NOT_BIT",
  `!n a. ~BIT n a = (BITS n n a = 0)`,
  RW_TAC bool_ss [BIT_def,BITS_THM,SUC_SUB,EXP_1,GSYM NOT_MOD2_LEM]);

val NOT_BITS = store_thm("NOT_BITS",
  `!n a. ~(BITS n n a = 0) = (BITS n n a = 1)`,
  RW_TAC bool_ss [GSYM NOT_BIT,GSYM BIT_def]);

val NOT_BITS2 = store_thm("NOT_BITS2",
  `!n a. ~(BITS n n a = 1) = (BITS n n a = 0)`,
  RW_TAC bool_ss [GSYM NOT_BITS]);

val BIT_SLICE = store_thm("BIT_SLICE",
  `!n a b. (BIT n a = BIT n b) = (SLICE n n a = SLICE n n b)`,
  REPEAT STRIP_TAC \\ EQ_TAC
    >> (Cases_on `BIT n a` \\
        FULL_SIMP_TAC arith_ss [BIT_def,SLICE_THM,NOT_BITS2])
    \\ Cases_on `BITS n n a = 1` \\ Cases_on `BITS n n b = 1`
    \\ FULL_SIMP_TAC arith_ss [BIT_def,SLICE_THM,NOT_BITS2,MULT_CLAUSES,
         REWRITE_RULE [GSYM NOT_ZERO_LT_ZERO] ZERO_LT_TWOEXP]);

val BIT_SLICE_LEM = store_thm("BIT_SLICE_LEM",
  `!y x n. SBIT (BIT x n) (x + y) = (SLICE x x n) * 2 ** y`,
  RW_TAC arith_ss [SBIT_def,BIT_SLICE,SLICE_THM,BIT_def,EXP_ADD]
    \\ FULL_SIMP_TAC bool_ss [GSYM NOT_BITS]);

(* |- !x n. SBIT (BIT x n) x = SLICE x x n *)
val BIT_SLICE_THM = save_thm("BIT_SLICE_THM",
   SIMP_RULE arith_ss [EXP] (SPEC `0` BIT_SLICE_LEM));

val BIT_SLICE_THM2 = store_thm("BIT_SLICE_THM2",
  `!b n. BIT b n = (SLICE b b n = 2 ** b)`,
  RW_TAC bool_ss [SBIT_def,GSYM BIT_SLICE_THM,TWOEXP_NOT_ZERO]);

val BIT_SLICE_THM3 = store_thm("BIT_SLICE_THM3",
  `!b n. ~BIT b n = (SLICE b b n = 0)`,
  RW_TAC bool_ss [SBIT_def,GSYM BIT_SLICE_THM,TWOEXP_NOT_ZERO]);

val BIT_SLICE_THM4 = store_thm("BIT_SLICE_THM4",
  `!b h l n. BIT b (SLICE h l n) = l <= b /\ b <= h /\ BIT b n`,
  REPEAT STRIP_TAC \\ Cases_on `l <= b /\ b <= h`
    \\ RW_TAC arith_ss [BIT_SLICE_THM2,SLICE_COMP_THM2]
    \\ REWRITE_TAC [GSYM BIT_SLICE_THM2]
    \\ FULL_SIMP_TAC arith_ss [SLICE_THM,BIT_def,NOT_LESS_EQUAL,
         SPECL [`b`,`b`] BITS_THM,SUC_SUB,NOT_MOD2_LEM2]
    << [
      IMP_RES_TAC LESS_ADD_1
        \\ ASM_SIMP_TAC arith_ss [ONCE_REWRITE_RULE [ADD_COMM] EXP_ADD]
        \\ SIMP_TAC std_ss [MULT_DIV,ZERO_LT_TWOEXP,
             DECIDE ``a * (b * c) = (a * c) * b``]
        \\ METIS_TAC [MOD_EQ_0,DECIDE ``0 < 2``,MULT_ASSOC,MULT_COMM],
      `SUC h <= b` by DECIDE_TAC
        \\ `2 ** l * BITS h l n < 2 ** b` by METIS_TAC [TWOEXP_MONO2,
             GSYM SLICE_THM,SLICELT_THM,LESS_LESS_EQ_TRANS,MULT_COMM]
        \\ ASM_SIMP_TAC std_ss [LESS_DIV_EQ_ZERO]]);

val SUB_BITS = prove(
  `!h l a b. (BITS (SUC h) l a = BITS (SUC h) l b) ==>
      (BITS h l a = BITS h l b)`,
  REPEAT STRIP_TAC
    \\ Cases_on `h < l` >> RW_TAC bool_ss [BITS_ZERO]
    \\ RULE_ASSUM_TAC (REWRITE_RULE [NOT_LESS])
    \\ POP_ASSUM (fn th => ONCE_REWRITE_TAC
         [(GSYM o SIMP_RULE arith_ss [th,SUB_ADD] o
           SPECL [`SUC h`,`l`,`h - l`,`0`]) BITS_COMP_THM])
    \\ ASM_REWRITE_TAC []);

val SBIT_DIV = store_thm("SBIT_DIV",
  `!b m n. n < m ==> (SBIT b (m - n) = SBIT b m DIV 2 ** n)`,
  RW_TAC bool_ss [SBIT_def,ZERO_DIV,ZERO_LT_TWOEXP,
    SIMP_RULE arith_ss [] (SPEC `1` lem4)]);

val BITS_SUC = store_thm("BITS_SUC",
  `!h l n.  l <= SUC h ==>
     (SBIT (BIT (SUC h) n) (SUC h - l) + BITS h l n = BITS (SUC h) l n)`,
  REPEAT STRIP_TAC
    \\ Cases_on `l = SUC h`
    << [
      RW_TAC arith_ss [EXP,BITS_ZERO,SBIT_def,BIT_def]
        \\ FULL_SIMP_TAC bool_ss [NOT_BITS2],
      `l <= h` by ASM_SIMP_TAC arith_ss []
        \\ IMP_RES_TAC LESS_EQ_IMP_LESS_SUC
        \\ ASM_SIMP_TAC arith_ss [SBIT_DIV,BIT_SLICE_THM,SLICE_THM,
             ONCE_REWRITE_RULE [MULT_COMM] lem4,
             (ONCE_REWRITE_RULE [MULT_COMM] o
              SPECL [`SUC h`,`h`]) BIT_COMP_THM3]]);

val BITS_SUC_THM = store_thm("BITS_SUC_THM",
  `!h l n. BITS (SUC h) l n =
     if SUC h < l then 0 else SBIT (BIT (SUC h) n) (SUC h - l) + BITS h l n`,
  RW_TAC arith_ss [BITS_ZERO,BITS_SUC]);

val DECEND_LEMMA = prove(
  `!P l y.  (!x. l <= x /\ x <= SUC y ==> P x) ==>
     (!x. l <= x /\ x <= y ==> P x)`,
  RW_TAC arith_ss []);

val BIT_BITS_LEM = prove(
  `!h l a b. l <= h ==> (BITS h l a = BITS h l b) ==>
      (BIT h a = BIT h b)`,
  RW_TAC bool_ss [BIT_SLICE,SLICE_THM]
    \\ PAT_ASSUM `l <= h` (fn th => ONCE_REWRITE_TAC
         [(GSYM o SIMP_RULE arith_ss [th,SUB_ADD] o
           SPECL [`h`,`l`,`h - l`,`h - l`]) BITS_COMP_THM])
    \\ ASM_REWRITE_TAC []);

val BIT_BITS_THM = store_thm("BIT_BITS_THM",
  `!h l a b. (!x. l <= x /\ x <= h ==>
      (BIT x a = BIT x b)) = (BITS h l a = BITS h l b)`,
  Induct_on `h` \\ REPEAT STRIP_TAC
    >> (Cases_on `l = 0` \\ RW_TAC arith_ss [BIT_SLICE,SLICE_THM,EXP,
          SPEC `0` BITS_ZERO,NOT_ZERO_LT_ZERO])
    \\ EQ_TAC \\ REPEAT STRIP_TAC
    << [
      RW_TAC bool_ss [BITS_SUC_THM]
        \\ RULE_ASSUM_TAC (REWRITE_RULE [NOT_LESS])
        \\ PAT_ASSUM `!x. l <= x /\ x <= SUC h ==> (BIT x a = BIT x b)`
             (fn th => ASM_SIMP_TAC bool_ss
                       [SIMP_RULE arith_ss [] (SPEC `SUC h` th)] \\
                     ASSUME_TAC (MATCH_MP ((BETA_RULE o SPECL
                       [`\x. BIT x a = BIT x b`,`l`,`h`]) DECEND_LEMMA) th))
        \\ FIRST_ASSUM (fn th => ASSUME_TAC (SPECL [`l`,`a`,`b`] th))
        \\ FULL_SIMP_TAC bool_ss [],
      IMP_RES_TAC SUB_BITS
        \\ FIRST_ASSUM (fn th => RULE_ASSUM_TAC
             (REWRITE_RULE [SYM (SPECL [`l`,`a`,`b`] th)]))
        \\ Cases_on `x <= h` \\ ASM_SIMP_TAC bool_ss []
        \\ `x = SUC h` by ASM_SIMP_TAC arith_ss []
        \\ Cases_on `l = SUC h` >> FULL_SIMP_TAC bool_ss [BIT_def]
        \\ `l <= SUC h` by ASM_SIMP_TAC arith_ss []
        \\ POP_ASSUM (fn th => ASSUME_TAC (SIMP_RULE bool_ss [th]
             (SPECL [`SUC h`,`l`,`a`,`b`] BIT_BITS_LEM)))
        \\ FULL_SIMP_TAC bool_ss []]);

(* ------------------------------------------------------------------------- *)

val LSB_ODD = store_thm("LSB_ODD", `LSB = ODD`,
  ONCE_REWRITE_TAC [FUN_EQ_THM]
    \\ SIMP_TAC arith_ss [ODD_MOD2_LEM,LSB_def,BIT_def,BITS_THM2,EXP,DIV_1]);

val BITV_THM = store_thm("BITV_THM",
  `!b n. BITV n b = SBIT (BIT b n) 0`,
  RW_TAC arith_ss [BITV_def,BIT_def,SBIT_def]
    \\ FULL_SIMP_TAC bool_ss [NOT_BITS2]);

(* ------------------------------------------------------------------------- *)

val BITWISE_LT_2EXP = store_thm("BITWISE_LT_2EXP",
  `!n op a b. BITWISE n op a b < 2 ** n`,
  Induct_on `n`
    \\ RW_TAC bool_ss [ADD_0,TIMES2,LESS_IMP_LESS_ADD,LESS_MONO_ADD,
         BITWISE_def,SBIT_def,EXP]
    \\ REDUCE_TAC);

val LESS_EXP_MULT2 = prove(
  `!a b. a < b ==> ?p. 2 ** b = 2 ** (p + 1) * 2 ** a`,
  REPEAT STRIP_TAC
    \\ IMP_RES_TAC LESS_ADD_1
    \\ RULE_ASSUM_TAC (ONCE_REWRITE_RULE [SIMP_RULE arith_ss []
           (SPEC `2` (GSYM EXP_INJECTIVE))])
    \\ EXISTS_TAC `p` \\ FULL_SIMP_TAC arith_ss [EXP_ADD,MULT_COMM]);

val BITWISE_LEM = prove(
  `!n op a b. BIT n (BITWISE (SUC n) op a b) = op (BIT n a) (BIT n b)`,
  RW_TAC arith_ss [SBIT_def,BITWISE_def,NOT_BIT]
    >> SIMP_TAC arith_ss [BIT_def,BITS_THM,SUC_SUB,
         REWRITE_RULE [BITWISE_LT_2EXP]
           (SPECL [`BITWISE n op a b`,`2 ** n`] DIV_MULT_1)]
    \\ SIMP_TAC arith_ss [BITS_THM,LESS_DIV_EQ_ZERO,BITWISE_LT_2EXP,SUC_SUB]);

val TWO_SUC_SUB =
  GEN_ALL (SIMP_CONV bool_ss [SUC_SUB,EXP_1] ``2 ** (SUC x - x)``);

val BITWISE_THM = store_thm("BITWISE_THM",
  `!x n op a b. x < n ==> (BIT x (BITWISE n op a b) = op (BIT x a) (BIT x b))`,
  Induct_on `n`
    \\ REPEAT STRIP_TAC >> FULL_SIMP_TAC arith_ss []
    \\ Cases_on `x = n` >> ASM_REWRITE_TAC [BITWISE_LEM]
    \\ `x < n` by ASM_SIMP_TAC arith_ss []
    \\ RW_TAC arith_ss [BITWISE_def,SBIT_def]
    \\ LEFT_REWRITE_TAC [BIT_def]
    \\ ASM_REWRITE_TAC [BITS_THM]
    \\ IMP_RES_TAC LESS_EXP_MULT2 \\ POP_LAST_TAC
    \\ ASM_SIMP_TAC bool_ss [ZERO_LT_TWOEXP,ADD_DIV_ADD_DIV,
         TWO_SUC_SUB,GSYM ADD1,EXP,ONCE_REWRITE_RULE [MULT_COMM]
         (REWRITE_RULE [DECIDE (Term `0 < 2`)] (SPEC `2` MOD_TIMES))]
    \\ SUBST_OCCS_TAC [([2],SYM (SPEC `x` TWO_SUC_SUB))]
    \\ ASM_SIMP_TAC bool_ss [GSYM BITS_THM,GSYM BIT_def]);

val BITWISE_COR = store_thm("BITWISE_COR",
  `!x n op a b. x < n ==> op (BIT x a) (BIT x b) ==>
      ((BITWISE n op a b DIV 2 ** x) MOD 2 = 1)`,
  NTAC 6 STRIP_TAC \\ IMP_RES_TAC BITWISE_THM
    \\ NTAC 2 (WEAKEN_TAC (K true))
    \\ POP_ASSUM (fn th => REWRITE_TAC [GSYM th])
    \\ ASM_REWRITE_TAC [BITS_THM,BIT_def,DIV_1,EXP_1,SUC_SUB]);

val BITWISE_NOT_COR = store_thm("BITWISE_NOT_COR",
  `!x n op a b. x < n ==> ~op (BIT x a) (BIT x b) ==>
      ((BITWISE n op a b DIV 2 ** x) MOD 2 = 0)`,
  NTAC 6 STRIP_TAC \\ IMP_RES_TAC BITWISE_THM
    \\ NTAC 2 (WEAKEN_TAC (K true))
    \\ POP_ASSUM (fn th => REWRITE_TAC [GSYM th])
    \\ ASM_REWRITE_TAC [BITS_THM,BIT_def,GSYM NOT_MOD2_LEM,DIV_1,EXP_1,SUC_SUB]
);

val BITWISE_BITS = store_thm("BITWISE_BITS",
  `!wl op a b. BITWISE (SUC wl) op (BITS wl 0 a) (BITS wl 0 b) =
               BITWISE (SUC wl) op a b`,
  Induct \\ FULL_SIMP_TAC arith_ss [BITWISE_def,BIT_def,BITS_COMP_THM2,MIN_DEF]
    \\ POP_ASSUM (fn th => ONCE_REWRITE_TAC [GSYM th])
    \\ SIMP_TAC arith_ss [BITS_COMP_THM2,MIN_DEF]);

(* ------------------------------------------------------------------------- *)

val BITS_SUC2 = prove(
  `!n a. BITS (SUC n) 0 a = SLICE (SUC n) (SUC n) a + BITS n 0 a`,
  RW_TAC arith_ss [GSYM SLICE_ZERO_THM,SLICE_COMP_THM]);

val lem = prove(
  `!n a. a < 2 ** SUC n ==> ~(2 ** SUC n < a + 1)`,
  RW_TAC arith_ss [NOT_LESS,EXP]);

val lem2 = MATCH_MP lem (REWRITE_RULE [SUB_0] (SPECL [`n`,`0`,`a`] BITSLT_THM));

val BITWISE_ONE_COMP_LEM = store_thm("BITWISE_ONE_COMP_LEM",
  `!n a b. BITWISE (SUC n) (\x y. ~x) a b = 2 ** (SUC n) - 1 - BITS n 0 a`,
  Induct_on `n` \\ REPEAT STRIP_TAC
    >> RW_TAC arith_ss [SBIT_def,BIT_def,BITWISE_def,NOT_BITS2]
    \\ RW_TAC arith_ss [BITWISE_def,SBIT_def,REWRITE_RULE [SLICE_THM] BITS_SUC2]
    \\ RULE_ASSUM_TAC (SIMP_RULE bool_ss [NOT_BIT,NOT_BITS,BIT_def])
    \\ ASM_SIMP_TAC arith_ss [MULT_CLAUSES]
    << [
      Cases_on `2 ** SUC n = BITS n 0 a + 1`
        >> ASM_SIMP_TAC arith_ss [SUB_RIGHT_ADD,EXP]
        \\ ASSUME_TAC lem2
        \\ `~(2 ** SUC n <= BITS n 0 a + 1)` by ASM_SIMP_TAC arith_ss []
        \\ ASM_SIMP_TAC arith_ss [SUB_RIGHT_ADD,EXP],
      REWRITE_TAC [REWRITE_CONV [ADD_SUB,TIMES2] (Term`2 * a - a`),SUB_PLUS,EXP]
    ]
);

(* ------------------------------------------------------------------------- *)

val BIT_SET_NOT_ZERO = prove(
  `!a. (a MOD 2 = 1) ==> (1 <= a)`,
  SPOSE_NOT_THEN STRIP_ASSUME_TAC \\ `a = 0` by DECIDE_TAC
    \\ FULL_SIMP_TAC arith_ss [ZERO_MOD]);

val BIT_SET_NOT_ZERO_COR = prove(
  `!x n op a b. x < n ==> op (BIT x a) (BIT x b) ==>
      (1 <= (BITWISE n op a b DIV 2 ** x))`,
  REPEAT STRIP_TAC \\ ASM_SIMP_TAC bool_ss [BITWISE_COR,BIT_SET_NOT_ZERO]);

val BIT_SET_NOT_ZERO_COR2 =
  REWRITE_RULE [DIV_1,EXP] (SPEC `0` BIT_SET_NOT_ZERO_COR);

val BIT_DIV2 = prove(
  `!i. BIT n (i DIV 2) = BIT (SUC n) i`,
  RW_TAC arith_ss [BIT_def,BITS_THM,EXP,ZERO_LT_TWOEXP,DIV_DIV_DIV_MULT]);

val SBIT_MULT = store_thm("SBIT_MULT",
  `!b m n. (SBIT b n) * 2 ** m = SBIT b (n + m)`,
  RW_TAC arith_ss [SBIT_def,EXP_ADD]);

val lemma1 = prove(
  `!a b n. 0 < n ==> ((a + SBIT b n) DIV 2 = a DIV 2 + SBIT b (n - 1))`,
  RW_TAC arith_ss [SBIT_def] \\ IMP_RES_TAC LESS_ADD_1
    \\ FULL_SIMP_TAC arith_ss [GSYM ADD1,EXP,
         (SIMP_RULE arith_ss [] o SPEC `2`) ADD_DIV_ADD_DIV]);

val lemma2 = (ONCE_REWRITE_RULE [MULT_COMM] o REWRITE_RULE [EXP_1] o
              INST [`m` |-> `1`] o SPEC_ALL) SBIT_MULT;

val lemma3 = prove(
  `!n op a b. 0 < n ==> (BITWISE n op a b MOD 2 = SBIT (op (LSB a) (LSB b)) 0)`,
  RW_TAC bool_ss [LSB_def]
    \\ POP_ASSUM (fn th => ONCE_REWRITE_TAC
           [MATCH_MP ((GSYM o SPEC `0`) BITWISE_THM) th])
    \\ RW_TAC bool_ss [GSYM LSB_def,LSB_ODD,ODD_MOD2_LEM,SBIT_def,EXP]
    \\ FULL_SIMP_TAC bool_ss [GSYM NOT_MOD2_LEM]);

val lemma4 = prove(
  `!n op a b. 0 < n /\ BITWISE n op a b <= SBIT (op (LSB a) (LSB b)) 0 ==>
              (BITWISE n op a b = SBIT (op (LSB a) (LSB b)) 0)`,
  RW_TAC arith_ss [LSB_def,SBIT_def,EXP]
    \\ IMP_RES_TAC BIT_SET_NOT_ZERO_COR2
    \\ ASM_SIMP_TAC arith_ss []);

val BITWISE_ISTEP = prove(
  `!n op a b. 0 < n ==>
      (BITWISE n op (a DIV 2) (b DIV 2) =
       (BITWISE n op a b) DIV 2 + SBIT (op (BIT n a) (BIT n b)) (n - 1))`,
  Induct_on `n` \\ REPEAT STRIP_TAC >> FULL_SIMP_TAC arith_ss []
    \\ Cases_on `n = 0` >> RW_TAC arith_ss [BITWISE_def,SBIT_def,BIT_DIV2]
    \\ FULL_SIMP_TAC bool_ss
         [NOT_ZERO_LT_ZERO,BITWISE_def,SUC_SUB1,BIT_DIV2,lemma1]);

val BITWISE_EVAL = store_thm("BITWISE_EVAL",
  `!n op a b. BITWISE (SUC n) op a b =
      2 * (BITWISE n op (a DIV 2) (b DIV 2)) + SBIT (op (LSB a) (LSB b)) 0`,
  REPEAT STRIP_TAC \\ Cases_on `n = 0`
    >> RW_TAC arith_ss [BITWISE_def,MULT_CLAUSES,LSB_def]
    \\ FULL_SIMP_TAC arith_ss [BITWISE_def,NOT_ZERO_LT_ZERO,BITWISE_ISTEP,
           DIV_MULT_THM2,LEFT_ADD_DISTRIB,SUB_ADD,lemma2,lemma3]
    \\ RW_TAC arith_ss [SUB_RIGHT_ADD,lemma4]);

(* ------------------------------------------------------------------------- *)

val MOD_PLUS_RIGHT = store_thm("MOD_PLUS_RIGHT",
 `!n. 0<n ==> !j k. ((j + (k MOD n)) MOD n) = ((j+k) MOD n)`,
   let fun SUBS th = SUBST_OCCS_TAC [([2],th)]
   in
   REPEAT STRIP_TAC \\
   IMP_RES_TAC MOD_TIMES \\
   PURE_ONCE_REWRITE_TAC [ADD_SYM] \\
   IMP_RES_THEN (TRY o SUBS o SPEC (`k:num`)) DIVISION \\
   ASM_REWRITE_TAC [SYM(SPEC_ALL ADD_ASSOC)]
   end);

val MOD_LESS = prove(
  `!n a. 0 < n ==> a MOD n < n`, PROVE_TAC [DIVISION]);

val MOD_LESS1 = prove(
  `!n. 0 < n ==> a MOD n + 1 <= n`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC MOD_LESS
    \\ POP_ASSUM (fn th => ASSUME_TAC (SPEC `a` th))
    \\ RW_TAC arith_ss []);

val MOD_ZERO = prove(
  `!n. 0 < n /\ 0 < a /\ a <= n /\ (a MOD n = 0) ==> (a = n)`,
  REPEAT STRIP_TAC \\ Cases_on `a < n`
    \\ FULL_SIMP_TAC arith_ss [LESS_MOD,GSYM NOT_ZERO_LT_ZERO]);

val MOD_PLUS_1 = store_thm("MOD_PLUS_1",
  `!n. 0 < n ==> !x. ((x + 1) MOD n = 0) = (x MOD n + 1 = n)`,
  REPEAT STRIP_TAC
    \\ Cases_on `n = 1` >> ASM_SIMP_TAC arith_ss [MOD_1]
    \\ IMP_RES_TAC MOD_PLUS
    \\ POP_ASSUM (fn th => ONCE_REWRITE_TAC [GSYM th])
    \\ `1 < n` by ASM_SIMP_TAC arith_ss []
    \\ ASM_SIMP_TAC bool_ss [LESS_MOD]
    \\ EQ_TAC \\ STRIP_TAC
    << [
      `0 < x MOD n + 1` by SIMP_TAC arith_ss []
        \\ IMP_RES_TAC MOD_LESS1
        \\ POP_ASSUM (fn th => ASSUME_TAC (SPEC `x` th))
        \\ IMP_RES_TAC MOD_ZERO,
      ASM_SIMP_TAC bool_ss [ADD_EQ_SUB,SUB_ADD,DIVMOD_ID]]);

val MOD_ADD_1 = store_thm("MOD_ADD_1",
  `!n. 0 < n ==> !x. ~((x + 1) MOD n = 0) ==> ((x + 1) MOD n = x MOD n + 1)`,
  RW_TAC bool_ss [MOD_PLUS_1]
    \\ IMP_RES_TAC (SPEC `n` DIVISION)
    \\ PAT_ASSUM `!k. k = k DIV n * n + k MOD n`
         (fn th => SUBST_OCCS_TAC [([1],SPEC `x` th)])
    \\ ONCE_REWRITE_TAC [GSYM ADD_ASSOC]
    \\ POP_ASSUM (fn th => ASSUME_TAC (SPEC `x` th))
    \\ `x MOD n + 1 < n` by ASM_SIMP_TAC arith_ss []
    \\ ASM_SIMP_TAC bool_ss [MOD_TIMES,LESS_MOD]);

(* ------------------------------------------------------------------------- *)

val SPEC_EXP1_RULE = (REWRITE_RULE [EXP_1] o SPECL [`x`,`1`]);

val BIT_REVERSE_THM = store_thm("BIT_REVERSE_THM",
  `!x n a. x < n ==> (BIT x (BIT_REVERSE n a) = BIT (n - 1 - x) a)`,
  Induct_on `n` >> REWRITE_TAC [NOT_LESS_0]
    \\ RW_TAC std_ss [BIT_REVERSE_def]
    \\ Cases_on `x = 0`
    << [
      `2 = 2 ** (SUC 0)` by numLib.REDUCE_TAC \\ POP_ASSUM SUBST1_TAC
        \\ ASM_SIMP_TAC bool_ss [BIT_def,BITS_SUM2]
        \\ RW_TAC arith_ss [SBIT_def,BITS_THM],
      `!y m n. BIT x (m + n) = BIT (x - 1) (BITS x 1 (m + n))`
          by RW_TAC arith_ss [BIT_def,BITS_COMP_THM2,MIN_DEF]
        \\ `!b. SBIT b 0 < 2` by RW_TAC arith_ss [SBIT_def]
        \\ `!y b. BIT x (y * 2 + SBIT b 0) = BIT (x - 1) y`
        by (ASM_SIMP_TAC arith_ss
                  [SPEC_EXP1_RULE BITS_SUM, SPEC_EXP1_RULE BITS_ZERO4]
             \\ SIMP_TAC arith_ss [BIT_def,BITS_COMP_THM2])
        \\ `x - 1 < n` by DECIDE_TAC
        \\ ASM_SIMP_TAC std_ss []
        \\ Cases_on `n = 0` >> ASM_SIMP_TAC arith_ss []
        \\ `1 <= n /\ 1 <= x` by DECIDE_TAC
        \\ ASM_SIMP_TAC std_ss [ADD1,SUB_SUB,ADD_SUB,SUB_ADD]]);

(* ------------------------------------------------------------------------- *)

val BIT_MODIFY_LT_2EXP = prove(
  `!n f a. BIT_MODIFY n f a < 2 ** n`,
  Induct_on `n`
    \\ RW_TAC bool_ss [ADD_0,TIMES2,LESS_IMP_LESS_ADD,LESS_MONO_ADD,
           BIT_MODIFY_def,SBIT_def,EXP] \\ REDUCE_TAC);

val BIT_MODIFY_LEM = prove(
  `!n f a. BIT n (BIT_MODIFY (SUC n) f a) = f n (BIT n a)`,
  RW_TAC arith_ss [SBIT_def,BIT_MODIFY_def,NOT_BIT]
    >> SIMP_TAC arith_ss [BIT_def,BITS_THM,SUC_SUB,
         REWRITE_RULE [BIT_MODIFY_LT_2EXP]
           (SPECL [`BIT_MODIFY n f a`,`2 ** n`] DIV_MULT_1)]
    \\ SIMP_TAC arith_ss [BITS_THM,LESS_DIV_EQ_ZERO,BIT_MODIFY_LT_2EXP,SUC_SUB]
);

val BIT_MODIFY_THM = store_thm("BIT_MODIFY_THM",
  `!x n f a. x < n ==> (BIT x (BIT_MODIFY n f a) = f x (BIT x a))`,
  Induct_on `n` \\ REPEAT STRIP_TAC >> FULL_SIMP_TAC arith_ss []
    \\ Cases_on `x = n` >> ASM_REWRITE_TAC [BIT_MODIFY_LEM]
    \\ `x < n` by ASM_SIMP_TAC arith_ss []
    \\ RW_TAC arith_ss [BIT_MODIFY_def,SBIT_def]
    \\ LEFT_REWRITE_TAC [BIT_def] \\ ASM_REWRITE_TAC [BITS_THM]
    \\ IMP_RES_TAC LESS_EXP_MULT2 \\ POP_LAST_TAC
    \\ ASM_SIMP_TAC bool_ss [ZERO_LT_TWOEXP,ADD_DIV_ADD_DIV,
         TWO_SUC_SUB,GSYM ADD1,EXP,ONCE_REWRITE_RULE [MULT_COMM]
         (REWRITE_RULE [DECIDE (Term `0 < 2`)] (SPEC `2` MOD_TIMES))]
    \\ SUBST_OCCS_TAC [([2],SYM (SPEC `x` TWO_SUC_SUB))]
    \\ ASM_SIMP_TAC bool_ss [GSYM BITS_THM,GSYM BIT_def]);

(* ------------------------------------------------------------------------- *)

val _ =
 let open EmitML
 in
   exportML (!Globals.exportMLPath)
  ("bits",
    MLSIG "type num = numML.num" :: OPEN ["num"]
    ::
    map (DEFN o PURE_REWRITE_RULE [arithmeticTheory.NUMERAL_DEF])
        [TIMES_2EXP_def, DIV_2EXP_def, MOD_2EXP_def,
         DIVMOD_2EXP, SBIT_def, BITS_def,
         BITV_def, BIT_def, SLICE_def,LSB_def,
         SIGN_EXTEND_def])
 end;

val _ = export_theory();

(* ------------------------------------------------------------------------- *)
