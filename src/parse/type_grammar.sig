signature type_grammar =
sig

  type kernelname = KernelSig.kernelname

  datatype grammar_rule = datatype type_grammar_dtype.grammar_rule
  datatype type_structure = datatype type_grammar_dtype.type_structure
  datatype delta = datatype type_grammar_dtype.delta

  type grammar

  val structure_to_type : type_structure -> Type.hol_type

  val empty_grammar    : grammar
  val min_grammar      : grammar
  val rules            : grammar -> {infixes: (int * grammar_rule) list,
                                     suffixes : string list}
  val parse_map    : grammar -> (kernelname,type_structure) Binarymap.dict
  val privileged_abbrevs : grammar -> (string,string) Binarymap.dict

  val abb_dest_type : grammar -> Type.hol_type ->
                      {Thy : string option, Tyop : string,
                       Args : Type.hol_type list}
  val disable_abbrev_printing : string -> grammar -> grammar

  val new_binary_tyop  : grammar
                          -> {precedence : int,
                              infix_form : string option,
                              opname : string,
                              associativity : HOLgrammars.associativity}
                          -> grammar

  val remove_binary_tyop : grammar -> string -> grammar
  (* removes by infix symbol, i.e. "+", not "sum" *)

  val new_qtyop        : kernelname -> grammar -> grammar
  val hide_tyop        : string -> grammar -> grammar
  val new_abbreviation : grammar -> kernelname * type_structure -> grammar
  val remove_abbreviation : grammar -> string -> grammar
  val num_params : type_structure -> int

  val merge_grammars   : grammar * grammar -> grammar

  val prettyprint_grammar   : Portable.ppstream -> grammar -> unit
  val initialise_typrinter
    : (grammar -> Portable.ppstream -> Type.hol_type -> unit) -> unit

end
