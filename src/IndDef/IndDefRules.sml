(* ========================================================================= *)
(* File        : IndDefRules.sml                                             *)
(* Description : Rules for manipulating simple inductive definitions.        *)
(*               Drawn from Tom Melham's ind. def. library                   *)
(* ========================================================================= *)

structure IndDefRules :> IndDefRules =
struct

open HolKernel Parse boolLib;

val ERR = mk_HOL_ERR "IndDefRules";

(* ===================================================================== *)
(* STRONGER FORM OF INDUCTION. From Tom Melham's library.                *)
(* ===================================================================== *)

(* ---------------------------------------------------------------------*)
(* INTERNAL FUNCTION : simp_axiom                                       *)
(*                                                                      *)
(* This function takes an axiom of the form                             *)
(*                                                                      *)
(*    |- !xs. REL ps <args>                                             *)
(*                                                                      *)
(* and a term of the form                                               *)
(*                                                                      *)
(*    !xs. (\vs. REL ps vs /\ P vs) <args>                              *)
(*                                                                      *)
(* and proves that                                                      *)
(*                                                                      *)
(*    |- (!xs. P <args>) ==> !xs. (\vs. REL ps vs /\ P vs) <args>       *)
(*                                                                      *)
(* That is, simp_axiom essentially beta-reduces the input term, and     *)
(* drops the redundant conjunct "REL ps xs", this holding merely by     *)
(* virtue of the axiom being true.                                      *)
(* ---------------------------------------------------------------------*)

fun simp_axiom (ax,tm) =
   let val (vs,red) = strip_forall tm
       val bth = LIST_BETA_CONV red
       val asm = list_mk_forall(vs,rand(rand(concl bth)))
       val th1 = SPECL vs (ASSUME asm)
       val th2 = EQ_MP (SYM bth) (CONJ (SPECL vs ax) th1)
   in DISCH asm (GENL vs th2)
   end

(* ---------------------------------------------------------------------*)
(* INTERNAL FUNCION : reduce_asm                                        *)
(*                                                                      *)
(* The term asm is expected to be the antecedent of a rule in the form: *)
(*                                                                      *)
(*   "?zs. ... /\ (\vs. REL ps vs /\ P vs) <args> /\ ..."               *)
(*                                                                      *)
(* in which applications of the supplied parameter fn:                  *)
(*                                                                      *)
(*   "(\vs . REL ps vs /\ P vs)"                                        *)
(*                                                                      *)
(* appear as conjuncts (possibly among some side conditions).  The      *)
(* function reduce_asm beta-reduces these conjuncts and flattens the    *)
(* resulting conjunction of terms.  The result is the theorem:          *)
(*                                                                      *)
(*   |- asm ==> ?zs. ... /\ REL ps <args> /\ P <args> /\ ...            *)
(*                                                                      *)
(* ---------------------------------------------------------------------*)

local fun reduce Fn tm =
       let val (conj1,conj2) = dest_conj tm
           val imp = reduce Fn conj2
       in 
       if fst(strip_comb conj1) = Fn 
       then let val (t1,t2) = 
                     CONJ_PAIR (EQ_MP (LIST_BETA_CONV conj1) (ASSUME conj1))
                val thm1 = CONJ t1 (CONJ t2 (UNDISCH imp))
                val asm = mk_conj(conj1,rand(rator(concl imp)))
                val (h1,h2) = CONJ_PAIR (ASSUME asm)
            in DISCH asm (PROVE_HYP h1 (PROVE_HYP h2 thm1))
            end
       else IMP_CONJ (DISCH conj1 (ASSUME conj1)) imp
       end handle HOL_ERR _ => 
            if fst(strip_comb tm) = Fn
            then fst(EQ_IMP_RULE(LIST_BETA_CONV tm))
            else DISCH tm (ASSUME tm)
in
fun reduce_asm Fn asm =
   let val (vs,body) = strip_exists asm
   in itlist EXISTS_IMP vs (reduce Fn body)
   end
end;

fun prove_asm P tm =
   let fun test t = not(fst(strip_comb(concl t)) = P)
       val (vs,body) = strip_exists tm
       val newc = LIST_CONJ(filter test (CONJUNCTS(ASSUME body)))
   in itlist EXISTS_IMP vs (DISCH body newc)
   end;

fun simp_concl rul tm =
 let val (vs,(ant,conseq)) = (I ## dest_imp) (strip_forall tm)
     val srul = SPECL vs rul
     val (cvs,(_,conj2)) = (I ## dest_conj) (strip_forall conseq)
     val simpl = prove_asm (fst(strip_comb conj2)) ant
     val thm1 = SPECL cvs (UNDISCH (IMP_TRANS simpl srul))
     val newasm = list_mk_forall(vs,mk_imp(ant,list_mk_forall(cvs,conj2)))
     val thm2 = CONJ thm1 (SPECL cvs (UNDISCH (SPECL vs (ASSUME newasm))))
 in DISCH newasm (GENL vs (DISCH ant (GENL cvs thm2)))
 end;

fun simp_rule (rul,tm) =
 let val (vs,(ant,conseq)) = (I ## dest_imp) (strip_forall tm)
     val (cvs,red) = strip_forall conseq
     val bth = itlist FORALL_EQ cvs (LIST_BETA_CONV red)
     val basm = reduce_asm (fst(strip_comb red)) ant
     val asm = list_mk_forall(vs,mk_imp(rand(concl basm),rand(concl bth)))
     val thm1 = UNDISCH (IMP_TRANS basm (SPECL vs (ASSUME asm)))
     val thm2 = DISCH asm (GENL vs (DISCH ant (EQ_MP (SYM bth) thm1)))
     val thm3 = simp_concl rul (rand(rator(concl thm2)))
 in IMP_TRANS thm3 thm2
 end;

fun simp p = simp_rule p handle HOL_ERR _ => simp_axiom p;

fun derive_strong_induction (rules,ind) =
 let val rules = map GEN_ALL rules
     val (vs,(_,conseq)) = (I ## dest_imp) (strip_forall (concl ind))
     val srules = map (SPECL (butlast vs)) rules
     val (cvs,(rel,pred)) = (I ## dest_imp) (strip_forall conseq)
     val newp = list_mk_abs(cvs,mk_conj(rel,pred))
     val (pvar,args) = strip_comb pred
     val ith = INST [pvar |-> newp] (SPECL vs ind)
     val (ant,co) = dest_imp (concl ith)
     val bth = LIST_BETA_CONV (list_mk_comb(newp,args))
     val sth = CONJUNCT2 (EQ_MP bth (UNDISCH (SPECL args (ASSUME co))))
     val thm1 = IMP_TRANS ith (DISCH co (GENL args (DISCH rel sth)))
     val ths = map simp (combine (srules,strip_conj ant))
 in
   GENL vs (IMP_TRANS (end_itlist IMP_CONJ ths) thm1)
 end
 handle e => raise (wrap_exn "IndDefRules" 
                             "derive_strong_induction" e);


(* ===================================================================== *)
(* RULE INDUCTION 							 *)
(* ===================================================================== *)

(* --------------------------------------------------------------------- *)
(* Internal function: TACF	 					 *)
(*									 *)
(* TACF is used to generate the subgoals for each case in an inductive 	 *)
(* proof.  The argument tm is formula which states one case in the 	 *)
(* the induction. In general, this will take one of the forms:		 *)
(*									 *)
(*   (1) no side condition, no assumptions:				 *)
(*									 *)
(*       tm = !x1...xn. P x1 ... xn					 *)
(*									 *)
(*   (2) side condition ?y1...ym.C, no assumptions:			 *)
(*									 *)
(*       tm = !xs. (?y1...ym.C) ==> !zs. P xz1 ... xz(n+o)		 *)
(*									 *)
(*   (3) assumptions ?y1...ym.A, no side condition:			 *)
(*									 *)
(*       tm = !xs. (?y1...ym.A) ==> !zs. P xz1 ... xz(n+o)		 *)
(*									 *)
(*   (4) assumptions ?y1...ym.A, and side condition (?y1...ym.C):	 *)
(*									 *)
(*       tm = !xs. ?zs.(?y1...ym.A) /\ (?w1...wm.C) ==> 		 *)
(*		  !zs. P xz1 ... xz(n+o)				 *)
(*									 *)
(*									 *)
(* 2--4 now merged into:						 *)
(*      								 *)
(*       tm = !xs. ?zs. A /\ ... /\ C /\ ... /\ A ==>			 *)
(*	          !ys. P ...						 *)
(*									 *)
(* TACF applied to each these terms to construct a parameterized tactic  *)
(* which will be used to further break these terms into subgoals.  The   *)
(* resulting tactic takes a variable name x and a user supplied theorem  *)
(* continuation ttac.  For a base case, like case 1 above, the resulting *)
(* tactic just throws these parameters away and passes the goal on 	 *)
(* unchanged (i.e. \x ttac. ALL_TAC).  For a step case, like case 2, the *)
(* tactic applies GTAC x as many times as required.  It then strips off  *)
(* the induction hypotheses and applies ttac to each one.  For example,  *)
(* if tac is the tactic generated by:					 *)
(*									 *)
(*    TACF "!n. P n ==> P(SUC n)" "x:num" ASSUME_TAC			 *)
(*									 *)
(* then applying tac to the goal A,"!n. P[n] ==> P[SUC n] has the same 	 *)
(* effect as applying:							 *)
(*									 *)
(*    GTAC "x:num" THEN DISCH_THEN ASSUME_TAC				 *)
(*									 *)
(* TACF is a strictly local function, used only to define TACS, below.	 *)
(*									 *)
(* --------------------------------------------------------------------- *)

fun MK_CONJ_THEN Fn tm =
 let val (conj1,conj2) = dest_conj tm
     val tcl1 = if (fst(strip_comb conj1) = Fn)
                  then fn t1 => fn t2 => t1
                  else fn t1 => fn t2 => t2
     val tcl2 = MK_CONJ_THEN Fn conj2
 in
   fn ttac1 => fn ttac2 =>
     CONJUNCTS_THEN2 (tcl1 ttac1 ttac2) (tcl2 ttac1 ttac2)
 end
 handle HOL_ERR _ => if (fst(strip_comb tm) = Fn) then K else C K;

fun MK_CHOOSE_THEN Fn [] body = MK_CONJ_THEN Fn body
  | MK_CHOOSE_THEN Fn (_::t) body =
      let val tcl = MK_CHOOSE_THEN Fn t body
      in fn ttac1 => fn ttac2 => CHOOSE_THEN (tcl ttac1 ttac2)
      end;

fun MK_THEN Fn tm =
  let val (vs,body) = strip_exists tm
  in if free_in Fn body then MK_CHOOSE_THEN Fn vs body
     else fn ttac1 => fn ttac2 => ttac2
  end;

fun TACF Fn tm =
 let val (vs,body) = strip_forall tm
 in if is_imp body
    then let val TTAC = MK_THEN Fn (fst(dest_imp body))
         in fn ttac1 => fn ttac2 =>
              REPEAT GEN_TAC THEN DISCH_THEN (TTAC ttac1 ttac2)
        end
    else fn ttac1 => fn ttac2 => ALL_TAC
 end;

(* --------------------------------------------------------------------- *)
(* Internal function: TACS						 *)
(*									 *)
(* TACS uses TACF to generate a paramterized list of tactics, one for    *)
(* each conjunct in the hypothesis of an induction theorem.		 *)
(*									 *)
(* For example, if tm is the hypothesis of the induction thoerem for the *)
(* natural numbers---i.e. if:						 *)
(*									 *)
(*   tm = "P 0 /\ (!n. P n ==> P(SUC n))"				 *)
(*									 *)
(* then TACS tm yields the paremterized list of tactics:		 *)
(*									 *)
(*   \x ttac. [TACF "P 0" x ttac; TACF "!n. P n ==> P(SUC n)" x ttac]    *)
(*									 *)
(* TACS is a strictly local function, used only in INDUCT_THEN.		 *)
(*									 *)
(* --------------------------------------------------------------------- *)

fun TACS Fn tm =
 let val (cf,csf) = 
       (TACF Fn ## TACS Fn) (dest_conj tm)
       handle HOL_ERR _ => (TACF Fn tm, fn x => fn y => [])
 in 
     fn ttac1 => fn ttac2 => cf ttac1 ttac2 :: csf ttac1 ttac2
 end;


(* --------------------------------------------------------------------- *)
(* Internal function RED_WHERE.						 *)
(*									 *)
(* Given the arguments "f" and "tm[f]", this function produces a 	 *)
(* conversion that will apply LIST_BETA_CONV to its argument at all	 *)
(* top-level subterms that correspond to occurrences of f (bottom-up).	 *)
(*									 *)
(* Optimized for induction special form.				 *)
(*									 *)
(* --------------------------------------------------------------------- *)

local fun mkred Fn (c::cs) =
        let val cfn = if (fst(strip_comb c) = Fn) then LIST_BETA_CONV else REFL
        in if null cs then cfn
           else let val rest = mkred Fn cs
                in fn tm => 
                     let val (conj1,conj2) = dest_conj tm
                     in MK_COMB(AP_TERM boolSyntax.conjunction (cfn conj1),
                                rest conj2)
                     end
                end
        end
in
fun RED_CASE Fn pat =
 let val bdy = snd(strip_forall pat)
 in if is_imp bdy
    then let val (ant,_) = dest_imp bdy
             val hyps = strip_conj(snd(strip_exists ant))
             val redf = mkred Fn hyps
         in fn tm =>
             let val (vs,(ant,conseq)) = (I##dest_imp) (strip_forall tm)
                 val (cvs,red) = strip_forall conseq
                 val th1 = itlist FORALL_EQ cvs (LIST_BETA_CONV red)
                 val (evs,hyp) = strip_exists ant
                 val th2 = itlist EXISTS_EQ evs (redf hyp)
             in itlist FORALL_EQ vs 
                         (MK_COMB((AP_TERM boolSyntax.implication th2),th1))
             end
        end
   else fn tm =>
          let val (vs,con) = strip_forall tm
          in itlist FORALL_EQ vs (LIST_BETA_CONV con)
          end
 end
end;


fun APPLY_CASE [f] tm = f tm
  | APPLY_CASE (f::fs) tm =
     let val (conj1,conj2) = dest_conj tm
     in MK_COMB (AP_TERM boolSyntax.conjunction (f conj1),APPLY_CASE fs conj2)
     end

fun RED_WHERE Fn body =
 let val rfns = map (RED_CASE Fn) (strip_conj (fst(dest_imp body)))
 in fn stm =>
      let val (ant,conseq) = dest_imp stm
          val hthm = APPLY_CASE rfns ant
          val cthm = RAND_CONV LIST_BETA_CONV conseq
      in MK_COMB(AP_TERM boolSyntax.implication hthm,cthm)
      end
  end;

fun residue_assoc itm =
   let fun assc ([]:(term,term)subst) = NONE
         | assc ({redex,residue}::rst) =
             if itm = residue then SOME redex else assc rst
   in assc
   end;

(* lookup on the residue, then take the redex *)

fun is_param icvs slis arg =
 let val vl = case residue_assoc arg slis of SOME x => x | NONE => arg
 in mem vl icvs
 end;

(* --------------------------------------------------------------------- *)
(* RULE_INDUCT_THEN : rule induction tactic.			         *)
(* --------------------------------------------------------------------- *)

local val RIND_ERR = ERR "RULE_INDUCT_THEN"
      fun pair x y = (x,y)
in
fun RULE_INDUCT_THEN th =
 let val (vs,(ant,conseq)) = (I ## dest_imp) (strip_forall (concl th))
     val (cvs,cncl) = strip_forall conseq
     val thm  = DISCH ant (SPECL cvs(UNDISCH(SPECL vs th)))
     val pvar = genvar (type_of (last vs))
     val sthm = INST [last vs |-> pvar] thm
     val RED  = RED_WHERE (last vs) (mk_imp(ant,cncl))
     val tacs = TACS (last vs) ant
 in
 fn ttac1 => fn ttac2 => fn (A,g) =>
   let val (gvs,body) = strip_forall g
       val (theta as (slis,ilis)) = match_term (rator cncl) (rator body)
       val sith = INST_TY_TERM theta sthm
       val largs = snd(strip_comb (rand(rator body)))
       val icvs = map (inst ilis) cvs
       val params = filter (is_param icvs slis) largs
       val lam = list_mk_abs(params,rand body)
       val spth = INST [inst ilis pvar |-> lam] sith
       val spec = GENL gvs (UNDISCH (CONV_RULE RED spth))
       val subgls = map (pair A) (strip_conj (hd(hyp spec)))
       fun tactc g = (subgls,fn ths => PROVE_HYP (LIST_CONJ ths) spec)
   in (tactc THENL (tacs ttac1 ttac2)) (A,g)
   end handle HOL_ERR _ => raise RIND_ERR "inappropriate goal"
 end handle HOL_ERR _ => raise RIND_ERR "ill-formed rule induction theorem"
end;


(* ===================================================================== *)
(* TACTICS FROM THEOREMS THAT STATE RULES.			 	 *)
(* ===================================================================== *)

fun axiom_tac th :tactic = fn (A,g) =>
 let val (vs,body) = strip_forall g
     val instl = match_term (concl th) body
 in ([], K (itlist ADD_ASSUM A (GENL vs (INST_TY_TERM instl th))))
 end
 handle HOL_ERR _ => raise ERR "axiom_tac" "axiom does not match goal";

(* --------------------------------------------------------------------- *)
(* prove_conj								 *)
(*									 *)
(* HOL88 code:                                                           *)
(*									 *)
(* letrec prove_conj ths tm =                                            *)
(*    uncurry CONJ ((prove_conj ths # prove_conj ths) (dest_conj tm)) ?  *)
(*    find (curry $= tm o concl) ths;;                                   *)
(* --------------------------------------------------------------------- *)

fun prove_conj ths tm =
 let val (conj1,conj2) = dest_conj tm
     val f = prove_conj ths
 in CONJ (f conj1) (f conj2)
 end 
 handle HOL_ERR _ => first (equal tm o concl) ths;

(* --------------------------------------------------------------------- *)
(* RULE_TAC								 *)
(* --------------------------------------------------------------------- *)

local fun mkg A vs c = (A,list_mk_forall(vs,c))
in
fun RULE_TAC th =
 let val (vs,rule) = with_exn (strip_forall o concl) th 
                         (ERR "RULE_TAC" "ill-formed input theorem")
 in let val (ant,conseq) = dest_imp rule
        val (cvs,cncl) = strip_forall conseq
        val ith = DISCH ant (SPECL cvs (UNDISCH (SPECL vs th)))
    in fn (A,g) =>
        let val (gvs,body) = strip_forall g
            val (slis,ilis) = match_term cncl body
            val th1 = INST_TY_TERM (slis,ilis) ith
            val svs = rev (free_varsl (map (subst slis o inst ilis) vs))
            val nvs = intersect gvs svs
            val ante = fst(dest_imp(concl th1))
            val newgs = map (mkg A nvs) (strip_conj ante)
        in (newgs,
            fn thl => let val ths = map (SPECL nvs o ASSUME o snd) newgs
                          val th2 = GENL gvs(MP th1 (prove_conj ths ante))
                      in itlist PROVE_HYP thl th2 end)
        end
        handle HOL_ERR _ => raise ERR "RULE_TAC" "rule does not match goal"
    end
    handle HOL_ERR _ => axiom_tac (SPECL vs th)
 end
end;

(* =====================================================================*)
(* REDUCTION OF A CONJUNCTION OF EQUATIONS.				*)
(* =====================================================================*)

(* ---------------------------------------------------------------------*)
(* INTERNAL FUNCTION : reduce 						*)
(* 									*)
(* A call to 								*)
(*									*)
(*   reduce [v1;...;vn] ths [] []					*)
(*									*)
(* reduces the list of theorems ths to an equivalent list by removing 	*)
(* theorems of the form |- vi = ti where vi does not occur free in ti,  *)
(* first using this equation to substitute ti for vi in all the other	*)
(* theorems. The theorems in ths are processed sequentially, so for 	*)
(* example:								*)
(*									*)
(*   reduce [a;b] [|- a=1; |- b=a+2; |- c=a+b] [] []			*)
(*									*)
(* is reduced in the following stages:					*)
(*									*)
(*   [|- a=1; |- b=a+2; |- c=a+b]					*)
(*   									*)
(*   ===> [|- b=1+2; |- c=1+b]      (by the substitution [1/a])		*)
(*   ===> [|- c=1+(1+2)]            (by the substitution [1+2/b])	*)
(*									*)
(* The function returns the reduced list of theorems, paired with a list *)
(* of the substitutions that were made, in reverse order.  The result 	*)
(* for the above example would be [|- c = 1+(1+2)],[("1+2",b);("1",a)].	*)
(* ---------------------------------------------------------------------*)

fun subst_in_subst theta =
  map (fn {redex,residue} => {redex=redex, residue = subst theta residue});

fun reduce vs ths res subf =
 if null ths then (rev res, subf)
 else let val (lhs,rhs) = dest_eq(concl(hd ths))
          val (sth,pai) = 
             if mem lhs vs then (hd ths,(lhs |-> rhs))
             else if mem rhs vs
                  then (SYM(hd ths),(rhs |-> lhs))
                  else raise ERR "reduce" ""
      in if free_in (#redex pai) (#residue pai)
         then raise ERR "reduce" ""
         else let val sfn = map (SUBS [sth])
                  val ssfn = subst_in_subst [pai]
              in reduce vs (sfn (tl ths)) (sfn res) (pai::ssfn subf)
              end
      end
      handle HOL_ERR _ => reduce vs (tl ths) (hd ths::res) subf


(* --------------------------------------------------------------------- *)
(* REDUCE : simplify an existentially quantified conjuction by		*)
(* eliminating conjuncts of the form |- v=t, where v is among the 	*)
(* quantified variables and v does not appear free in t. For example 	*)
(* suppose:								*)
(* 									*)
(*   tm = "?vi. ?vs. C1 /\ ... /\ v = t /\ ... /\ Cn"			*)
(*									*)
(* then the result is:							*)
(*									*)
(*   |- (?vi. ?vs. C1 /\ ... /\ vi = ti /\ ... /\ Cn)			*)
(*          =								*)
(*      (?vs. C1[ti/vi] /\ ... /\ Cn[ti/vi])				*)
(*									*)
(* The equations vi = ti can appear as ti = vi, and all eliminable 	*)
(* equations are eliminated.  Fails unless there is at least one	*)
(* eliminable equation. Also flattens conjuncts. Reduces term to "T" if	*)
(* all variables eliminable.						*)
(* ---------------------------------------------------------------------*)

local fun chfn v (a,th) =
        let val tm = mk_exists(v,a)
            val th' = if free_in v (concl th)
                      then EXISTS (mk_exists(v,concl th),v) th
                      else th
        in (tm,CHOOSE (v,ASSUME tm) th')  
        end
      fun efn ss v (pat,th) =
        let val wit = case subst_assoc (equal v) ss
                       of NONE => v
                        | SOME residue => residue
            val ex = mk_exists(v,pat)
            val epat = subst ss ex
        in (ex,EXISTS(epat,wit) th)
        end
      fun prove ths cs =
         (uncurry CONJ ((prove ths ## prove ths) (dest_conj cs)))
         handle HOL_ERR _
           => (Lib.first (fn t => concl t = cs) ths)
         handle HOL_ERR _
           => REFL (rand cs)
in
fun REDUCE tm =
 let val (vs,cs) = strip_exists tm
     val (remn,ss) = reduce vs (CONJUNCTS (ASSUME cs)) [] []
 in if null ss then raise ERR "REDUCE" ""
    else let val th1 = LIST_CONJ remn handle HOL_ERR _ => TRUTH
             val th2 = (uncurry DISCH) (itlist chfn vs (cs,th1))
             val (rvs,rcs) = strip_exists(rand(concl th2))
             val eqt = subst ss cs
             val th3 = prove (CONJUNCTS (ASSUME rcs)) eqt
             val (_,th4) = itlist (efn ss) vs (cs,th3)
             val th5 = (uncurry DISCH) (itlist chfn rvs (rcs,th4))
         in IMP_ANTISYM_RULE th2 th5
         end
 end
end

end;
