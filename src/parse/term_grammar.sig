signature term_grammar = sig

  type block_info = PP.break_style * int
  datatype rule_element = TOK of string | TM
  datatype pp_element =
    PPBlock of pp_element list * block_info |
    EndInitialBlock of block_info | BeginFinalBlock of block_info |
    HardSpace of int | BreakSpace of (int * int) |
    RE of rule_element | LastTM | FirstTM
  (* these last two only used internally *)

  datatype PhraseBlockStyle =
    AroundSameName | AroundSamePrec | AroundEachPhrase
  datatype ParenStyle =
    Always | OnlyIfNecessary | ParoundName | ParoundPrec

  val rule_elements : pp_element list -> rule_element list
  val pp_elements_ok : pp_element list -> bool


  val reltoString : rule_element -> string

  type rule_record = {term_name : string,
                      elements : pp_element list,
                      preferred : bool,
                      block_style : PhraseBlockStyle * block_info,
                      paren_style : ParenStyle}

datatype binder = LAMBDA | BinderString of string
datatype prefix_rule = STD_prefix of rule_record list | BINDER of binder list
datatype suffix_rule = STD_suffix of rule_record list | TYPE_annotation
datatype infix_rule =
  STD_infix of rule_record list * HOLgrammars.associativity |
  RESQUAN_OP

type listspec =
  {separator : string, leftdelim : string, rightdelim : string,
   cons : string, nilstr : string}

datatype grammar_rule =
  PREFIX of prefix_rule
| SUFFIX of suffix_rule
| INFIX of infix_rule
| CLOSEFIX of rule_record list
| FNAPP | VSCONS
| LISTRULE of listspec list

type grammar
type overload_info = Overload.overload_info

val rules : grammar -> (int option * grammar_rule) list
val grammar_rules : grammar -> grammar_rule list
val specials : grammar -> {type_intro : string,
                           lambda     : string,
                           endbinding : string,
                           restr_binders : (binder * string) list,
                           res_quanop : string
                           }
val numeral_info : grammar -> (char * string option) list
val overload_info : grammar -> overload_info
val fupdate_overload_info :
  (overload_info -> overload_info) -> grammar -> grammar

(* known constants are those strings that the parsing process will
   attempt to turn into constants.  This is independent of overloading;
   because overloading is always over constants (something fixed by
   design, but possibly open to change), an overloaded string will
   always get resolved to a constant.  Non-overloaded strings will
   only get resolved to constants if they appear in the "known constants"
   list. *)
val known_constants : grammar -> string list
val hide_constant : string -> grammar -> grammar
val show_constant : string -> grammar -> grammar
val fupdate_known_constants :
  (string list -> string list) -> grammar -> grammar

val binders : grammar -> string list
val is_binder : grammar -> string -> bool
val binder_to_string : grammar -> binder -> string

val resquan_op : grammar -> string
val associate_restriction : grammar -> binder * string -> grammar

val compatible_listrule :
  grammar -> {separator : string, leftdelim : string, rightdelim : string} ->
  {cons : string, nilstr : string} option

datatype stack_terminal =
  STD_HOL_TOK of string | BOS | EOS | Id  | TypeColon | TypeTok | EndBinding |
  VS_cons | ResquanOpTok

val STtoString : grammar -> stack_terminal -> string
val stdhol : grammar

val grammar_tokens : grammar -> string list
val rule_tokens : grammar -> grammar_rule -> string list
val find_suffix_rhses : grammar -> stack_terminal list
val find_prefix_lhses : grammar -> stack_terminal list

val add_binder : grammar -> (string * int) -> grammar
val add_listform : grammar -> {separator : string, leftdelim : string,
                               rightdelim : string, cons : string,
                               nilstr : string} -> grammar
datatype rule_fixity =
  Infix of HOLgrammars.associativity * int |
  Closefix |
  Suffix of int |
  TruePrefix of int

val rule_fixityToString : rule_fixity -> string
val add_rule :
  grammar -> {term_name : string, fixity : rule_fixity,
              pp_elements: pp_element list, paren_style : ParenStyle,
              block_style : PhraseBlockStyle * block_info} -> grammar
val add_grule : grammar -> (int option * grammar_rule) -> grammar

val add_numeral_form : grammar -> (char * string option) -> grammar
val give_num_priority : grammar -> char -> grammar
val remove_numeral_form : grammar -> char -> grammar

(* this removes all those rules which give special status to the
   given string.  If there is a rule saying that COND is written
      if _ then _ else _
   you could get rid of it with
      remove_standard_form G "COND"
*)
val remove_standard_form : grammar -> string -> grammar

(* this one removes those rules relating to the term which also include
   a token of the form given.  Thus, if you had two rules for COND, and you
   wanted to get rid of the one with the "if" token in it, you would
   use
     remove_form_with_tok G {term_name = "COND", tok = "if"}
*)
val remove_form_with_tok :
  grammar -> {term_name : string, tok: string} -> grammar

(* for pretty-printing *)
val clear_prefs_for : string -> grammar -> grammar
val prefer_form_with_tok :
  grammar -> {term_name : string, tok : string} -> grammar


val set_associativity_at_level :
  grammar -> (int * HOLgrammars.associativity) -> grammar
val get_precedence : grammar -> string -> rule_fixity option

val merge_grammars : (grammar * grammar) -> grammar

val prettyprint_grammar : Portable.ppstream -> grammar -> unit

end