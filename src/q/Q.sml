(*---------------------------------------------------------------------------
 * A bunch of functions that fold quotation parsing in, sometimes to good
 * effect.
 *---------------------------------------------------------------------------*)
structure Q :> Q =
struct

open HolKernel boolLib;
infix THEN |-> ## -->;

val Q_ERR = mk_HOL_ERR "Q";

val ptm = Parse.Term
val pty = Parse.Type;

fun normalise_quotation frags =
  case frags of
    [] => []
  | [x] => [x]
  | (QUOTE s1::QUOTE s2::rest) => normalise_quotation (QUOTE (s1^s2) :: rest)
  | x::xs => x :: normalise_quotation xs

fun contextTerm ctxt q = Parse.parse_in_context ctxt (normalise_quotation q);

fun ptm_with_ctxtty ctxt ty q =
 let val q' = QUOTE "(" :: (q @ [QUOTE "):", ANTIQUOTE(ty_antiq ty), QUOTE ""])
 in Parse.parse_in_context ctxt (normalise_quotation q')
end

fun ptm_with_ty q ty = ptm_with_ctxtty [] ty q;
fun btm q = ptm_with_ty q Type.bool;

fun mk_term_rsubst ctxt =
  map (fn {redex,residue} =>
          let val redex' = contextTerm ctxt redex
              val residue' = ptm_with_ctxtty ctxt (type_of redex') residue
          in redex' |-> residue'
          end);

val mk_type_rsubst = map (fn {redex,residue} => (pty redex |-> pty residue));

val TAUT_CONV = tautLib.TAUT_CONV;
fun store_thm(s,q,t) = Tactical.store_thm(s,btm q,t);
fun prove (q, t) = Tactical.prove(btm q,t);
fun new_definition(s,q) = Definition.new_definition(s,btm q);
fun new_infixl_definition(s,q,f) = boolLib.new_infixl_definition(s,btm q,f);
fun new_infixr_definition(s,q,f) = boolLib.new_infixr_definition(s,btm q,f);

val ABS       = Thm.ABS o ptm;
val BETA_CONV = Thm.BETA_CONV o ptm;
val REFL      = Thm.REFL o ptm;

fun DISJ1 th = Thm.DISJ1 th o btm;
val DISJ2    = Thm.DISJ2 o btm;

fun GEN [QUOTE s] th =
     let val V = free_vars (concl th)
     in case Lib.assoc2 (Lib.deinitcomment s) (Lib.zip V (map (fst o Term.dest_var) V))
         of NONE => raise Q_ERR "GEN" "variable not found"
         | SOME (v,_) => Thm.GEN v th
     end
  | GEN _ _ = raise Q_ERR "GEN" "unexpected quote format"

fun SPEC q =
 W(Thm.SPEC o ptm_with_ty q o (type_of o fst o dest_forall o concl));

val SPECL = rev_itlist SPEC;
val ISPEC = Drule.ISPEC o ptm;
val ISPECL = Drule.ISPECL o map ptm;
val ID_SPEC = W(Thm.SPEC o (fst o dest_forall o concl))

fun SPEC_THEN q ttac thm (g as (asl,w)) = let
  val ctxt = free_varsl (w::asl)
  val (Bvar,_) = dest_forall (concl thm)
  val t = ptm_with_ctxtty ctxt (type_of Bvar) q
in
  ttac (Thm.SPEC t thm) g
end

fun SPECL_THEN ql ttac thm (g as (asl,w)) = let
  val ctxt = free_varsl (w::asl)
  fun spec ql thm =
    case ql of
      [] => thm
    | (q::qs) => let
        val (Bvar,_) = dest_forall (concl thm)
        val t = ptm_with_ctxtty ctxt (type_of Bvar) q
      in
        spec qs (Thm.SPEC t thm)
      end
in
  ttac (spec ql thm) g
end

fun ISPEC_THEN q ttac thm (g as (asl,w)) = let
  val ctxt = free_varsl (w::asl)
  val t = Parse.parse_in_context ctxt q
in
  ttac (Drule.ISPEC t thm) g
end

fun ISPECL_THEN ql ttac thm (g as (asl, w)) = let
  val ctxt = free_varsl (w::asl)
  val ts = map (Parse.parse_in_context ctxt) ql
in
  ttac (Drule.ISPECL ts thm) g
end

fun SPEC_TAC (q1,q2) (g as (asl,w)) = let
  val ctxt = free_varsl (w::asl)
  val T1 = Parse.parse_in_context ctxt q1
  val T2 = ptm_with_ctxtty ctxt (type_of T1) q2
in
  Tactic.SPEC_TAC(T1, T2) g
end;

(* Generalizes first free variable with given name to itself. *)

fun ID_SPEC_TAC q (g as (asl,w)) =
 let val ctxt = free_varsl (w::asl)
     val tm = Parse.parse_in_context ctxt q
 in
   Tactic.SPEC_TAC (tm, tm) g
 end

val EXISTS = Thm.EXISTS o (btm##btm);

fun EXISTS_TAC q (g as (asl, w)) =
 let val ctxt = free_varsl (w::asl)
     val exvartype = type_of (fst (dest_exists w))
       handle HOL_ERR _ => raise Q_ERR "EXISTS_TAC" "goal not an exists"
 in
  Tactic.EXISTS_TAC (ptm_with_ctxtty ctxt exvartype q) g
 end

fun ID_EX_TAC(g as (_,w)) =
  Tactic.EXISTS_TAC (fst(dest_exists w)
                     handle HOL_ERR _ =>
                       raise Q_ERR "ID_EX_TAC" "goal not an exists") g;


fun REFINE_EXISTS_TAC q (asl, w) = let
  val (qvar, body) = dest_exists w
  val ctxt = free_varsl (w::asl)
  val t = ptm_with_ctxtty ctxt (type_of qvar) q
  val qvars = set_diff (free_vars t) ctxt
  val newgoal = subst [qvar |-> t] body
in
  SUBGOAL_THEN (list_mk_exists(rev qvars, newgoal))
  (REPEAT_TCL CHOOSE_THEN (fn th => Tactic.EXISTS_TAC t THEN ACCEPT_TAC th))
  (asl, w)
end

fun X_CHOOSE_THEN q ttac thm (g as (asl,w)) =
 let val ty = type_of (fst (dest_exists (concl thm)))
       handle HOL_ERR _ =>
          raise Q_ERR "X_CHOOSE_THEN" "provided thm not an exists"
     val ctxt = free_varsl (w::asl)
 in
   Thm_cont.X_CHOOSE_THEN (ptm_with_ctxtty ctxt ty q) ttac thm g
 end

val X_CHOOSE_TAC = C X_CHOOSE_THEN Tactic.ASSUME_TAC;

fun DISCH q th =
 let val (asl,c) = dest_thm th
     val V = free_varsl (c::asl)
     val tm = ptm_with_ctxtty V Type.bool q
 in Thm.DISCH tm th
 end;

fun PAT_UNDISCH_TAC q (g as (asl,w)) =
let val ctxt = free_varsl (w::asl)
    val pat = ptm_with_ctxtty ctxt Type.bool q
    val asm =
        first (can (ho_match_term [] Term.empty_tmset pat)) asl
in Tactic.UNDISCH_TAC asm g
end;

fun UNDISCH_THEN q ttac = PAT_UNDISCH_TAC q THEN DISCH_THEN ttac;

fun PAT_ASSUM q ttac (g as (asl,w)) =
 let val ctxt = free_varsl (w::asl)
 in Tactical.PAT_ASSUM (ptm_with_ctxtty ctxt Type.bool q) ttac g
 end

fun SUBGOAL_THEN q ttac (g as (asl,w)) =
let val ctxt = free_varsl (w::asl)
in Tactical.SUBGOAL_THEN (ptm_with_ctxtty ctxt Type.bool q) ttac g
end

fun UNDISCH_TAC q (g as (asl, w)) = let
  val ctxt = free_varsl (w::asl)
in Tactic.UNDISCH_TAC (ptm_with_ctxtty ctxt Type.bool q) g
end

val ASSUME = ASSUME o btm

fun X_GEN_TAC q (g as (asl, w)) =
 let val ctxt = free_varsl (w::asl)
     val ty = type_of (fst(dest_forall w))
 in
   Tactic.X_GEN_TAC (ptm_with_ctxtty ctxt ty q) g
 end

fun X_FUN_EQ_CONV q tm =
 let val ctxt = free_vars tm
     val ty = #1 (dom_rng (type_of (lhs tm)))
 in
   Conv.X_FUN_EQ_CONV (ptm_with_ctxtty ctxt ty q) tm
 end

fun skolem_ty tm =
 let val (V,tm') = strip_forall tm
 in if V<>[]
    then list_mk_fun (map type_of V, type_of(fst(dest_exists tm')))
    else raise Q_ERR"XSKOLEM_CONV" "no universal prefix"
  end;

fun X_SKOLEM_CONV q tm =
 let val ctxt = free_vars tm
     val ty = skolem_ty tm
 in
  Conv.X_SKOLEM_CONV (ptm_with_ctxtty ctxt ty q) tm
 end


fun AP_TERM q th =
 let val ctxt = free_vars(concl th)
     val tm = contextTerm ctxt q
     val (ty,_) = dom_rng (type_of tm)
     val (lhs,rhs) = dest_eq(concl th)
     val theta = match_type ty (type_of lhs)
 in
   Thm.AP_TERM (Term.inst theta tm) th
 end;

fun AP_THM th q =
 let val (lhs,rhs) = dest_eq(concl th)
     val ty = fst (dom_rng (type_of lhs))
     val ctxt = free_vars (concl th)
 in
   Thm.AP_THM th (ptm_with_ctxtty ctxt ty q)
 end;

fun ASM_CASES_TAC q (g as (asl,w)) =
 let val ctxt = free_varsl (w::asl)
 in Tactic.ASM_CASES_TAC (ptm_with_ctxtty ctxt bool q) g
 end

fun AC_CONV p = Conv.AC_CONV p o ptm;

(* Could be smarter *)

fun INST subst th = let
  val ctxt = free_vars (concl th)
in
  Thm.INST (mk_term_rsubst ctxt subst) th
end
val INST_TYPE = Thm.INST_TYPE o mk_type_rsubst;


(*---------------------------------------------------------------------------
 * A couple from jrh.
 *---------------------------------------------------------------------------*)

fun ABBREV_TAC q (g as (asl,w)) =
 let val ctxt = free_varsl(w::asl)
     val (lhs,rhs) = dest_eq (Parse.parse_in_context ctxt q)
 in
    CHOOSE_THEN (fn th => SUBST_ALL_TAC th THEN ASSUME_TAC th)
    (Thm.EXISTS (mk_exists(lhs, mk_eq(rhs,lhs)),rhs) (Thm.REFL rhs))
    g
 end;

fun UNABBREV_TAC [QUOTE s] = let val s' = Lib.deinitcomment s in
        FIRST_ASSUM(SUBST1_TAC o SYM o
             assert(curry op = s' o fst o dest_var o rhs o concl))
         THEN BETA_TAC end
  | UNABBREV_TAC _ = raise Q_ERR "UNABBREV_TAC" "unexpected quote format"

fun find' f [] = NONE
  | find' f (h::t) = case f h of NONE => find' f t | x => x

fun PAT_ABBREV_TAC q (g as (asl, w)) =
    let val fv_set = FVL (w::asl) empty_tmset
        val ctxt = HOLset.listItems fv_set
        val (l,r) = dest_eq(Parse.parse_in_context ctxt q)
        fun matchr t = raw_match [] fv_set r t ([],[])
        val l = variant (HOLset.listItems (FVL [r] fv_set)) l
    in
      case find' (Lib.total (find_term (can matchr))) (w::asl) of
        NONE => raise Q_ERR "PAT_ABBREV_TAC" "No matching term found"
      | SOME t =>
        CHOOSE_THEN (fn th => SUBST_ALL_TAC th THEN ASSUME_TAC th)
                    (Thm.EXISTS (mk_exists(l, mk_eq(t, l)), t)
                                (Thm.REFL t)) g
    end

end; (* Q *)
