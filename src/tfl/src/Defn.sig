signature Defn =
sig
  include Abbrev

  type thry   = TypeBasePure.typeBase
  type proofs = GoalstackPure.proofs
  type absyn  = Absyn.absyn

  val monitoring : bool ref

  val ind_suffix : string ref
  val def_suffix : string ref

  val mk_defn    : string -> term -> defn
  val mk_Rdefn   : string -> term -> term -> defn
  val Hol_defn   : string -> term quotation -> defn
  val Hol_Rdefn  : string -> term quotation -> term quotation -> defn

  val name_of    : defn -> string
  val eqns_of    : defn -> thm list
  val ind_of     : defn -> thm option
  val tcs_of     : defn -> term list
  val reln_of    : defn -> term option
  val params_of  : defn -> term list

  val aux_defn   : defn -> defn option
  val union_defn : defn -> defn option

  val inst_defn  : defn -> (term,term)subst * (hol_type,hol_type)subst -> defn
  val set_reln   : defn -> term -> defn

  val elim_tcs   : defn -> thm list -> defn
  val simp_tcs   : defn -> conv -> defn
  val prove_tcs  : defn -> tactic -> defn

  val save_defn  : defn -> unit

  val parse_defn : term quotation -> term * string list

  val tgoal      : defn -> proofs
  val tprove     : defn * tactic -> thm * thm
  val tstore_defn : defn * tactic -> thm * thm


   (* Historical relics *)

   val prim_wfrec_definition :
        thry -> string
             -> {R:term, functional:term}
             -> {def:thm, corollary:thm, theory:thry}

   val gen_wfrec_definition :
         thry -> string
              -> {R:term, eqs:term}
              -> {rules : thm,
                  TCs : term list list,
                  full_pats_TCs : (term * term list) list,
                  patterns : Functional.pattern list,
                  theory:thry}

end
