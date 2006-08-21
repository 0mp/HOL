open HolKernel Parse boolLib bossLib metisLib basic_swapTheory

val _ = new_theory "chap3";

local open pred_setLib in end;

open binderLib BasicProvers
open termTheory chap2Theory

val SUBSET_DEF = pred_setTheory.SUBSET_DEF

val compatible_def =
    Define`compatible R = !x y c. R x y /\ one_hole_context c ==>
                                  R (c x) (c y)`;

val congruence_def = Define`congruence R = equivalence R /\ compatible R`;

val is_reduction_def =
    Define`is_reduction R = compatible R /\ transitive R /\ reflexive R`;

val (compat_closure_rules, compat_closure_ind, compat_closure_cases) =
    Hol_reln`(!x y. R x y ==> compat_closure R x y) /\
             (!x y z. compat_closure R x y ==>
                      compat_closure R (z @@ x) (z @@ y)) /\
             (!x y z. compat_closure R x y ==>
                      compat_closure R (x @@ z) (y @@ z)) /\
             (!x y v. compat_closure R x y ==>
                 compat_closure R (LAM v x) (LAM v y))`

(* Barendregt definition 3.1.14 *)
val substitutive_def = Define`
  substitutive R = !M M'. R M M' ==> !N v. R ([N/v]M) ([N/v]M')
`;

val permutative_def = Define`
  permutative R = !M M'. R M M' ==> !p. R (tpm p M) (tpm p M')
`;

val cc_gen_ind = store_thm(
  "cc_gen_ind",
  ``!R fv. (!M N p. R M N ==> R (tpm p M) (tpm p N)) /\
           (!M N x. R M N ==> P M N x) /\
           (!M M' N x. (!y. P M M' y) ==> P (M @@ N) (M' @@ N) x) /\
           (!M N N' x. (!y. P N N' y) ==> P (M @@ N) (M @@ N') x) /\
           (!v M M' x. ~(v IN fv x) /\ (!y. P M M' y) ==>
                       P (LAM v M) (LAM v M') x) /\
           (!x. FINITE (fv x)) ==>
           !M N. compat_closure R M N ==> !x. P M N x``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  Q_TAC SUFF_TAC `!M N. compat_closure R M N ==>
                        !x p. P (tpm p M) (tpm p N) x`
        THEN1 METIS_TAC [tpm_NIL] THEN
  HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][] THEN
  Q_TAC (NEW_TAC "z") `fv x UNION {lswapstr p v} UNION FV (tpm p M) UNION
                       FV (tpm p N)` THEN
  `LAM (lswapstr p v) (tpm p M) = LAM z (tpm ([(z,lswapstr p v)] ++ p) M)`
     by SRW_TAC [][tpm_ALPHA, tpm_APPEND] THEN
  `LAM (lswapstr p v) (tpm p N) = LAM z (tpm ([(z,lswapstr p v)] ++ p) N)`
     by SRW_TAC [][tpm_ALPHA, tpm_APPEND] THEN
  SRW_TAC [][]);

val all_fnone = prove(
  ``(!(f:one -> 'a). P f) = !x:'a. P (K x)``,
  SRW_TAC [][EQ_IMP_THM] THEN
  Q_TAC SUFF_TAC `f = K (f())`
        THEN1 (DISCH_THEN SUBST1_TAC THEN SRW_TAC [][]) THEN
  SRW_TAC [][FUN_EQ_THM, oneTheory.one]);

val cc_ind = save_thm(
  "cc_ind",
  (Q.GEN `P` o Q.GEN `X` o Q.GEN `R` o
   SIMP_RULE bool_ss [] o
   SPECL [``(\M:term N:term x:one. P M N:bool)``,
          ``R: term -> term -> bool``,
          ``X:string -> bool``] o
   SIMP_RULE (srw_ss()) [all_fnone, oneTheory.one] o
   INST_TYPE [alpha |-> ``:one``] o
   GEN_ALL) cc_gen_ind);

val compat_closure_permutative = store_thm(
  "compat_closure_permutative",
  ``permutative R ==> permutative (compat_closure R)``,
  STRIP_TAC THEN ASM_SIMP_TAC (srw_ss()) [permutative_def] THEN
  HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][] THEN
  METIS_TAC [permutative_def, compat_closure_rules]);

val permutative_compat_closure_eqn = store_thm(
  "permutative_compat_closure_eqn",
  ``permutative R ==>
    (compat_closure R (tpm p M) (tpm p N) = compat_closure R M N)``,
  STRIP_TAC THEN EQ_TAC THEN STRIP_TAC THENL [
    `permutative (compat_closure R)`
       by METIS_TAC [compat_closure_permutative] THEN
    `compat_closure R (tpm (REVERSE p) (tpm p M))
                      (tpm (REVERSE p) (tpm p N))`
       by METIS_TAC [permutative_def] THEN
    FULL_SIMP_TAC (srw_ss()) [],
    METIS_TAC [permutative_def, compat_closure_permutative]
  ]);
val _ = BasicProvers.export_rewrites ["permutative_compat_closure_eqn"]

val swap_eq_3substs = store_thm(
  "swap_eq_3substs",
  ``~(z IN FV M) /\ ~(x = z) /\ ~(y = z) ==>
    (tpm [(x, y)] M = [VAR y/z] ([VAR x/y] ([VAR z/x] M)))``,
  SRW_TAC [][GSYM fresh_tpm_subst] THEN
  `tpm [(x,y)] (tpm [(z,x)] M) =
       tpm [(swapstr x y z, swapstr x y x)] (tpm [(x,y)] M)`
     by (CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [GSYM tpm_sing_to_back])) THEN
         SRW_TAC [][]) THEN
  POP_ASSUM SUBST_ALL_TAC THEN
  SRW_TAC [][tpm_flip_args]);

val substitutive_implies_permutative = store_thm(
  "substitutive_implies_permutative",
  ``substitutive R ==> permutative R``,
  SRW_TAC [][substitutive_def, permutative_def] THEN
  Induct_on `p` THEN SRW_TAC [][] THEN
  `?x y. h = (x,y)` by METIS_TAC [pairTheory.pair_CASES] THEN
  SRW_TAC [][] THEN
  Q_TAC (NEW_TAC "z") `{x; y} UNION FV (tpm p M) UNION FV (tpm p M')` THEN
  `(tpm ((x,y)::p) M = [VAR y/z] ([VAR x/y] ([VAR z/x] (tpm p M)))) /\
   (tpm ((x,y)::p) M'= [VAR y/z] ([VAR x/y] ([VAR z/x] (tpm p M'))))`
      by (ONCE_REWRITE_TAC [tpm_CONS] THEN
          SRW_TAC [][swap_eq_3substs]) THEN
  ASM_SIMP_TAC (srw_ss()) []);

val compat_closure_substitutive = store_thm(
  "compat_closure_substitutive",
  ``substitutive R ==> substitutive (compat_closure R)``,
  STRIP_TAC THEN SIMP_TAC (srw_ss()) [substitutive_def] THEN
  REPEAT STRIP_TAC THEN
  Q.UNDISCH_THEN `compat_closure R M M'` MP_TAC THEN
  MAP_EVERY Q.ID_SPEC_TAC [`M'`, `M`] THEN
  HO_MATCH_MP_TAC cc_ind THEN Q.EXISTS_TAC `v INSERT FV N` THEN
  SRW_TAC [][SUB_THM] THENL [
    PROVE_TAC [substitutive_implies_permutative, permutative_def],
    PROVE_TAC [compat_closure_rules, substitutive_def],
    SRW_TAC [][compat_closure_rules],
    SRW_TAC [][compat_closure_rules],
    SRW_TAC [][compat_closure_rules]
  ]);

val _ = overload_on ("equiv_closure", ``relation$EQC``)

local
  open relationTheory
in
  val equiv_closure_rules = LIST_CONJ [EQC_R, EQC_REFL, EQC_SYM, EQC_TRANS]
  val equiv_closure_ind = EQC_INDUCTION
end

val equiv_closure_substitutive = store_thm(
  "equiv_closure_substitutive",
  ``substitutive R ==> substitutive (equiv_closure R)``,
  STRIP_TAC THEN SIMP_TAC (srw_ss()) [substitutive_def] THEN
  HO_MATCH_MP_TAC equiv_closure_ind THEN SRW_TAC [][] THEN
  METIS_TAC [substitutive_def, equiv_closure_rules]);

val conversion_def =
    Define`conversion R = equiv_closure (compat_closure R)`;

val conversion_substitutive = store_thm(
  "conversion_substitutive",
  ``substitutive R ==> substitutive (conversion R)``,
  METIS_TAC [compat_closure_substitutive, equiv_closure_substitutive,
             conversion_def]);

val RTC_substitutive = store_thm(
  "RTC_substitutive",
  ``substitutive R ==> substitutive (RTC R)``,
  STRIP_TAC THEN SIMP_TAC (srw_ss()) [substitutive_def] THEN
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  METIS_TAC [relationTheory.RTC_RULES, substitutive_def]);

val reduction_def =
    Define`reduction R = RTC (compat_closure R)`;

val reduction_substitutive = store_thm(
  "reduction_substitutive",
  ``substitutive R ==> substitutive (reduction R)``,
  METIS_TAC [compat_closure_substitutive, RTC_substitutive, reduction_def]);

val conversion_rules = store_thm(
  "conversion_rules",
  ``!R. (!x. conversion R x x) /\
        (!x y. conversion R x y ==> conversion R y x) /\
        (!x y z. conversion R x y /\ conversion R y z ==> conversion R x z) /\
        (!x y. R x y ==> conversion R x y) /\
        (!x y. reduction R x y ==> conversion R x y) /\
        (!x y. compat_closure R x y ==> conversion R x y)``,
  SRW_TAC [][equiv_closure_rules, conversion_def] THENL [
    PROVE_TAC [equiv_closure_rules],
    PROVE_TAC [equiv_closure_rules, compat_closure_rules],
    POP_ASSUM MP_TAC THEN SIMP_TAC (srw_ss()) [reduction_def] THEN
    MAP_EVERY Q.ID_SPEC_TAC [`y`,`x`] THEN
    HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
    PROVE_TAC [equiv_closure_rules]
  ]);

val compat_closure_compatible = store_thm(
  "compat_closure_compatible",
  ``!R. compatible (compat_closure R)``,
  GEN_TAC THEN
  Q_TAC SUFF_TAC `!c. one_hole_context c ==>
                      !x y. compat_closure R x y ==>
                            compat_closure R (c x) (c y)` THEN1
     SRW_TAC [][compatible_def] THEN
  HO_MATCH_MP_TAC one_hole_context_ind THEN SRW_TAC [][] THEN
  PROVE_TAC [compat_closure_rules]);

val reduction_compatible = store_thm(
  "reduction_compatible",
  ``!R. compatible (reduction R)``,
  GEN_TAC THEN
  Q_TAC SUFF_TAC `!x y. RTC (compat_closure R) x y ==>
                        !c. one_hole_context c ==>
                            RTC (compat_closure R) (c x) (c y)` THEN1
    SRW_TAC [][compatible_def, reduction_def] THEN
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN SRW_TAC [][] THENL [
    PROVE_TAC [relationTheory.RTC_RULES],
    PROVE_TAC [compatible_def, compat_closure_compatible,
               relationTheory.RTC_RULES]
  ]);

val reduction_rules = store_thm(
  "reduction_rules",
  ``(!x. reduction R x x) /\
    (!x y. R x y ==> reduction R x y) /\
    (!x y. compat_closure R x y ==> reduction R x y) /\
    (!x y z. reduction R x y /\ reduction R y z ==>
             reduction R x z) /\
    (!x y z. reduction R x y ==> reduction R (z @@ x) (z @@ y)) /\
    (!x y z. reduction R x y ==> reduction R (x @@ z) (y @@ z)) /\
    (!x y v. reduction R x y ==> reduction R (LAM v x) (LAM v y))``,
  REPEAT STRIP_TAC THENL [
    PROVE_TAC [reduction_def, relationTheory.RTC_RULES],
    PROVE_TAC [reduction_def, relationTheory.RTC_RULES, compat_closure_rules],
    PROVE_TAC [reduction_def, relationTheory.RTC_RULES],
    PROVE_TAC [reduction_def, relationTheory.RTC_RTC],
    PROVE_TAC [leftctxt, compatible_def, reduction_compatible],
    PROVE_TAC [rightctxt_thm, rightctxt, compatible_def, reduction_compatible],
    PROVE_TAC [absctxt, compatible_def, reduction_compatible]
  ]);

val conversion_compatible = store_thm(
  "conversion_compatible",
  ``!R. compatible (conversion R)``,
  GEN_TAC THEN
  Q_TAC SUFF_TAC `!x y. equiv_closure (compat_closure R) x y ==>
                        !c. one_hole_context c ==>
                            equiv_closure (compat_closure R) (c x) (c y)` THEN1
    SRW_TAC [][compatible_def, conversion_def] THEN
  HO_MATCH_MP_TAC equiv_closure_ind THEN SRW_TAC [][] THEN
  PROVE_TAC [compatible_def, equiv_closure_rules, compat_closure_compatible]);

(* "Follows from an induction on the structure of M, and the
    compatibility of reduction R" *)
val lemma3_8 = store_thm(
  "lemma3_8",
  ``!M. reduction R N N' ==> reduction R ([N/x] M) ([N'/x] M)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `x INSERT FV N UNION FV N'` THEN
  SRW_TAC [][SUB_THM, SUB_VAR] THEN PROVE_TAC [reduction_rules]);

val redex_def = Define`redex (R:'a -> 'a -> bool) t = ?u. R t u`;

val (can_reduce_rules, can_reduce_ind, can_reduce_cases) =
  Hol_reln`(!t. redex R t ==> can_reduce R t) /\
           (!M N. can_reduce R M ==> can_reduce R (M @@ N)) /\
           (!M N. can_reduce R M ==> can_reduce R (N @@ M)) /\
           (!v M. can_reduce R M ==> can_reduce R (LAM v M))`

val can_reduce_reduces = store_thm(
  "can_reduce_reduces",
  ``!R t. can_reduce R t ==> ?u. compat_closure R t u``,
  GEN_TAC THEN HO_MATCH_MP_TAC can_reduce_ind THEN SRW_TAC [][redex_def] THEN
  PROVE_TAC [compat_closure_rules]);

val normal_form_def = Define`normal_form R t = ~can_reduce R t`;

(* definition from p30 *)
val beta_def = Define`beta M N = ?x body arg. (M = LAM x body @@ arg) /\
                                              (N = [arg/x]body)`;

val beta_alt = store_thm(
  "beta_alt",
  ``!X M N. FINITE X ==>
            (beta M N = ?x body arg. (M = LAM x body @@ arg) /\
                                     (N = [arg/x] body) /\
                                     ~(x IN X))``,
  SRW_TAC [][beta_def, EQ_IMP_THM] THENL [
    SRW_TAC [][LAM_eq_thm] THEN
    Q_TAC (NEW_TAC "z") `x INSERT FV body UNION X` THEN
    MAP_EVERY Q.EXISTS_TAC [`z`, `tpm [(x,z)] body`] THEN
    SRW_TAC [][] THEN
    Q_TAC SUFF_TAC `tpm [(x,z)] body = [VAR z/x]body`
          THEN1 SRW_TAC [][lemma15a] THEN
    SRW_TAC [][GSYM fresh_tpm_subst, tpm_flip_args],
    METIS_TAC []
  ]);

val strong_bvc_term_ind = store_thm(
  "strong_bvc_term_ind",
  ``!P fv. (!s x. P (VAR s) x) /\
           (!M N x. (!x. P M x) /\ (!x. P N x) ==> P (M @@ N) x) /\
           (!v x M. ~(v IN fv x) /\ (!x. P M x) ==> P (LAM v M) x) /\
           (!x. FINITE (fv x)) ==>
           !t x. P t x``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  Q_TAC SUFF_TAC `!t p x. P (tpm p t) x` THEN1 METIS_TAC [tpm_NIL] THEN
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][] THEN
  Q.ABBREV_TAC `u = lswapstr p v` THEN
  Q.ABBREV_TAC `M = tpm p t` THEN
  Q_TAC (NEW_TAC "z") `u INSERT FV M UNION fv x` THEN
  `LAM u M = LAM z (tpm [(z, u)] M)` by SRW_TAC [][tpm_ALPHA] THEN
  `tpm [(z,u)] M = tpm ((z,u)::p) t`
     by SRW_TAC [][Abbr`M`, GSYM tpm_APPEND] THEN
  SRW_TAC [][])

val ccbeta_gen_ind = store_thm(
  "ccbeta_gen_ind",
  ``(!v M N X. ~(v IN FV N) /\ ~(v IN fv X) ==>
               P ((LAM v M) @@ N) ([N/v]M) X) /\
    (!M1 M2 N X. (!X. P M1 M2 X) ==> P (M1 @@ N) (M2 @@ N) X) /\
    (!M N1 N2 X. (!X. P N1 N2 X) ==> P (M @@ N1) (M @@ N2) X) /\
    (!v M1 M2 X. ~(v IN fv X) /\ (!X. P M1 M2 X) ==>
                 P (LAM v M1) (LAM v M2) X) /\
    (!X. FINITE (fv X)) ==>
    !M N. compat_closure beta M N ==> !X. P M N X``,
  STRIP_TAC THEN
  Q_TAC SUFF_TAC `!M N. compat_closure beta M N ==>
                        !X p. P (tpm p M) (tpm p N) X`
        THEN1 METIS_TAC [tpm_NIL] THEN
  HO_MATCH_MP_TAC compat_closure_ind THEN REPEAT STRIP_TAC THENL [
    FULL_SIMP_TAC (srw_ss()) [beta_def, tpm_subst] THEN
    Q.ABBREV_TAC `v = lswapstr p x` THEN
    Q.ABBREV_TAC `N' = tpm p arg` THEN
    Q.ABBREV_TAC `M' = tpm p body` THEN
    Q_TAC (NEW_TAC "z") `v INSERT FV M' UNION FV N' UNION fv X` THEN
    `LAM v M' = LAM z ([VAR z/v] M')` by SRW_TAC [][SIMPLE_ALPHA] THEN
    Q_TAC SUFF_TAC `[N'/v]M' = [N'/z]([VAR z/v]M')` THEN1 SRW_TAC [][] THEN
    SRW_TAC [][lemma15a],
    SRW_TAC [][],
    SRW_TAC [][],
    SRW_TAC [][] THEN
    Q.ABBREV_TAC `x = lswapstr p v` THEN
    Q.ABBREV_TAC `M' = tpm p M` THEN
    Q.ABBREV_TAC `N' = tpm p N` THEN
    Q_TAC (NEW_TAC "z") `x INSERT FV M' UNION FV N' UNION fv X` THEN
    `(LAM x M' = LAM z (tpm [(z,x)] M')) /\ (LAM x N' = LAM z (tpm[(z,x)] N'))`
       by SRW_TAC [][tpm_ALPHA] THEN
    SRW_TAC [][] THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN SRW_TAC [][] THEN
    `(tpm [(z,x)] M' = tpm ((z,x)::p) M) /\
     (tpm [(z,x)] N' = tpm ((z,x)::p) N)`
       by SRW_TAC [][Abbr`M'`, Abbr`N'`, GSYM tpm_APPEND] THEN
    SRW_TAC [][]
  ]);

val ccbeta_ind = save_thm(
  "ccbeta_ind",
  (Q.GEN `P` o Q.GEN `X` o
   SIMP_RULE bool_ss [] o
   SPECL [``X:string -> bool``, ``(\M:term N:term x:one. P M N:bool)``] o
   SIMP_RULE (srw_ss()) [all_fnone, oneTheory.one] o
   INST_TYPE [alpha |-> ``:one``] o
   GEN_ALL) ccbeta_gen_ind);

val beta_substitutive = store_thm(
  "beta_substitutive",
  ``substitutive beta``,
  SRW_TAC [][substitutive_def] THEN
  Q.SPEC_THEN `v INSERT FV N` ASSUME_TAC beta_alt THEN
  FULL_SIMP_TAC (srw_ss()) [] THEN
  Q.EXISTS_TAC `x` THEN SRW_TAC [][SUB_THM, GSYM substitution_lemma]);

val cc_beta_subst = store_thm(
  "cc_beta_subst",
  ``!M N. compat_closure beta M N ==>
          !P v. compat_closure beta ([P/v]M) ([P/v]N)``,
  METIS_TAC [beta_substitutive, compat_closure_substitutive,
             substitutive_def]);

val reduction_beta_subst = store_thm(
  "reduction_beta_subst",
  ``!M N. reduction beta M N ==>
          !P v. reduction beta ([P/v]M) ([P/v]N)``,
  METIS_TAC [beta_substitutive, reduction_substitutive, substitutive_def]);

val cc_beta_FV_SUBSET = store_thm(
  "cc_beta_FV_SUBSET",
  ``!M N. compat_closure beta M N ==> FV N SUBSET FV M``,
  HO_MATCH_MP_TAC ccbeta_ind THEN Q.EXISTS_TAC `{}` THEN
  SRW_TAC [][SUBSET_DEF, FV_SUB] THEN PROVE_TAC []);

val cc_beta_tpm = store_thm(
  "cc_beta_tpm",
  ``!M N. compat_closure beta M N ==>
          !p. compat_closure beta (tpm p M) (tpm p N)``,
  HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][] THENL [
    FULL_SIMP_TAC (srw_ss()) [beta_def, tpm_subst] THEN
    METIS_TAC [compat_closure_rules, beta_def],
    METIS_TAC [compat_closure_rules],
    METIS_TAC [compat_closure_rules],
    METIS_TAC [compat_closure_rules]
  ]);

val cc_beta_tpm_eqn = store_thm(
  "cc_beta_tpm_eqn",
  ``compat_closure beta (tpm pi M) N =
    compat_closure beta M (tpm (REVERSE pi) N)``,
  METIS_TAC [tpm_inverse, cc_beta_tpm]);

val cc_beta_thm = store_thm(
  "cc_beta_thm",
  ``(!s t. compat_closure beta (VAR s) t = F) /\
    (!M N P. compat_closure beta (M @@ N) P =
               (?v M0. (M = LAM v M0) /\ (P = [N/v]M0)) \/
               (?M'. (P = M' @@ N) /\ compat_closure beta M M') \/
               (?N'. (P = M @@ N') /\ compat_closure beta N N')) /\
    (!v M N.
               compat_closure beta (LAM v M) N =
               ?N0. (N = LAM v N0) /\ compat_closure beta M N0)``,
  CONV_TAC (EVERY_CONJ_CONV
            (STRIP_QUANT_CONV
               (LAND_CONV (ONCE_REWRITE_CONV [compat_closure_cases])))) THEN
  SIMP_TAC (srw_ss()) [beta_def] THEN REPEAT STRIP_TAC THEN EQ_TAC THEN
  SRW_TAC [][] THEN SRW_TAC [][] THENL [
    PROVE_TAC [],
    PROVE_TAC [],
    REPEAT (POP_ASSUM MP_TAC) THEN
    Q_TAC SUFF_TAC
          `!v w M N P.
                 (LAM v M = LAM w N) ==>
                 compat_closure beta N P ==>
                 ?M0. (LAM w P = LAM v M0) /\
                      compat_closure beta M M0` THEN1 PROVE_TAC [] THEN
    SRW_TAC [][LAM_eq_thm] THEN Q.EXISTS_TAC `tpm [(v,w)] P` THEN
    SRW_TAC [][tpm_flip_args, cc_beta_tpm_eqn] THEN
    METIS_TAC [cc_beta_FV_SUBSET, SUBSET_DEF],
    PROVE_TAC []
  ]);

val beta_normal_form_bnf = store_thm(
  "beta_normal_form_bnf",
  ``normal_form beta = bnf``,
  SIMP_TAC (srw_ss()) [FUN_EQ_THM, EQ_IMP_THM, normal_form_def,
                       FORALL_AND_THM] THEN
  CONJ_TAC THENL [
    Q_TAC SUFF_TAC `!t. ~bnf t ==> can_reduce beta t` THEN1 PROVE_TAC [] THEN
    HO_MATCH_MP_TAC nc_INDUCTION2 THEN
    Q.EXISTS_TAC `{}` THEN SRW_TAC [][] THENL [
      PROVE_TAC [can_reduce_rules],
      PROVE_TAC [can_reduce_rules],
      Q_TAC SUFF_TAC `redex beta (t @@ t')` THEN1
            PROVE_TAC [can_reduce_rules] THEN
      SRW_TAC [][redex_def, beta_def] THEN PROVE_TAC [is_abs_thm, term_CASES],
      PROVE_TAC [lemma14a, can_reduce_rules]
    ],
    Q_TAC SUFF_TAC `!t. can_reduce beta t ==> ~bnf t` THEN1 PROVE_TAC [] THEN
    HO_MATCH_MP_TAC can_reduce_ind THEN SRW_TAC [][redex_def, beta_def] THEN
    SRW_TAC [][]
  ]);

val nf_of_def = Define`nf_of R M N = normal_form R N /\ conversion R M N`;

val prop3_10 = store_thm(
  "prop3_10",
  ``!R M N.
       compat_closure R M N = ?P Q c. one_hole_context c /\ (M = c P) /\
                                      (N = c Q) /\ R P Q``,
  GEN_TAC THEN SIMP_TAC (srw_ss()) [EQ_IMP_THM, FORALL_AND_THM] THEN
  CONJ_TAC THENL [
    HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][] THENL [
      MAP_EVERY Q.EXISTS_TAC [`M`,`N`,`\x.x`] THEN
      SRW_TAC [][one_hole_context_rules],
      MAP_EVERY Q.EXISTS_TAC [`P`,`Q`,`\t. z @@ c t`] THEN
      SRW_TAC [][one_hole_context_rules],
      MAP_EVERY Q.EXISTS_TAC [`P`,`Q`,`\t. c t @@ z`] THEN
      SRW_TAC [][one_hole_context_rules],
      MAP_EVERY Q.EXISTS_TAC [`P`,`Q`,`\t. LAM v (c t)`] THEN
      SRW_TAC [][one_hole_context_rules]
    ],
    PROVE_TAC [compat_closure_compatible, compatible_def,
               compat_closure_rules]
  ]);

val corollary3_2_1 = store_thm(
  "corollary3_2_1",
  ``!R M. normal_form R M ==> (!N. ~compat_closure R M N) /\
                              (!N. reduction R M N ==> (M = N))``,
  SIMP_TAC (srw_ss()) [normal_form_def] THEN REPEAT GEN_TAC THEN
  STRIP_TAC THEN
  Q.SUBGOAL_THEN `!N. ~compat_closure R M N` ASSUME_TAC THENL [
    GEN_TAC THEN POP_ASSUM MP_TAC THEN
    CONV_TAC CONTRAPOS_CONV THEN SIMP_TAC (srw_ss())[] THEN
    MAP_EVERY Q.ID_SPEC_TAC [`N`, `M`] THEN
    HO_MATCH_MP_TAC compat_closure_ind THEN
    PROVE_TAC [can_reduce_rules, redex_def],
    ALL_TAC
  ] THEN ASM_SIMP_TAC (srw_ss()) [reduction_def] THEN
  PROVE_TAC [relationTheory.RTC_CASES1]);

local open relationTheory
in
val diamond_property_def = save_thm("diamond_property_def", diamond_def)
end
val _ = overload_on("diamond_property", ``relation$diamond``)

(* This is not the same CR as appears in relationTheory.  There
     CR R = diamond (RTC R)
   Here,
     CR R = diamond (RTC (compat_closure R))
   In other words, this formulation allows us to write
     CR beta
   rather than having to write
     CR (compat_closure beta)
*)
val CR_def = Define`CR R = diamond_property (reduction R)`;

val theorem3_13 = store_thm(
  "theorem3_13",
  ``!R. CR R ==>
        !M N. conversion R M N ==> ?Z. reduction R M Z /\ reduction R N Z``,
  GEN_TAC THEN STRIP_TAC THEN SIMP_TAC (srw_ss()) [conversion_def] THEN
  HO_MATCH_MP_TAC equiv_closure_ind THEN REVERSE (SRW_TAC [][]) THEN1
    (`?Z2. reduction R Z Z2 /\ reduction R Z' Z2` by
        PROVE_TAC [CR_def, diamond_property_def] THEN
     PROVE_TAC [reduction_rules]) THEN
  PROVE_TAC [reduction_rules]);

val corollary3_3_1 = store_thm(
  "corollary3_3_1",
  ``!R. CR R ==> (!M N. nf_of R M N ==> reduction R M N) /\
                 (!M N1 N2. nf_of R M N1 /\ nf_of R M N2 ==> (N1 = N2))``,
  SRW_TAC [][nf_of_def] THENL [
    PROVE_TAC [corollary3_2_1, theorem3_13],
    `conversion R N1 N2` by
       (FULL_SIMP_TAC (srw_ss()) [conversion_def] THEN
        PROVE_TAC [equiv_closure_rules]) THEN
    `?Z. reduction R N1 Z /\ reduction R N2 Z` by
       PROVE_TAC [theorem3_13] THEN
    PROVE_TAC [corollary3_2_1]
  ]);

val diamond_TC = relationTheory.diamond_TC_diamond

val (grandbeta_rules, grandbeta_ind, grandbeta_cases) =
    Hol_reln`(!M. grandbeta M M) /\
             (!M M' x. grandbeta M M' ==> grandbeta (LAM x M) (LAM x M')) /\
             (!M N M' N'. grandbeta M M' /\ grandbeta N N' ==>
                          grandbeta (M @@ N) (M' @@ N')) /\
             (!M N M' N' x. grandbeta M M' /\ grandbeta N N' ==>
                            grandbeta ((LAM x M) @@ N) ([N'/x] M'))`;

val grandbeta_bvc_gen_ind = store_thm(
  "grandbeta_bvc_gen_ind",
  ``!P fv.
        (!M x. P M M x) /\
        (!v M1 M2 x. ~(v IN fv x) /\ (!x. P M1 M2 x) ==>
                     P (LAM v M1) (LAM v M2) x) /\
        (!M1 M2 N1 N2 x. (!x. P M1 M2 x) /\ (!x. P N1 N2 x) ==>
                         P (M1 @@ N1) (M2 @@ N2) x) /\
        (!M1 M2 N1 N2 v x.
                  ~(v IN fv x) /\ ~(v IN FV N1) /\ ~(v IN FV N2) /\
                  (!x. P M1 M2 x) /\ (!x. P N1 N2 x) ==>
                  P ((LAM v M1) @@ N1) ([N2/v]M2) x) /\
        (!x. FINITE (fv x)) ==>
        !M N. grandbeta M N ==> !x. P M N x``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  Q_TAC SUFF_TAC `!M N. grandbeta M N ==> !p x. P (tpm p M) (tpm p N) x`
        THEN1 METIS_TAC [tpm_NIL] THEN
  HO_MATCH_MP_TAC grandbeta_ind THEN SRW_TAC [][] THENL [
    Q.ABBREV_TAC `M' = tpm p M` THEN
    Q.ABBREV_TAC `N' = tpm p N` THEN
    Q.ABBREV_TAC `v = lswapstr p x` THEN
    Q_TAC (NEW_TAC "z") `v INSERT fv x' UNION FV M' UNION FV N'` THEN
    `(LAM v M' = LAM z (tpm ((z,v)::p) M)) /\
     (LAM v N' = LAM z (tpm ((z,v)::p) N))`
       by (ONCE_REWRITE_TAC [tpm_CONS] THEN
           SRW_TAC [][Abbr`M'`, Abbr`N'`, tpm_ALPHA]) THEN
    SRW_TAC [][],
    SRW_TAC [][tpm_subst] THEN
    Q.ABBREV_TAC `v = lswapstr p x` THEN
    Q.ABBREV_TAC `M1 = tpm p M` THEN
    Q.ABBREV_TAC `N1 = tpm p M'` THEN
    Q.ABBREV_TAC `M2 = tpm p N'` THEN
    Q.ABBREV_TAC `N2 = tpm p N''` THEN
    Q_TAC (NEW_TAC "z")
          `v INSERT fv x' UNION FV N1 UNION FV N2 UNION FV M1 UNION FV M2` THEN
    `LAM v M1 = LAM z (tpm [(z,v)] M1)` by SRW_TAC [][tpm_ALPHA] THEN
    `[N2/v]M2 = [N2/z](tpm [(z,v)] M2)`
       by SRW_TAC [][fresh_tpm_subst, lemma15a] THEN
    SRW_TAC [][] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
    SRW_TAC [][Abbr`N1`,Abbr`N2`] THEN
    `(tpm [(z,v)] M1 = tpm ((z,v)::p) M) /\
     (tpm [(z,v)] M2 = tpm ((z,v)::p) N')`
        by SRW_TAC [][GSYM tpm_APPEND, Abbr`M1`,Abbr`M2`] THEN
    SRW_TAC [][]
  ]);

val grandbeta_bvc_ind = save_thm(
  "grandbeta_bvc_ind",
  (Q.GEN `P` o Q.GEN `X` o
   SIMP_RULE bool_ss [] o
   SPECL [``(\M:term N:term x:one. P M N:bool)``, ``X:string -> bool``] o
   SIMP_RULE (srw_ss()) [all_fnone, oneTheory.one] o
   INST_TYPE [alpha |-> ``:one``])
  grandbeta_bvc_gen_ind);

val exercise3_3_1 = store_thm(
  "exercise3_3_1",
  ``!M N. compat_closure beta M N ==> grandbeta M N``,
  HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][beta_def] THEN
  PROVE_TAC [grandbeta_rules]);

val app_grandbeta = store_thm(  (* property 3 on p. 37 *)
  "app_grandbeta",
  ``!M N L. grandbeta (M @@ N) L =
               (?M' N'. grandbeta M M' /\ grandbeta N N' /\ (L = M' @@ N')) \/
               (?x P P' N'. (M = LAM x P) /\ grandbeta P P' /\
                            grandbeta N N' /\ (L = [N'/x]P'))``,
  REPEAT GEN_TAC THEN EQ_TAC THENL [
    CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [grandbeta_cases])) THEN
    SIMP_TAC (srw_ss()) [DISJ_IMP_THM, GSYM LEFT_FORALL_IMP_THM,
                         grandbeta_rules] THEN PROVE_TAC [],
    SRW_TAC [][] THEN PROVE_TAC [grandbeta_rules]
  ]);


val grandbeta_permutative = store_thm(
  "grandbeta_permutative",
  ``!M N. grandbeta M N ==> !pi. grandbeta (tpm pi M) (tpm pi N)``,
  HO_MATCH_MP_TAC grandbeta_ind THEN SRW_TAC [][tpm_subst] THEN
  METIS_TAC [grandbeta_rules]);

val grandbeta_permutative_eqn = store_thm(
  "grandbeta_permutative_eqn",
  ``grandbeta (tpm pi M) (tpm pi N) = grandbeta M N``,
  METIS_TAC [tpm_inverse, grandbeta_permutative]);
val _ = BasicProvers.export_rewrites ["grandbeta_permutative_eqn"]

val grandbeta_substitutive = store_thm(
  "grandbeta_substitutive",
  ``!M N. grandbeta M N ==> grandbeta ([P/x]M) ([P/x]N)``,
  HO_MATCH_MP_TAC grandbeta_bvc_ind THEN
  Q.EXISTS_TAC `x INSERT FV P` THEN
  SRW_TAC [][SUB_THM, grandbeta_rules] THEN
  SRW_TAC [][lemma2_11, grandbeta_rules]);

val grandbeta_FV = store_thm(
  "grandbeta_FV",
  ``!M N. grandbeta M N ==> FV N SUBSET FV M``,
  HO_MATCH_MP_TAC grandbeta_ind THEN
  SRW_TAC [][SUBSET_DEF, FV_SUB] THEN
  PROVE_TAC []);

val abs_grandbeta = store_thm(
  "abs_grandbeta",
  ``!M N v. grandbeta (LAM v M) N = ?N0. (N = LAM v N0) /\ grandbeta M N0``,
  REPEAT GEN_TAC THEN EQ_TAC THENL [
    CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [grandbeta_cases])) THEN
    SIMP_TAC (srw_ss()) [DISJ_IMP_THM, grandbeta_rules] THEN
    SRW_TAC [][LAM_eq_thm] THENL [
      PROVE_TAC [],
      SRW_TAC [][LAM_eq_thm] THEN
      Q.EXISTS_TAC `tpm [(v,x)] M''` THEN SRW_TAC [][tpm_flip_args] THEN
      PROVE_TAC [SUBSET_DEF, grandbeta_FV]
    ],
    PROVE_TAC [grandbeta_rules]
  ]);

val lemma3_15 = save_thm("lemma3_15", abs_grandbeta);

val redex_grandbeta = store_thm(
  "redex_grandbeta",
  ``grandbeta (LAM v M @@ N) L =
        (?M' N'. grandbeta M M' /\ grandbeta N N' /\
                 (L = LAM v M' @@ N')) \/
        (?M' N'. grandbeta M M' /\ grandbeta N N' /\ (L = [N'/v]M'))``,
  SRW_TAC [][app_grandbeta, EQ_IMP_THM] THENL [
    PROVE_TAC [abs_grandbeta],
    FULL_SIMP_TAC (srw_ss()) [LAM_eq_thm] THEN DISJ2_TAC THENL [
      METIS_TAC [],
      SRW_TAC [][] THEN
      MAP_EVERY Q.EXISTS_TAC [`tpm [(v,x)] P'`, `N'`] THEN
      SRW_TAC [][] THEN
      `~(v IN FV P')`
        by METIS_TAC [grandbeta_FV, SUBSET_DEF] THEN
      SRW_TAC [][fresh_tpm_subst, lemma15a]
    ],
    METIS_TAC [grandbeta_rules],
    METIS_TAC []
  ]);

val var_grandbeta = store_thm(
  "var_grandbeta",
  ``!v N. grandbeta (VAR v) N = (N = VAR v)``,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC [grandbeta_cases] THEN
  SRW_TAC [][]);

val grandbeta_cosubstitutive = store_thm(
  "grandbeta_cosubstitutive",
  ``!M. grandbeta N N' ==> grandbeta ([N/x] M) ([N'/x] M)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `x INSERT FV N UNION FV N'` THEN
  SRW_TAC [][SUB_THM, grandbeta_rules, SUB_VAR]);

(* property 1 on p37, and Barendregt's lemma 3.2.4 *)
val grandbeta_subst = store_thm(
  "grandbeta_subst",
  ``grandbeta M M' /\ grandbeta N N' ==> grandbeta ([N/x]M) ([N'/x]M')``,
  Q_TAC SUFF_TAC
        `!M M'. grandbeta M M' ==> grandbeta N N' ==>
                grandbeta ([N/x] M) ([N'/x]M')` THEN1
        METIS_TAC [] THEN
  HO_MATCH_MP_TAC grandbeta_bvc_ind THEN
  Q.EXISTS_TAC `x INSERT FV N UNION FV N'` THEN
  SRW_TAC [][SUB_THM, grandbeta_rules] THENL [
    METIS_TAC [grandbeta_cosubstitutive],
    RES_TAC THEN
    SRW_TAC [][lemma2_11, grandbeta_rules]
  ]);

val strong_grandbeta_ind =
    IndDefRules.derive_strong_induction (grandbeta_rules, grandbeta_ind)

val strong_grandbeta_bvc_gen_ind =
    (GEN_ALL o
     SIMP_RULE (srw_ss()) [grandbeta_rules, FORALL_AND_THM,
                           GSYM CONJ_ASSOC] o
     Q.SPEC `\M N x. P M N x /\ grandbeta M N`)
    grandbeta_bvc_gen_ind

val lemma3_16 = store_thm( (* p. 37 *)
  "lemma3_16",
  ``diamond_property grandbeta``,
  Q_TAC SUFF_TAC `!M M1. grandbeta M M1 ==>
                         !M2. grandbeta M M2 ==>
                              ?M3. grandbeta M1 M3 /\ grandbeta M2 M3` THEN1
    PROVE_TAC [diamond_property_def] THEN
  HO_MATCH_MP_TAC strong_grandbeta_bvc_gen_ind THEN Q.EXISTS_TAC `FV` THEN
  SIMP_TAC (srw_ss()) [] THEN REPEAT CONJ_TAC THENL [
    (* reflexive case *)
    PROVE_TAC [grandbeta_rules],
    (* lambda case *)
    MAP_EVERY Q.X_GEN_TAC [`v`, `M`,`M1`, `M2`] THEN REPEAT STRIP_TAC THEN
    `?P. (M2 = LAM v P) /\ grandbeta M P` by PROVE_TAC [abs_grandbeta] THEN
    SRW_TAC [][] THEN PROVE_TAC [grandbeta_rules],
    (* app case *)
    MAP_EVERY Q.X_GEN_TAC [`f`,`g`,`x`,`y`, `fx'`] THEN STRIP_TAC THEN
    STRIP_TAC THEN
    `(?f' x'. (fx' = f' @@ x') /\ grandbeta f f' /\ grandbeta x x') \/
     (?v P P' x'. (f = LAM v P) /\ grandbeta P P' /\ grandbeta x x' /\
                  (fx' = [x'/v]P'))` by
        (FULL_SIMP_TAC (srw_ss()) [app_grandbeta] THEN PROVE_TAC [])
    THENL [
      METIS_TAC [grandbeta_rules],
      `?P2. (g = LAM v P2) /\ grandbeta P P2` by
          PROVE_TAC [abs_grandbeta] THEN
      SRW_TAC [][] THEN
      `?ff. grandbeta (LAM v P2) ff /\ grandbeta (LAM v P') ff` by
         PROVE_TAC [grandbeta_rules] THEN
      `?xx. grandbeta y xx /\ grandbeta x' xx` by PROVE_TAC [] THEN
      `?PP. grandbeta P' PP /\ (ff = LAM v PP)` by
         PROVE_TAC [abs_grandbeta] THEN
      SRW_TAC [][] THEN
      `grandbeta P2 PP` by PROVE_TAC [abs_grandbeta, term_11] THEN
      PROVE_TAC [grandbeta_rules, grandbeta_subst]
    ],
    (* beta-redex case *)
    MAP_EVERY Q.X_GEN_TAC [`M`, `M'`, `N`, `N'`, `x`, `M2`] THEN
    SRW_TAC [][redex_grandbeta] THENL [
      (* other reduction didn't beta-reduce *)
      `?Mfin. grandbeta M' Mfin /\ grandbeta M'' Mfin` by METIS_TAC [] THEN
      `?Nfin. grandbeta N' Nfin /\ grandbeta N'' Nfin` by METIS_TAC [] THEN
      Q.EXISTS_TAC `[Nfin/x]Mfin` THEN
      METIS_TAC [grandbeta_rules, grandbeta_subst],
      (* other reduction also beta-reduced *)
      `?Mfin. grandbeta M' Mfin /\ grandbeta M'' Mfin` by METIS_TAC [] THEN
      `?Nfin. grandbeta N' Nfin /\ grandbeta N'' Nfin` by METIS_TAC [] THEN
      Q.EXISTS_TAC `[Nfin/x]Mfin` THEN
      METIS_TAC [grandbeta_rules, grandbeta_subst]
    ]
  ]);

val theorem3_17 = store_thm(
  "theorem3_17",
  ``TC grandbeta = reduction beta``,
  Q_TAC SUFF_TAC
    `(!M N. TC grandbeta M N ==> reduction beta M N) /\
     (!M N. RTC (compat_closure beta) M N ==> TC grandbeta M N)`
    THEN1 SRW_TAC [] [reduction_def, FUN_EQ_THM, EQ_IMP_THM] THEN
  CONJ_TAC THENL [
    Q_TAC SUFF_TAC `!M N. grandbeta M N ==> reduction beta M N`
      THEN1 (REWRITE_TAC [reduction_def] THEN
             PROVE_TAC [relationTheory.TC_IDEM, relationTheory.TC_RC_EQNS,
                        relationTheory.TC_MONOTONE]) THEN
    HO_MATCH_MP_TAC grandbeta_ind THEN PROVE_TAC [reduction_rules, beta_def],

    Q_TAC SUFF_TAC `!M N. RC (compat_closure beta) M N ==> grandbeta M N`
      THEN1 PROVE_TAC [relationTheory.TC_MONOTONE,
                       relationTheory.TC_RC_EQNS] THEN
    Q_TAC SUFF_TAC `!M N. compat_closure beta M N ==> grandbeta M N`
      THEN1 PROVE_TAC [relationTheory.RC_DEF, grandbeta_rules] THEN
    PROVE_TAC [exercise3_3_1]
  ]);

val beta_CR = store_thm(
  "beta_CR",
  ``CR beta``,
  PROVE_TAC [CR_def, lemma3_16, theorem3_17, diamond_TC]);

val lameq_betaconversion = store_thm(
  "lameq_betaconversion",
  ``!M N. M == N = conversion beta M N``,
  SIMP_TAC (srw_ss()) [EQ_IMP_THM, FORALL_AND_THM] THEN CONJ_TAC THENL [
    HO_MATCH_MP_TAC lam_eq_indn THEN REPEAT STRIP_TAC THENL [
      Q_TAC SUFF_TAC `beta (LAM x M @@ N) ([N/x] M)` THEN1
        PROVE_TAC [conversion_rules] THEN
      SRW_TAC [][beta_def] THEN PROVE_TAC [],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_compatible, compatible_def, rightctxt,
                 rightctxt_thm],
      PROVE_TAC [conversion_compatible, compatible_def, leftctxt],
      PROVE_TAC [conversion_compatible, compatible_def, absctxt]
    ],
    SIMP_TAC (srw_ss()) [conversion_def] THEN
    HO_MATCH_MP_TAC equiv_closure_ind THEN REPEAT CONJ_TAC THEN1
      (HO_MATCH_MP_TAC compat_closure_ind THEN SRW_TAC [][beta_def] THEN
       PROVE_TAC [lam_eq_rules]) THEN
    PROVE_TAC [lam_eq_rules]
  ]);

val prop3_18 = save_thm("prop3_18", lameq_betaconversion);

val lameq_consistent = store_thm(
  "lameq_consistent",
  ``consistent $==``,
  SRW_TAC [][consistent_def] THEN
  MAP_EVERY Q.EXISTS_TAC [`S`,`K`] THEN STRIP_TAC THEN
  `conversion beta S K` by PROVE_TAC [prop3_18] THEN
  `?Z. reduction beta S Z /\ reduction beta K Z` by
     PROVE_TAC [theorem3_13, beta_CR] THEN
  `normal_form beta S` by PROVE_TAC [S_beta_normal, beta_normal_form_bnf] THEN
  `normal_form beta K` by PROVE_TAC [K_beta_normal, beta_normal_form_bnf] THEN
  `S = K` by PROVE_TAC [corollary3_2_1] THEN
  FULL_SIMP_TAC (srw_ss()) [S_def, K_def]);

val weak_diamond_def =
    save_thm("weak_diamond_def", relationTheory.WCR_def)
val _ = overload_on("weak_diamond", ``relation$WCR``)

(* likewise, these definitions of WCR and SN, differ from those in
   relation by wrapping the argument in a call to compat_closure
*)
val WCR_def = (* definition 3.20, p39 *) Define`
  WCR R = weak_diamond (compat_closure R)
`;

val SN_def = Define`SN R = relation$SN (compat_closure R)`;

val EXTEND_RTC_TC = relationTheory.EXTEND_RTC_TC

val newmans_lemma = store_thm( (* lemma3_22, p39 *)
  "newmans_lemma",
  ``!R. SN R /\ WCR R ==> CR R``,
  SIMP_TAC (srw_ss()) [SN_def, WCR_def, relationTheory.Newmans_lemma,
                       CR_def, reduction_def,
                       GSYM relationTheory.diamond_def,
                       GSYM relationTheory.CR_def]);

val commute_def =  (* p43 *)
    Define`commute R1 R2 = !x x1 x2. R1 x x1 /\ R2 x x2 ==>
                                     ?x3. R2 x1 x3 /\ R1 x2 x3`;

val commute_COMM = store_thm(
  "commute_COMM",
  ``commute R1 R2 = commute R2 R1``,
  PROVE_TAC [commute_def]);

val diamond_RC = relationTheory.diamond_RC_diamond
  (* |- !R. diamond_property R ==> diamond_property (RC R) *)

val diamond_RTC = store_thm(
  "diamond_RTC",
  ``!R. diamond_property R ==> diamond_property (RTC R)``,
  PROVE_TAC [diamond_TC, diamond_RC, relationTheory.TC_RC_EQNS]);

fun CONJ1_TAC f (asl, w) = let
  val (c1, c2) = dest_conj w
in
  SUBGOAL_THEN c1 (fn th => CONJ_TAC THENL [ACCEPT_TAC th, ASSUME_TAC (f th)])
end (asl, w)

val hr_lemma0 = prove(
  ``!R1 R2. diamond_property R1 /\ diamond_property R2 /\ commute R1 R2 ==>
            diamond_property (RTC (R1 RUNION R2))``,
  REPEAT STRIP_TAC THEN
  Q_TAC SUFF_TAC `diamond_property (R1 RUNION R2)` THEN1
        PROVE_TAC [diamond_RTC] THEN
  FULL_SIMP_TAC (srw_ss()) [diamond_property_def, commute_def,
                            relationTheory.RUNION] THEN
  PROVE_TAC []);

val RUNION_RTC_MONOTONE = store_thm(
  "RUNION_RTC_MONOTONE",
  ``!R1 x y. RTC R1 x y ==> !R2. RTC (R1 RUNION R2) x y``,
  GEN_TAC THEN HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  PROVE_TAC [relationTheory.RTC_RULES, relationTheory.RUNION]);

val RUNION_COMM = relationTheory.RUNION_COMM

val RTC_OUT = store_thm(
  "RTC_OUT",
  ``!R1 R2. RTC (RTC R1 RUNION RTC R2) = RTC (R1 RUNION R2)``,
  REPEAT GEN_TAC THEN
  Q_TAC SUFF_TAC
    `(!x y. RTC (RTC R1 RUNION RTC R2) x y ==> RTC (R1 RUNION R2) x y) /\
     (!x y. RTC (R1 RUNION R2) x y ==> RTC (RTC R1 RUNION RTC R2) x y)` THEN1
    (SIMP_TAC (srw_ss()) [FUN_EQ_THM, EQ_IMP_THM, FORALL_AND_THM] THEN
     PROVE_TAC []) THEN CONJ_TAC
  THEN HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THENL [
    CONJ_TAC THENL [
      PROVE_TAC [relationTheory.RTC_RULES],
      MAP_EVERY Q.X_GEN_TAC [`x`,`y`,`z`] THEN REPEAT STRIP_TAC THEN
      `RTC R1 x y \/ RTC R2 x y` by PROVE_TAC [relationTheory.RUNION] THEN
      PROVE_TAC [RUNION_RTC_MONOTONE, relationTheory.RTC_RTC, RUNION_COMM]
    ],
    CONJ_TAC THENL [
      PROVE_TAC [relationTheory.RTC_RULES],
      MAP_EVERY Q.X_GEN_TAC [`x`,`y`,`z`] THEN REPEAT STRIP_TAC THEN
      `R1 x y \/ R2 x y` by PROVE_TAC [relationTheory.RUNION] THEN
      PROVE_TAC [relationTheory.RTC_RULES, relationTheory.RUNION]
    ]
  ]);


val CC_RUNION_MONOTONE = store_thm(
  "CC_RUNION_MONOTONE",
  ``!R1 x y. compat_closure R1 x y ==> compat_closure (R1 RUNION R2) x y``,
  GEN_TAC THEN HO_MATCH_MP_TAC compat_closure_ind THEN
  PROVE_TAC [compat_closure_rules, relationTheory.RUNION]);

val CC_RUNION_DISTRIB = store_thm(
  "CC_RUNION_DISTRIB",
  ``!R1 R2. compat_closure (R1 RUNION R2) =
            compat_closure R1 RUNION compat_closure R2``,
  REPEAT GEN_TAC THEN
  Q_TAC SUFF_TAC
     `(!x y. compat_closure (R1 RUNION R2) x y ==>
             (compat_closure R1 RUNION compat_closure R2) x y) /\
      (!x y. (compat_closure R1 RUNION compat_closure R2) x y ==>
             compat_closure (R1 RUNION R2) x y)` THEN1
     SIMP_TAC (srw_ss()) [FUN_EQ_THM, EQ_IMP_THM, FORALL_AND_THM] THEN
  CONJ_TAC THENL [
    HO_MATCH_MP_TAC compat_closure_ind THEN
    PROVE_TAC [compat_closure_rules, relationTheory.RUNION],
    SRW_TAC [][relationTheory.RUNION] THEN
    PROVE_TAC [RUNION_COMM, CC_RUNION_MONOTONE]
  ]);

val hindley_rosen_lemma = store_thm( (* p43 *)
  "hindley_rosen_lemma",
  ``(!R1 R2. diamond_property R1 /\ diamond_property R2 /\ commute R1 R2 ==>
             diamond_property (RTC (R1 RUNION R2))) /\
    (!R1 R2. CR R1 /\ CR R2 /\ commute (reduction R1) (reduction R2) ==>
             CR (R1 RUNION R2))``,
  CONJ_TAC THENL [
    MATCH_ACCEPT_TAC hr_lemma0,
    SRW_TAC [][CR_def, reduction_def] THEN
    `diamond_property (RTC (RTC (compat_closure R1) RUNION
                            RTC (compat_closure R2)))`
        by PROVE_TAC [hr_lemma0] THEN
    FULL_SIMP_TAC (srw_ss()) [RTC_OUT, CC_RUNION_DISTRIB]
  ]);

val eta_def =
    Define`eta M N = ?v. (M = LAM v (N @@ VAR v)) /\ ~(v IN FV N)`;

val eta_normal_form_enf = store_thm(
  "eta_normal_form_enf",
  ``normal_form eta = enf``,
  Q_TAC SUFF_TAC `(!x. ~enf x ==> can_reduce eta x) /\
                  (!x. can_reduce eta x ==> ~enf x)` THEN1
    (SIMP_TAC (srw_ss())[normal_form_def, FUN_EQ_THM, EQ_IMP_THM,
                         FORALL_AND_THM] THEN PROVE_TAC []) THEN
  CONJ_TAC THENL [
    HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `{}` THEN
    SRW_TAC [][] THENL [
      PROVE_TAC [can_reduce_rules],
      PROVE_TAC [can_reduce_rules],
      PROVE_TAC [can_reduce_rules, lemma14a],
      Q_TAC SUFF_TAC `?u. eta (LAM y x) u` THEN1
            PROVE_TAC [can_reduce_rules, redex_def] THEN
      FULL_SIMP_TAC (srw_ss()) [is_comb_APP_EXISTS, eta_def] THEN
      SRW_TAC [][] THEN
      FULL_SIMP_TAC (srw_ss()) [rand_thm, rator_thm] THEN PROVE_TAC []
    ],
    HO_MATCH_MP_TAC can_reduce_ind THEN
    SRW_TAC [][redex_def, eta_def] THEN
    SRW_TAC [][]
  ]);

val no_eta_thm = store_thm(
  "no_eta_thm",
  ``(!s t. ~(eta (VAR s) t)) /\
    (!t u v. ~(eta (t @@ u) v))``,
  SRW_TAC [][eta_def]);

val cc_eta_thm = store_thm(
  "cc_eta_thm",
  ``(!s t. compat_closure eta (VAR s) t = F) /\
    (!t u v. compat_closure eta (t @@ u) v =
             (?t'. (v = t' @@ u) /\ compat_closure eta t t') \/
             (?u'. (v = t @@ u') /\ compat_closure eta u u'))``,
  CONV_TAC (EVERY_CONJ_CONV
              (STRIP_QUANT_CONV
                 (LAND_CONV (ONCE_REWRITE_CONV [compat_closure_cases])))) THEN
  SIMP_TAC (srw_ss()) [no_eta_thm, EQ_IMP_THM, DISJ_IMP_THM,
                       GSYM LEFT_FORALL_IMP_THM, RIGHT_AND_OVER_OR,
                       LEFT_AND_OVER_OR, FORALL_AND_THM,
                       is_comb_APP_EXISTS, GSYM LEFT_EXISTS_AND_THM]);

val eta_substitutive = store_thm(
  "eta_substitutive",
  ``substitutive eta``,
  SRW_TAC [][substitutive_def, eta_def] THEN
  Q_TAC (NEW_TAC "z") `{v;v'} UNION FV M' UNION FV N` THEN
  `LAM v (M' @@ VAR v) = LAM z ([VAR z/v] (M' @@ VAR v))`
     by SRW_TAC [][SIMPLE_ALPHA] THEN
  ` _ = LAM z ([VAR z/v] M' @@ VAR z)` by SRW_TAC [][SUB_THM] THEN
  ASM_SIMP_TAC (srw_ss()) [SUB_THM, lemma14b] THEN
  Q.EXISTS_TAC `z` THEN SRW_TAC [][FV_SUB]);

val cc_eta_subst = store_thm(
  "cc_eta_subst",
  ``!M N. compat_closure eta M N ==>
          !P v. compat_closure eta ([P/v] M) ([P/v] N)``,
  METIS_TAC [eta_substitutive, compat_closure_substitutive, substitutive_def]);

val cc_eta_tpm = store_thm(
  "cc_eta_tpm",
  ``!M N. compat_closure eta M N ==>
          compat_closure eta (tpm pi M) (tpm pi N)``,
  METIS_TAC [compat_closure_permutative, substitutive_implies_permutative,
             eta_substitutive, permutative_def])
val cc_eta_tpm_eqn = store_thm(
  "cc_eta_tpm_eqn",
  ``compat_closure eta (tpm pi M) N =
    compat_closure eta M (tpm (REVERSE pi) N)``,
  METIS_TAC [cc_eta_tpm, tpm_inverse]);

val eta_deterministic = store_thm(
  "eta_deterministic",
  ``!M N1 N2. eta M N1 /\ eta M N2 ==> (N1 = N2)``,
  SIMP_TAC (srw_ss() ++ boolSimps.DNF_ss) [eta_def, LAM_eq_thm, tpm_fresh]);

val cc_eta_FV_SUBSET = store_thm(
  "cc_eta_FV_SUBSET",
  ``!M N. compat_closure eta M N ==> FV N SUBSET FV M``,
  HO_MATCH_MP_TAC compat_closure_ind THEN
  SIMP_TAC (srw_ss()) [SUBSET_DEF] THEN
  Q_TAC SUFF_TAC `!M N. eta M N ==> !s. s IN FV N ==> s IN FV M` THEN1
        PROVE_TAC [] THEN
  SIMP_TAC (srw_ss()) [eta_def, GSYM LEFT_FORALL_IMP_THM]);

val cc_eta_LAM = store_thm(
  "cc_eta_LAM",
  ``!t v u. compat_closure eta (LAM v t) u =
            (?t'. (u = LAM v t') /\ compat_closure eta t t') \/
            eta (LAM v t) u``,
  CONV_TAC (STRIP_QUANT_CONV
              (LAND_CONV (ONCE_REWRITE_CONV [compat_closure_cases]))) THEN
  SIMP_TAC (srw_ss() ++ boolSimps.DNF_ss)[LAM_eq_thm, EQ_IMP_THM, tpm_eqr,
                                          cc_eta_tpm_eqn, tpm_flip_args] THEN
  REPEAT STRIP_TAC THEN DISJ1_TAC THEN
  Q_TAC SUFF_TAC `~(v' IN FV (tpm [(v,v')] y))` THEN1 SRW_TAC [][] THEN
  METIS_TAC [cc_eta_FV_SUBSET, SUBSET_DEF]);

val eta_LAM = store_thm(
  "eta_LAM",
  ``!v t u. eta (LAM v t) u = (t = u @@ VAR v) /\ ~(v IN FV u)``,
  SRW_TAC [][eta_def, LAM_eq_thm, EQ_IMP_THM] THEN SRW_TAC [][tpm_fresh] THEN
  SRW_TAC [boolSimps.DNF_ss][]);

val CR_eta_lemma = prove(
  ``!M M1 M2. eta M M1 /\ compat_closure eta M M2 /\ ~(M1 = M2) ==>
              ?M3. compat_closure eta M1 M3 /\ compat_closure eta M2 M3``,
  REPEAT STRIP_TAC THEN
  `?v. (M = LAM v (M1 @@ VAR v)) /\ ~(v IN FV M1)` by PROVE_TAC [eta_def] THEN
  FULL_SIMP_TAC (srw_ss()) [cc_eta_LAM, cc_eta_thm] THENL [
    Q.EXISTS_TAC `rator t'` THEN
    SRW_TAC [][eta_LAM] THEN
    METIS_TAC [cc_eta_FV_SUBSET, SUBSET_DEF],
    FULL_SIMP_TAC (srw_ss()) [eta_LAM]
  ]);

val cc_strong_ind =
    IndDefRules.derive_strong_induction (compat_closure_rules, compat_closure_ind)

val eta_diamond = prove(
  ``!M M1. compat_closure eta M M1 ==>
           !M2. compat_closure eta M M2 /\ ~(M1 = M2) ==>
                ?M3. compat_closure eta M1 M3 /\
                     compat_closure eta M2 M3``,
  HO_MATCH_MP_TAC cc_strong_ind THEN REPEAT CONJ_TAC THENL [
    PROVE_TAC [CR_eta_lemma],

    SRW_TAC [][cc_eta_thm] THEN
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.DNF_ss) [cc_eta_thm],

    SRW_TAC [][cc_eta_thm] THEN
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.DNF_ss) [cc_eta_thm],

    SRW_TAC [][cc_eta_LAM, eta_LAM] THEN
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.DNF_ss) [cc_eta_LAM, cc_eta_thm] THEN
    METIS_TAC [cc_eta_FV_SUBSET, SUBSET_DEF]
  ]);

val eta_CR = store_thm(
  "eta_CR",
  ``CR eta``,
  Q_TAC SUFF_TAC `diamond_property (RC (compat_closure eta))` THEN1
        (SRW_TAC [][CR_def, reduction_def] THEN
         PROVE_TAC [relationTheory.TC_RC_EQNS, diamond_TC]) THEN
  SIMP_TAC (srw_ss()) [diamond_property_def, relationTheory.RC_DEF,
                       RIGHT_AND_OVER_OR, LEFT_AND_OVER_OR, EXISTS_OR_THM,
                       DISJ_IMP_THM, FORALL_AND_THM] THEN
  PROVE_TAC [eta_diamond]);

val wonky_diamond_commutes = store_thm( (* Barendregt, lemma 3.3.6 *)
  "wonky_diamond_commutes",
  ``!R1 R2.
        (!x y z. R1 x y /\ R2 x z ==> ?w. RTC R1 z w /\ RC R2 y w) ==>
        commute (RTC R1) (RTC R2)``,
  REPEAT STRIP_TAC THEN
  `!x y. RTC R1 x y ==> !z. R2 x z ==> ?w. RTC R1 z w /\ RTC R2 y w` by
      (HO_MATCH_MP_TAC relationTheory.RTC_STRONG_INDUCT THEN
       CONJ_TAC THENL [
         PROVE_TAC [relationTheory.RTC_RULES],
         MAP_EVERY Q.X_GEN_TAC [`x`,`y`,`z`] THEN REPEAT STRIP_TAC THEN
         `?w. RC R2 y w /\ RTC R1 z' w` by PROVE_TAC [] THEN
         FULL_SIMP_TAC (srw_ss()) [relationTheory.RC_DEF] THEN
         PROVE_TAC [relationTheory.RTC_RTC, relationTheory.RTC_RULES]
       ]) THEN
  Q_TAC SUFF_TAC
        `!x y. RTC R2 x y ==> !z. RTC R1 x z ==>
                                  ?w. RTC R2 z w /\ RTC R1 y w` THEN1
        (SRW_TAC [][commute_def] THEN PROVE_TAC []) THEN
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  PROVE_TAC [relationTheory.RTC_RULES, relationTheory.RTC_RTC]);

val eta_cosubstitutive = store_thm(
  "eta_cosubstitutive",
  ``!P M N x. compat_closure eta M N ==> reduction eta ([M/x] P) ([N/x] P)``,
  REPEAT GEN_TAC THEN Q.ID_SPEC_TAC `P` THEN
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `x INSERT FV M UNION FV N` THEN
  SRW_TAC [][SUB_THM, SUB_VAR] THEN
  PROVE_TAC [reduction_rules]);

val strong_ccbeta_gen_ind =
    (GEN_ALL o
     SIMP_RULE (srw_ss()) [compat_closure_rules, FORALL_AND_THM,
                           GSYM CONJ_ASSOC] o
     Q.INST [`P` |-> `\M N x. P M N x /\ compat_closure beta M N`])
    ccbeta_gen_ind

val eta_beta_commute = store_thm(
  "eta_beta_commute",
  ``commute (reduction eta) (reduction beta)``,
  SIMP_TAC (srw_ss()) [reduction_def] THEN
  MATCH_MP_TAC wonky_diamond_commutes THEN
  Q_TAC SUFF_TAC
        `!M P. compat_closure beta M P ==>
               !N. compat_closure eta M N ==>
                   ?Q. reduction eta P Q /\
                       RC (compat_closure beta) N Q`
        THEN1 PROVE_TAC [reduction_def] THEN
  HO_MATCH_MP_TAC strong_ccbeta_gen_ind THEN
  Q.EXISTS_TAC `FV` THEN SRW_TAC [][] THENL [
    FULL_SIMP_TAC (srw_ss()) [cc_eta_thm, cc_eta_LAM] THENL [
      Q.EXISTS_TAC `[P/v]t''` THEN
      `compat_closure eta ([P/v]M) ([P/v]t'')`
         by METIS_TAC [cc_eta_subst] THEN
      `compat_closure beta (LAM v t'' @@ P) ([P/v]t'')`
         by METIS_TAC [beta_def, compat_closure_rules] THEN
      METIS_TAC [relationTheory.RC_DEF, reduction_rules],
      FULL_SIMP_TAC (srw_ss()) [eta_LAM, SUB_THM, lemma14b] THEN
      Q.EXISTS_TAC `t' @@ P` THEN
      METIS_TAC [reduction_rules, relationTheory.RC_DEF],
      Q.EXISTS_TAC `[u'/v]M` THEN
      METIS_TAC [relationTheory.RC_DEF, eta_cosubstitutive, beta_def,
                 compat_closure_rules]
    ],
    METIS_TAC [beta_def, compat_closure_rules],

    FULL_SIMP_TAC (srw_ss()) [cc_eta_thm] THEN
    METIS_TAC [compat_closure_rules, relationTheory.RC_DEF,
               reduction_rules],
    FULL_SIMP_TAC (srw_ss()) [cc_eta_thm] THEN
    METIS_TAC [compat_closure_rules, relationTheory.RC_DEF,
               reduction_rules],

    FULL_SIMP_TAC (srw_ss()) [cc_eta_LAM, eta_LAM] THENL [
      METIS_TAC [compat_closure_rules, relationTheory.RC_DEF,
                 reduction_rules],
      FULL_SIMP_TAC (srw_ss()) [cc_beta_thm] THENL [
        SRW_TAC [][] THEN FULL_SIMP_TAC (srw_ss()) [] THENL [
          `LAM v ([VAR v/v'] M0) = LAM v' M0`
             by METIS_TAC [SIMPLE_ALPHA] THEN
          METIS_TAC [reduction_rules, relationTheory.RC_DEF],
          METIS_TAC [reduction_rules, relationTheory.RC_DEF]
        ],
        `~(v IN FV M')` by METIS_TAC [cc_beta_FV_SUBSET, SUBSET_DEF] THEN
        `compat_closure eta (LAM v (M' @@ VAR v)) M'`
           by SRW_TAC [][cc_eta_LAM, eta_LAM] THEN
        METIS_TAC [relationTheory.RC_DEF, reduction_rules]
      ]
    ]
  ])

val beta_eta_CR = store_thm(
  "beta_eta_CR",
  ``CR (beta RUNION eta)``,
  MATCH_MP_TAC (CONJUNCT2 hindley_rosen_lemma) THEN
  PROVE_TAC [beta_CR, eta_CR, eta_beta_commute, commute_COMM]);

val beta_eta_lameta = store_thm(
  "beta_eta_lameta",
  ``conversion (beta RUNION eta) = lameta``,
  SIMP_TAC (srw_ss()) [FUN_EQ_THM, EQ_IMP_THM, FORALL_AND_THM] THEN
  CONJ_TAC THENL [
    SIMP_TAC (srw_ss()) [conversion_def] THEN
    HO_MATCH_MP_TAC equiv_closure_ind THEN
    REPEAT CONJ_TAC THEN1
      (HO_MATCH_MP_TAC compat_closure_ind THEN
       REPEAT CONJ_TAC THEN1
          (SRW_TAC [][beta_def, eta_def, relationTheory.RUNION] THEN
           PROVE_TAC [lameta_rules]) THEN
       PROVE_TAC [lameta_rules]) THEN
    PROVE_TAC [lameta_rules],
    CONV_TAC (RENAME_VARS_CONV ["M", "N"]) THEN HO_MATCH_MP_TAC lameta_ind THEN
    REPEAT STRIP_TAC THENL [
      `(beta RUNION eta) (LAM x M @@ N) ([N/x]M)` by
         (SRW_TAC [][beta_def, relationTheory.RUNION] THEN PROVE_TAC []) THEN
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_rules],
      PROVE_TAC [conversion_compatible, compatible_def, rightctxt,
                 rightctxt_thm],
      PROVE_TAC [conversion_compatible, compatible_def, leftctxt],
      PROVE_TAC [conversion_compatible, compatible_def, absctxt],
      `(beta RUNION eta) (LAM x (N @@ VAR x)) N` by
         (SRW_TAC [][eta_def, relationTheory.RUNION] THEN PROVE_TAC []) THEN
      PROVE_TAC [conversion_rules]
    ]
  ]);

val beta_eta_normal_form_benf = store_thm(
  "beta_eta_normal_form_benf",
  ``normal_form (beta RUNION eta) = benf``,
  SIMP_TAC (srw_ss()) [FUN_EQ_THM, EQ_IMP_THM, benf_def, FORALL_AND_THM,
                       normal_form_def] THEN CONJ_TAC
  THENL [
    Q_TAC SUFF_TAC `!M. ~bnf M \/ ~enf M ==> can_reduce (beta RUNION eta) M`
          THEN1 PROVE_TAC [] THEN
    HO_MATCH_MP_TAC simple_induction THEN REPEAT CONJ_TAC THENL [
      SRW_TAC [][bnf_thm, enf_thm], (* var case *)
      MAP_EVERY Q.X_GEN_TAC [`f`, `x`] THEN (* app case *)
      SRW_TAC [][bnf_thm, enf_thm] THENL [
        PROVE_TAC [can_reduce_rules],
        PROVE_TAC [can_reduce_rules],
        `redex (beta RUNION eta) (f @@ x)` by
         (SRW_TAC [][redex_def, relationTheory.RUNION, beta_def,
                     EXISTS_OR_THM] THEN
          PROVE_TAC [is_abs_thm, term_CASES]) THEN
        PROVE_TAC [can_reduce_rules],
        PROVE_TAC [can_reduce_rules],
        PROVE_TAC [can_reduce_rules]
      ],

      MAP_EVERY Q.X_GEN_TAC [`x`, `M`] THEN
      SRW_TAC [][bnf_thm, enf_thm] THENL [
        PROVE_TAC [can_reduce_rules, lemma14a],
        PROVE_TAC [can_reduce_rules, lemma14a],
        Q_TAC SUFF_TAC `redex (beta RUNION eta) (LAM x M)` THEN1
            PROVE_TAC [can_reduce_rules] THEN
        SRW_TAC [][redex_def, relationTheory.RUNION, eta_def] THEN
        PROVE_TAC [is_comb_rator_rand]
      ]
    ],
    Q_TAC SUFF_TAC `!x. can_reduce (beta RUNION eta) x ==> ~bnf x \/ ~enf x`
          THEN1 PROVE_TAC [] THEN
    HO_MATCH_MP_TAC can_reduce_ind THEN
    SIMP_TAC (srw_ss()) [bnf_thm, enf_thm, DISJ_IMP_THM, redex_def,
                         relationTheory.RUNION, GSYM LEFT_FORALL_IMP_THM,
                         beta_def, eta_def]
  ]);

val lameta_consistent = store_thm(
  "lameta_consistent",
  ``consistent lameta``,
  SIMP_TAC (srw_ss()) [consistent_def, GSYM beta_eta_lameta] THEN
  MAP_EVERY Q.EXISTS_TAC [`S`, `K`] THEN STRIP_TAC THEN
  `?Z. reduction (beta RUNION eta) S Z /\ reduction (beta RUNION eta) K Z` by
     PROVE_TAC [theorem3_13, beta_eta_CR] THEN
  `normal_form (beta RUNION eta) S` by
       SRW_TAC [][beta_eta_normal_form_benf, benf_def, bnf_thm, enf_thm,
                  S_def] THEN
  `normal_form (beta RUNION eta) K` by
       SRW_TAC [][beta_eta_normal_form_benf, benf_def, bnf_thm, enf_thm,
                  K_def] THEN
  `S = K` by PROVE_TAC [corollary3_2_1] THEN
  FULL_SIMP_TAC (srw_ss()) [S_def, K_def]);

val is_comb_subst = store_thm(
  "is_comb_subst",
  ``!t u v. is_comb t ==> is_comb ([u/v]t)``,
  SIMP_TAC (srw_ss()) [SUB_THM, is_comb_APP_EXISTS,
                       GSYM LEFT_FORALL_IMP_THM]);

val rator_isub_commutes = store_thm(
  "rator_isub_commutes",
  ``!R t. is_comb t ==> (rator (t ISUB R) = rator t ISUB R)``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss()) [ISUB_def, pairTheory.FORALL_PROD,
                           rator_subst_commutes, is_comb_subst]);


val SUB_MERGE = save_thm("SUB_MERGE", lemma15a)

val (hnf_thm, _) =
    define_recursive_term_function
    `(hnf (VAR s) = T) /\
     (hnf (x @@ y) = hnf x /\ ~is_abs x) /\
     (hnf (LAM v t) = hnf t)`;

val _ = export_theory();

