(* ========================================================================= *)
(* FILE          : fcpScript.sml                                             *)
(* DESCRIPTION   : A port, from HOL light, of John Harrison's treatment of   *)
(*                 finite Cartesian products (TPHOLs 2005)                   *)
(* DATE          : 2005                                                      *)
(* ========================================================================= *)

(* interactive use:
  load "pred_setTheory";
*)

open HolKernel Parse boolLib bossLib;
open Q pred_setTheory;

val _ = new_theory "fcp";

(* ------------------------------------------------------------------------- *)

val _ = add_infix("HAS_SIZE",8,HOLgrammars.RIGHT);

val HAS_SIZE = Define`
  (s HAS_SIZE n) = FINITE s /\ (CARD s = n)`;

val CARD_CLAUSES = CONJ CARD_EMPTY (PROVE [CARD_INSERT]
  ``!x s. FINITE s ==>
           (CARD (x INSERT s) = (if x IN s then CARD s else SUC (CARD s)))``);
val IMAGE_CLAUSES = CONJ IMAGE_EMPTY IMAGE_INSERT;
val FINITE_RULES = CONJ FINITE_EMPTY FINITE_INSERT;
val NOT_SUC = numTheory.NOT_SUC;
val SUC_INJ = prim_recTheory.INV_SUC_EQ;
val LT = CONJ (DECIDE ``!m. ~(m < 0)``) prim_recTheory.LESS_THM;
val LT_REFL = prim_recTheory.LESS_REFL;

val CARD_IMAGE_INJ = prove(
  `!(f:'a->'b) s. (!x y. x IN s /\ y IN s /\ (f(x) = f(y)) ==> (x = y)) /\
                FINITE s ==> (CARD (IMAGE f s) = CARD s)`,
  GEN_TAC THEN
  REWRITE_TAC[DECIDE ``a /\ b ==> c = b ==> a ==> c``] THEN
  SPEC_THEN `\s. (!x y. (f x = f y) ==> y IN s ==> x IN s ==> (x = y)) ==>
      (CARD (IMAGE f s) = CARD s)` (MATCH_MP_TAC o BETA_RULE) FINITE_INDUCT THEN
  REWRITE_TAC[NOT_IN_EMPTY, IMAGE_CLAUSES] THEN
  REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC std_ss [CARD_CLAUSES, IMAGE_FINITE, IN_IMAGE] THEN
  COND_CASES_TAC THEN PROVE_TAC[IN_INSERT]);

val HAS_SIZE_IMAGE_INJ = prove(
  `!(f:'a->'b) s n.
        (!x y. x IN s /\ y IN s /\ (f(x) = f(y)) ==> (x = y)) /\ (s HAS_SIZE n)
        ==> ((IMAGE f s) HAS_SIZE n)`,
  SIMP_TAC std_ss [HAS_SIZE, IMAGE_FINITE] THEN PROVE_TAC[CARD_IMAGE_INJ]);

val HAS_SIZE_0 = prove(
  `!(s:'a->bool) n. (s HAS_SIZE 0) = (s = {})`,
  REPEAT GEN_TAC THEN REWRITE_TAC[HAS_SIZE] THEN
  EQ_TAC THEN DISCH_TAC THEN
  ASM_REWRITE_TAC[FINITE_RULES, CARD_CLAUSES] THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT2) THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1) THEN
  SPEC_TAC(`s:'a->bool`,`s:'a->bool`) THEN
  SPEC_THEN `\s. (CARD s = 0) ==> (s = {})` (MATCH_MP_TAC o BETA_RULE) FINITE_INDUCT THEN
  REWRITE_TAC[NOT_INSERT_EMPTY] THEN
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  ASM_SIMP_TAC arith_ss [CARD_INSERT]);

val HAS_SIZE_SUC = prove
 (`!(s:'a->bool) n. (s HAS_SIZE (SUC n)) =
                   ~(s = {}) /\ !a. a IN s ==> ((s DELETE a) HAS_SIZE n)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[HAS_SIZE] THEN
  ASM_CASES_TAC `s:'a->bool = {}` THEN
  ASM_REWRITE_TAC[CARD_CLAUSES, FINITE_RULES, NOT_IN_EMPTY, GSYM NOT_SUC] THEN
  REWRITE_TAC[FINITE_DELETE] THEN
  ASM_CASES_TAC `FINITE(s:'a->bool)` THEN
  ASM_SIMP_TAC std_ss[NOT_FORALL_THM, MEMBER_NOT_EMPTY] THEN
  EQ_TAC THEN REPEAT STRIP_TAC THENL
   [MP_TAC(ISPECL [`a:'a`, `s DELETE a:'a`] (CONJUNCT2 CARD_CLAUSES)) THEN
    ASM_REWRITE_TAC [FINITE_DELETE, IN_DELETE] THEN
    SUBGOAL_THEN `a INSERT (s DELETE a:'a) = s` SUBST1_TAC THENL
     [UNDISCH_TAC `a:'a IN s` THEN PROVE_TAC[INSERT_DELETE],
      ASM_REWRITE_TAC[SUC_INJ] THEN PROVE_TAC[]],
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I empty_rewrites [GSYM MEMBER_NOT_EMPTY]) THEN
    DISCH_THEN(X_CHOOSE_TAC `a:'a`) THEN
    MP_TAC(ISPECL [`a:'a`, `s DELETE a:'a`] (CONJUNCT2 CARD_CLAUSES)) THEN
    ASM_REWRITE_TAC[FINITE_DELETE, IN_DELETE] THEN
    SUBGOAL_THEN `a INSERT (s DELETE a:'a) = s` SUBST1_TAC THENL
     [UNDISCH_TAC `a:'a IN s` THEN PROVE_TAC[INSERT_DELETE],
      PROVE_TAC[]]]);

val HAS_SIZE_INDEX = prove(
  `!s n. (s HAS_SIZE n)
         ==> ?f:num->'a. (!m. m < n ==> f(m) IN s) /\
                         (!x. x IN s ==> ?!m. m < n /\ (f m = x))`,
  CONV_TAC SWAP_VARS_CONV THEN numLib.INDUCT_TAC THEN
  SIMP_TAC std_ss [HAS_SIZE_0, HAS_SIZE_SUC, LT, NOT_IN_EMPTY] THEN
  X_GEN_TAC `s:'a->bool` THEN REWRITE_TAC[EXTENSION, NOT_IN_EMPTY] THEN
  SIMP_TAC std_ss[NOT_FORALL_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2 (X_CHOOSE_TAC `a:'a`) (MP_TAC o SPEC `a:'a`)) THEN
  ASM_REWRITE_TAC[] THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `s DELETE (a:'a)`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(X_CHOOSE_THEN `f:num->'a` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `\m:num. if m < n then f(m) else a:'a` THEN CONJ_TAC THENL
   [GEN_TAC THEN REWRITE_TAC[] THEN BETA_TAC THEN COND_CASES_TAC THEN
    PROVE_TAC[IN_DELETE], ALL_TAC] THEN
  X_GEN_TAC `x:'a` THEN DISCH_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:'a`) THEN
  ASM_SIMP_TAC (std_ss++boolSimps.COND_elim_ss) [IN_DELETE] THEN
  ASM_CASES_TAC `a:'a = x` THEN ASM_SIMP_TAC std_ss [] THEN
  PROVE_TAC[LT_REFL, IN_DELETE]);

(* ------------------------------------------------------------------------- *)
(* An isomorphic image of any finite type, 1-element for infinite ones.      *)
(* ------------------------------------------------------------------------- *)

val finite_image_tybij = BETA_RULE (define_new_type_bijections
  {name="finite_image_tybij", ABS="mk_finite_image", REP="dest_finite_image",
   tyax=new_type_definition("finite_image",
          prove(`?x:'a. (\x. (x = ARB) \/ FINITE(UNIV:'a->bool)) x`,PROVE_TAC[]))});

val FINITE_IMAGE_IMAGE = prove(
  `UNIV:'a finite_image->bool =
    IMAGE mk_finite_image
      (if FINITE(UNIV:'a->bool) then UNIV:'a->bool else {ARB})`,
  MP_TAC finite_image_tybij THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[EXTENSION, IN_IMAGE, IN_SING, IN_UNIV] THEN PROVE_TAC[]);

(* ------------------------------------------------------------------------- *)
(* Dimension of such a type, and indexing over it.                           *)
(* ------------------------------------------------------------------------- *)

val _ = computeLib.auto_import_definitions := false;

val dimindex_def = Define`
  dimindex(:'a) = if FINITE(UNIV:'a->bool) then CARD(UNIV:'a->bool) else 1`;
val dimindex = save_thm("dimindex", dimindex_def);

val HAS_SIZE_FINITE_IMAGE = prove(
  `(UNIV:'a finite_image->bool) HAS_SIZE dimindex(:'a)`,
  REWRITE_TAC[dimindex, FINITE_IMAGE_IMAGE] THEN
  MP_TAC finite_image_tybij THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  MATCH_MP_TAC HAS_SIZE_IMAGE_INJ THEN
  ASM_REWRITE_TAC [HAS_SIZE, IN_UNIV, IN_SING] THEN
  SIMP_TAC arith_ss [CARD_EMPTY, CARD_SING, CARD_INSERT, FINITE_SING,
    FINITE_INSERT, NOT_IN_EMPTY] THEN
  PROVE_TAC[]);

val CARD_FINITE_IMAGE = prove(
  `CARD(UNIV:'a finite_image->bool) = dimindex(:'a)`,
  PROVE_TAC[HAS_SIZE_FINITE_IMAGE, HAS_SIZE]);

val FINITE_FINITE_IMAGE = prove(
  `FINITE(UNIV:'a finite_image->bool)`,
  PROVE_TAC[HAS_SIZE_FINITE_IMAGE, HAS_SIZE]);

val DIMINDEX_NONZERO = prove(
  `~(dimindex(:'a) = 0)`,
  DISCH_TAC THEN
  MP_TAC HAS_SIZE_FINITE_IMAGE THEN
  ASM_REWRITE_TAC[HAS_SIZE_0,UNIV_NOT_EMPTY]);

val DIMINDEX_GE_1 = store_thm("DIMINDEX_GE_1",
  `1 <= dimindex(:'a)`,
  REWRITE_TAC[DECIDE ``1 <= x = ~(x = 0)``, DIMINDEX_NONZERO]);

val DIMINDEX_FINITE_IMAGE = prove(
  `dimindex(:'a finite_image) = dimindex(:'a)`,
  GEN_REWRITE_TAC LAND_CONV empty_rewrites [dimindex] THEN
  MP_TAC HAS_SIZE_FINITE_IMAGE THEN
  SIMP_TAC std_ss [FINITE_FINITE_IMAGE, HAS_SIZE]);

val finite_index = Define`
  finite_index =
    @f:num->'a. !x:'a. ?!n. n < dimindex(:'a) /\ (f n = x)`;

val FINITE_INDEX_WORKS_FINITE = prove(
  `FINITE(UNIV:'n->bool) ==>
   !i:'n. ?!n. n < dimindex(:'n) /\ (finite_index n = i)`,
  DISCH_TAC THEN ASM_REWRITE_TAC[finite_index, dimindex] THEN
  CONV_TAC SELECT_CONV THEN
  SUBGOAL_THEN `(UNIV:'n->bool) HAS_SIZE CARD(UNIV:'n->bool)`
  MP_TAC THENL [PROVE_TAC[HAS_SIZE], ALL_TAC] THEN
  DISCH_THEN(MP_TAC o MATCH_MP HAS_SIZE_INDEX) THEN
  ASM_REWRITE_TAC[HAS_SIZE, IN_UNIV]);

val FINITE_INDEX_WORKS = prove
 (`!i:'a finite_image.
        ?!n. n < dimindex(:'a) /\ (finite_index n = i)`,
  MP_TAC(MATCH_MP FINITE_INDEX_WORKS_FINITE FINITE_FINITE_IMAGE) THEN
  PROVE_TAC[DIMINDEX_FINITE_IMAGE]);

val FINITE_INDEX_INJ = prove
 (`!i j. i < dimindex(:'a) /\ j < dimindex(:'a)
         ==> ((finite_index i :'a = finite_index j) = (i = j))`,
  ASM_CASES_TAC `FINITE(UNIV:'a->bool)` THEN ASM_REWRITE_TAC[dimindex] THENL
   [FIRST_ASSUM(MP_TAC o MATCH_MP FINITE_INDEX_WORKS_FINITE) THEN
    ASM_REWRITE_TAC[dimindex] THEN PROVE_TAC[],
    PROVE_TAC[DECIDE ``!a. a < 1 = (a = 0)``]]);

val FORALL_FINITE_INDEX = prove
 (`(!k:'n finite_image. P k) =
   (!i. i < dimindex(:'n) ==> P(finite_index i))`,
  PROVE_TAC[FINITE_INDEX_WORKS]);

(* ------------------------------------------------------------------------- *)
(* Hence finite Cartesian products, with indexing and lambdas.               *)
(* ------------------------------------------------------------------------- *)

val cart_tybij = SIMP_RULE std_ss [] (define_new_type_bijections
  {name="cart_tybij", ABS="mk_cart", REP="dest_cart",
   tyax=new_type_definition("cart",
    prove(`?f:'b finite_image->'a. (\f. T) f`,REWRITE_TAC[]))});

val _ = add_infix_type {Prec = 60, ParseName = SOME "**", Name = "cart",
                        Assoc = HOLgrammars.RIGHT};

val index_def = new_infixl_definition("index",
  `$index x i = dest_cart x (finite_index i)`,500);

val _ = add_infix("%%",500,HOLgrammars.LEFT);
val _ = overload_on ("%%", Term`$index`);

val CART_EQ = store_thm("CART_EQ",
  `!(x:'a ** 'b) y.
    (x = y) = (!i. i < dimindex(:'b) ==> (x %% i = y %% i))`,
  REPEAT GEN_TAC THEN SIMP_TAC std_ss [index_def, GSYM FORALL_FINITE_INDEX] THEN
  REWRITE_TAC[GSYM FUN_EQ_THM, ETA_AX] THEN PROVE_TAC[cart_tybij]);

val FCP = new_binder_definition("FCP",
  ``($FCP) = \g.
     @(f:'a ** 'b). (!i. i < dimindex(:'b) ==> (f %% i = g i))``);

val FCP_BETA = store_thm("FCP_BETA",
  `!i. i < dimindex(:'b)
       ==> (((FCP) g:'a ** 'b) %% i = g i)`,
  SIMP_TAC std_ss [FCP] THEN CONV_TAC SELECT_CONV THEN
  EXISTS_TAC `mk_cart(\k. g(@i. i < dimindex(:'b) /\
                                (finite_index i = k))):'a ** 'b` THEN
  SIMP_TAC std_ss [index_def, cart_tybij] THEN
  REPEAT STRIP_TAC THEN AP_TERM_TAC THEN MATCH_MP_TAC SELECT_UNIQUE THEN
  GEN_TAC THEN REWRITE_TAC[] THEN
  PROVE_TAC[FINITE_INDEX_INJ, DIMINDEX_FINITE_IMAGE]);

val FCP_UNIQUE = prove
 (`!(f:'a ** 'b) g.
        (!i. i < dimindex(:'b) ==> (f %% i = g i)) =
        ((FCP) g = f)`,
  SIMP_TAC std_ss [CART_EQ, FCP_BETA] THEN PROVE_TAC[]);

val FCP_ETA = store_thm("FCP_ETA",
  `!g. (FCP i. g %% i) = g`,
  SIMP_TAC std_ss [CART_EQ, FCP_BETA]);

(* ------------------------------------------------------------------------- *)
(* Support for introducing finite index types                                *)
(* ------------------------------------------------------------------------- *)

(* Given an abstraction map f ... *)
val index_size = prove(
  `!f n. BIJ f (count n) (IMAGE f (count n)) ==>
    (CARD (IMAGE f (count n)) = CARD (count n))`,
  METIS_TAC [IMAGE_FINITE,FINITE_BIJ_CARD_EQ,FINITE_COUNT]
);

val index_size = save_thm("index_size",
  SIMP_RULE std_ss [CARD_COUNT] index_size);

(* ------------------------------------------------------------------------- *)

val sum_union = prove(
  `UNIV:('a+'b)->bool = ISL UNION ISR`,
  REWRITE_TAC [FUN_EQ_THM,UNIV_DEF,UNION_DEF]
    THEN STRIP_TAC THEN ONCE_REWRITE_TAC [GSYM SPECIFICATION]
    THEN SIMP_TAC std_ss [GSPECIFICATION,IN_DEF,sumTheory.ISL_OR_ISR]);

val inl_inr_bij = prove(
  `BIJ INL (UNIV:'a->bool) (ISL:'a + 'b -> bool) /\
   BIJ INR (UNIV:'b->bool) (ISR:'a + 'b -> bool)`,
  RW_TAC std_ss [UNIV_DEF,BIJ_DEF,INJ_DEF,SURJ_DEF,IN_DEF]
    THEN PROVE_TAC [sumTheory.INL,sumTheory.INR]);

val inl_inr_image = prove(
  `((ISL:'a + 'b -> bool) = IMAGE INL (UNIV:'a->bool)) /\
   ((ISR:'a + 'b -> bool) = IMAGE INR (UNIV:'b->bool))`,
  RW_TAC std_ss [EXTENSION,IMAGE_DEF,IN_UNIV,GSPECIFICATION]
    THEN SIMP_TAC std_ss [IN_DEF] THEN Cases_on `x`
    THEN SIMP_TAC std_ss [sumTheory.ISL,sumTheory.ISR,sumTheory.sum_distinct]);

val isl_isr_finite = prove(
  `(FINITE (ISL:'a + 'b -> bool) = FINITE (UNIV:'a->bool)) /\
   (FINITE (ISR:'a + 'b -> bool) = FINITE (UNIV:'b->bool))`,
  REWRITE_TAC [inl_inr_image] THEN CONJ_TAC
    THEN MATCH_MP_TAC INJECTIVE_IMAGE_FINITE
    THEN REWRITE_TAC [sumTheory.INR_INL_11]);

val isl_isr_univ = prove(
  `(FINITE (UNIV:'a -> bool) ==>
     (CARD (ISL:'a + 'b -> bool) = CARD (UNIV:'a->bool))) /\
   (FINITE (UNIV:'b -> bool) ==>
     (CARD (ISR:'a + 'b -> bool) = CARD (UNIV:'b->bool)))`,
   METIS_TAC [FINITE_BIJ_CARD_EQ,isl_isr_finite,inl_inr_bij]);

val isl_isr_inter = prove(
  `(ISL:'a + 'b -> bool) INTER (ISR:'a + 'b -> bool) = {}`,
  RW_TAC std_ss [INTER_DEF,EXTENSION,NOT_IN_EMPTY,GSPECIFICATION]
    THEN SIMP_TAC std_ss [IN_DEF] THEN Cases_on `x`
    THEN SIMP_TAC std_ss [sumTheory.ISR,sumTheory.ISL]);

val isl_isr_union = prove(
  `FINITE (UNIV:'a -> bool) /\ FINITE (UNIV:'b -> bool) ==>
     (CARD ((ISL:'a + 'b -> bool) UNION (ISR:'a + 'b -> bool)) =
      CARD (ISL:'a + 'b -> bool) + CARD (ISR:'a + 'b -> bool))`,
  METIS_TAC [CARD_UNION,arithmeticTheory.ADD_0,CARD_EMPTY,
    isl_isr_inter,isl_isr_finite]);

val index_sum = store_thm("index_sum",
  `dimindex(:('a+'b)) =
   if FINITE (UNIV:'a->bool) /\ FINITE (UNIV:'b->bool) then
     dimindex(:'a) + dimindex(:'b)
   else
     1`,
  RW_TAC std_ss [dimindex,sum_union,isl_isr_union,isl_isr_univ,FINITE_UNION]
    THEN METIS_TAC [isl_isr_finite]);

(* ------------------------------------------------------------------------- *)

val _ = export_theory();
