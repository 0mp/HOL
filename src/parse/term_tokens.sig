signature term_tokens =
sig

  datatype 'a term_token =
    Ident of string
  | Antiquote of 'a
  | Numeral of (string * char option)
  | QIdent of (string * string)

  val lex : string list -> 'a qbuf.qbuf -> 'a term_token option
      (* NONE indicates end of input; this function *always* advances over
         what it fulls out of the qbuf.   *)

  val token_string : 'a term_token -> string
  val dest_aq      : 'a term_token -> 'a
  val is_ident     : 'a term_token -> bool
  val is_aq        : 'a term_token -> bool



end

