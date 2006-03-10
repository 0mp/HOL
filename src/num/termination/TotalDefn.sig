signature TotalDefn =
sig

  include Abbrev

   (* Support for automated termination proofs *)

   val guessR        : defn -> term list
   val proveTotal    : tactic -> defn -> defn * thm 


   (* Support for interactive termination proofs *)

   val default_WF_thms : thm list ref
   val default_termination_simps : thm list ref

   val PRIM_WF_TAC   : thm list -> tactic
   val PRIM_TC_SIMP_CONV  : thm list -> conv
   val PRIM_TC_SIMP_TAC   : thm list -> tactic
   val PRIM_WF_REL_TAC    : term quotation -> thm list -> thm list -> tactic

   val WF_TAC        : tactic
   val TC_SIMP_CONV  : conv
   val TC_SIMP_TAC   : tactic
   val WF_REL_TAC    : term quotation -> tactic

   (* Definitions with automated termination proof support *)

   val primDefine    : defn -> thm * thm option * thm option
   val xDefine       : string -> term quotation -> thm
   val Define        : term quotation -> thm
   val xDefineSchema : string -> term quotation -> thm
   val DefineSchema  : term quotation -> thm

   val SUC_TO_NUMERAL_DEFN_CONV : conv

end
