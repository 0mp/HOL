(*---------------------------------------------------------------------------
       Internal interfaces to HOL kernel structures.
 ---------------------------------------------------------------------------*)

signature RawType =
sig
  type hol_type = KernelTypes.hol_type
  structure TypeSig : Sig where type ty = KernelTypes.tyconst
  val mk_vartype    : string -> hol_type
  val gen_tyvar     : unit -> hol_type
  val dest_vartype  : hol_type -> string
  val is_vartype    : hol_type -> bool
  val is_gen_tyvar  : hol_type -> bool
  val mk_thy_type   : {Thy:string, Tyop:string, Args:hol_type list} -> hol_type
  val dest_thy_type : hol_type -> {Thy:string, Tyop:string, Args:hol_type list}
  val mk_type       : string * hol_type list -> hol_type
  val dest_type     : hol_type -> string * hol_type list
  val break_type    : hol_type -> KernelTypes.tyconst * hol_type list
  val decls         : string -> {Thy:string, Tyop:string} list
  val is_type       : hol_type -> bool
  val polymorphic   : hol_type -> bool
  val compare       : hol_type * hol_type -> order
  val ty_sub        : (hol_type,hol_type)Lib.subst 
                        -> hol_type -> hol_type Lib.delta
  val type_subst    : (hol_type,hol_type)Lib.subst -> hol_type -> hol_type
  val type_vars     : hol_type -> hol_type list
  val type_varsl    : hol_type list -> hol_type list
  val type_var_in   : hol_type -> hol_type -> bool
  val exists_tyvar  : (hol_type -> bool) -> hol_type -> bool
  val -->           : hol_type * hol_type -> hol_type  (* infixr 3 --> *)
  val dom_rng       : hol_type -> hol_type * hol_type  (* inverts -->  *)
  val ind           : hol_type
  val bool          : hol_type
  val alpha         : hol_type 
  val beta          : hol_type
  val gamma         : hol_type
  val delta         : hol_type
  val tymatch       : hol_type -> hol_type 
                        -> (hol_type,hol_type) Lib.subst * hol_type list
                         -> (hol_type,hol_type) Lib.subst * hol_type list
  val match_type    : hol_type -> hol_type -> (hol_type,hol_type)Lib.subst
  val thy_types     : string -> (string * int) list
end;


signature RawTerm =
sig
  type hol_type = KernelTypes.hol_type
  type term = KernelTypes.term
  type ('a,'b)subst = ('a,'b)Lib.subst

  structure TermSig : Sig where type ty = KernelTypes.term

  val type_of       : term -> hol_type
  val free_vars     : term -> term list
  val free_vars_lr  : term -> term list
  val free_in       : term -> term -> bool
  val all_vars      : term -> term list
  val free_varsl    : term list -> term list
  val all_varsl     : term list -> term list
  val type_vars_in_term : term -> hol_type list
  val tyvar_occurs  : hol_type -> term -> bool
  val var_occurs    : term -> term -> bool
  val existsFV      : (string * hol_type -> bool) -> term -> bool
  val existsTYV     : (hol_type -> bool) -> term -> bool
  val genvar        : hol_type -> term
  val genvars       : hol_type -> int -> term list
  val variant       : term list -> term -> term
  val prim_variant  : term list -> term -> term
  val mk_var        : string * hol_type -> term
  val mk_primed_var : string * hol_type -> term
  val decls         : string -> term list
  val all_consts    : unit -> term list
  val prim_mk_const : {Thy:string,Name:string} -> term
  val mk_thy_const  : {Thy:string, Name:string, Ty:hol_type} -> term
  val dest_thy_const: term -> {Thy:string, Name:string, Ty:hol_type}
  val mk_const      : string * hol_type -> term
  val list_mk_comb  : term * term list -> term
  val mk_comb       : term * term -> term
  val mk_abs        : term * term -> term
  val dest_var      : term -> string * hol_type
  val dest_const    : term -> string * hol_type
  val dest_comb     : term -> term * term
  val dest_abs      : term -> term * term
  val is_var        : term -> bool
  val is_genvar     : term -> bool
  val is_const      : term -> bool
  val is_comb       : term -> bool
  val is_abs        : term -> bool
  val rator         : term -> term
  val rand          : term -> term
  val bvar          : term -> term
  val body          : term -> term
  val is_bvar       : term -> bool
  val aconv         : term -> term -> bool
  val beta_conv     : term -> term
  val eta_conv      : term -> term
  val subst         : (term,term) Lib.subst -> term -> term
  val inst          : (hol_type,hol_type) Lib.subst -> term -> term
  val raw_match     : term -> term
                       -> (term,term)Lib.subst 
                           * ((hol_type,hol_type)Lib.subst * hol_type list)
                        -> (term,term)Lib.subst 
                            * ((hol_type,hol_type)Lib.subst * hol_type list)
  val match_term     : term -> term 
                       -> (term,term)Lib.subst * (hol_type,hol_type)Lib.subst
  val norm_subst    : (hol_type,hol_type)subst 
                        -> (term,term)subst -> (term,term)subst
  val thy_consts     : string -> term list
  val compare        : term * term -> order
  val is_clos        : term -> bool
  val push_clos      : term -> term
  val norm_clos      : term -> term
  val lazy_beta_conv : term -> term
  val imp            : term
  val dest_eq_ty     : term -> term * term * hol_type
  val prim_mk_eq     : hol_type -> term -> term -> term
  val prim_mk_imp    : term -> term -> term
  val break_const    : term -> KernelTypes.id * hol_type
  val break_abs      : term -> term 
  val trav           : (term -> unit) -> term -> unit
  val pp_raw_term    : (term -> int) -> Portable.ppstream -> term -> unit
end;


signature RawTag =
sig
  type tag = KernelTypes.tag
  val std_tag       : tag
  val ax_tag        : string ref -> tag
  val merge         : tag -> tag -> tag
  val read          : string -> tag
  val read_disk_tag : string -> tag
  val axioms_of     : tag -> string ref list
  val pp_tag        : Portable.ppstream -> tag -> unit
  val pp_to_disk    : Portable.ppstream -> tag -> unit
end 


signature RawThm =
sig
  type thm
  type tag      = KernelTypes.tag
  type term     = KernelTypes.term
  type hol_type = KernelTypes.hol_type

  val tag           : thm -> tag
  val hyp           : thm -> term list
  val concl         : thm -> term
  val dest_thm      : thm -> term list * term
  val thm_frees     : thm -> term list
  val ASSUME        : term -> thm
  val REFL          : term -> thm
  val BETA_CONV     : term -> thm
  val ABS           : term -> thm -> thm
  val DISCH         : term -> thm -> thm
  val MP            : thm -> thm -> thm
  val SUBST         : (term,thm)Lib.subst -> term -> thm -> thm
  val INST_TYPE     : (hol_type,hol_type)Lib.subst -> thm -> thm
  val ALPHA         : term -> term -> thm
  val MK_COMB       : thm * thm -> thm
  val AP_TERM       : term -> thm -> thm
  val AP_THM        : thm -> term -> thm
  val ETA_CONV      : term -> thm
  val SYM           : thm -> thm
  val TRANS         : thm -> thm -> thm
  val EQ_MP         : thm -> thm -> thm
  val EQ_IMP_RULE   : thm -> thm * thm
  val INST          : (term,term)Lib.subst -> thm -> thm
  val SPEC          : term -> thm -> thm
  val GEN           : term -> thm -> thm
  val EXISTS        : term * term -> thm -> thm
  val CHOOSE        : term * thm -> thm -> thm
  val CONJ          : thm -> thm -> thm
  val CONJUNCT1     : thm -> thm
  val CONJUNCT2     : thm -> thm
  val DISJ1         : thm -> term -> thm
  val DISJ2         : term -> thm -> thm
  val DISJ_CASES    : thm -> thm -> thm -> thm
  val NOT_INTRO     : thm -> thm
  val NOT_ELIM      : thm -> thm
  val CCONTR        : term -> thm -> thm
  val Beta          : thm -> thm
  val Eta           : thm -> thm
  val Mk_comb       : thm -> thm * thm * (thm -> thm -> thm)
  val Mk_abs        : thm -> term * thm * (thm -> thm)
  val Spec          : term -> thm -> thm
  val mk_oracle_thm : tag -> term list * term -> thm
  val mk_thm        : term list * term -> thm
  val mk_axiom_thm  : string ref * term -> thm
  val mk_defn_thm   : tag * term -> thm
  val disk_thm      : term vector 
                       -> string * 'a frag list list * 'a frag list -> thm
end;

signature RawTheoryPP =
sig
 type thm      = KernelTypes.thm
 type hol_type = KernelTypes.hol_type
 type ppstream = Portable.ppstream

 val pp_type : string -> string -> ppstream -> hol_type -> unit
 val pp_sig :
   (ppstream -> thm -> unit)
    -> {name        : string,
        parents     : string list,
        axioms      : (string * thm) list,
        definitions : (string * thm) list,
        theorems    : (string * thm) list,
        sig_ps      : (ppstream -> unit) option list} 
    -> ppstream 
    -> unit

 val pp_struct :
   {theory      : string*int*int,
    parents     : (string*int*int) list,
    types       : (string*int) list,
    constants   : (string*hol_type) list,
    axioms      : (string * thm) list,
    definitions : (string * thm) list,
    theorems    : (string * thm) list,
    struct_ps   : (ppstream -> unit) option list} 
  -> ppstream
  -> unit
end


signature RawTheory =
sig
  type hol_type = KernelTypes.hol_type
  type term     = KernelTypes.term
  type thm      = KernelTypes.thm
  type witness  = KernelTypes.witness
  type ppstream = Portable.ppstream
  type thy_addon = {sig_ps    : (ppstream -> unit) option,
                    struct_ps : (ppstream -> unit) option}
 
  val new_type       : string * int -> unit
  val new_constant   : string * hol_type -> unit
  val new_axiom      : string * term -> thm
  val save_thm       : string * thm -> thm
  val delete_type    : string -> unit
  val delete_const   : string -> unit
  val delete_definition : string -> unit
  val delete_axiom   : string -> unit
  val delete_theorem : string -> unit
  val current_theory : unit -> string
  val parents        : string -> string list
  val ancestry       : string -> string list
  val types          : string -> (string * int) list
  val constants      : string -> term list
  val axioms         : unit -> (string * thm) list
  val definitions    : unit -> (string * thm) list
  val theorems       : unit -> (string * thm) list
  val axiom          : string -> thm
  val definition     : string -> thm
  val theorem        : string -> thm
  val new_theory     : string -> unit
  val after_new_theory : (string -> unit) -> unit
  val adjoin_to_theory : thy_addon -> unit
  val export_theory    : unit -> unit
  val pp_thm           : (ppstream -> thm -> unit) ref
  val link_parents     : string*int*int -> (string*int*int)list -> unit
  val incorporate_types  : string -> (string*int) list -> unit
  val incorporate_consts : string -> (string*hol_type)list -> unit
  val uptodate_type      : hol_type -> bool
  val uptodate_term      : term -> bool
  val uptodate_thm       : thm -> bool
  val scrub              : unit -> unit
  val set_MLname : string -> string -> unit
  val store_definition : string * string list * witness * thm -> thm
  val store_type_definition : string * string * witness * thm -> thm
end


signature RawDefinition =
sig
  type term = KernelTypes.term
  type thm  = KernelTypes.thm

  val new_type_definition : string * thm -> thm
  val new_specification   : string * string list * thm -> thm
  val new_definition      : string * term -> thm
  val new_definition_hook : ((term -> term list * term) *
                             (term list * thm -> thm)) ref
end

signature RawNet =
sig
  type 'a net
  type term = KernelTypes.term

  val empty     : 'a net
  val insert    : term * 'a -> 'a net -> 'a net
  val match     : term -> 'a net -> 'a list
  val index     : term -> 'a net -> 'a list
  val delete    : term * ('a -> bool) -> 'a net -> 'a net
  val filter    : ('a -> bool) -> 'a net -> 'a net
  val union     : 'a net -> 'a net -> 'a net
  val map       : ('a -> 'b) -> 'a net -> 'b net
  val itnet     : ('a -> 'b -> 'b) -> 'a net -> 'b -> 'b
  val size      : 'a net -> int
  val listItems : 'a net -> 'a list
  val enter     : term * 'a -> 'a net -> 'a net  (* for compatibility *)
  val lookup    : term -> 'a net -> 'a list      (* for compatibility *)
end
