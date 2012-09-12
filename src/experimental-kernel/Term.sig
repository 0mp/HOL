signature Term =
sig

  include FinalTerm where type hol_type = Type.hol_type
                      and type kind     = Kind.kind
                      and type rank     = Rank.rank

  val prim_mk_eq        : hol_type -> term -> term -> term
  val prim_mk_imp       : term -> term -> term
  val imp               : term
  val dest_eq_ty        : term -> term * term * hol_type
  val lazy_beta_conv    : term -> term

  val term_to_string: term -> string

end
