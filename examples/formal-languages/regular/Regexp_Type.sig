signature Regexp_Type =
sig

 type charset = LargeWord.word * LargeWord.word * LargeWord.word * LargeWord.word
(* type charset = IntInf.int *)

 datatype regexp
    = Chset of charset
    | Cat of regexp * regexp
    | Star of regexp
    | Or of regexp list
    | Neg of regexp

 val alphabet_size : int
 val alphabet : char list

 (* charsets *)
 val charset_empty   : charset
 val charset_full    : charset
 val charset_mem     : char -> charset -> bool
 val charset_of      : char list -> charset
 val charset_elts    : charset -> char list

 val charset_insert  : char -> charset -> charset
 val charset_sing    : char -> charset
 val charset_union   : charset -> charset -> charset
 val charset_diff    : charset -> charset -> charset
 val charset_compare : charset * charset -> order

 val regexp_compare : regexp * regexp -> order

 (* derived syntax *)
 val And  : regexp * regexp -> regexp
 val Diff : regexp * regexp -> regexp

 (* predeclared regexps *)
 val WHITESPACE : regexp
 val DIGIT      : regexp
 val ALPHA      : regexp
 val ALPHANUM   : regexp
 val EMPTY      : regexp
 val SIGMA      : regexp
 val DOT        : regexp
 val EPSILON    : regexp
 val SIGMASTAR  : regexp

 (* parsing *)

 datatype direction = MSB | LSB

 datatype packelt
   = Span of IntInf.int * IntInf.int
   | Pad of Int.int;

 datatype tree
   = Ap of string * tree list
   | Cset of charset
   | Ident of char
   | Power of tree * int
   | Range of tree * int option * int option
   | Interval of IntInf.int * IntInf.int * direction
   | Const of IntInf.int * direction
   | Pack of packelt list

 val tree_parse        : substring -> tree list * substring
 val substring_to_tree : substring -> tree
 val quote_to_tree     : 'a frag list -> tree

 val tree_to_regexp : tree -> regexp

 val fromSubstring : substring -> regexp
 val fromString    : string -> regexp
 val fromQuote     : 'a frag list -> regexp

 val pp_regexp     : HOLPP.ppstream -> regexp -> unit
 val print_regexp  : regexp -> unit
 val println_regexp  : regexp -> unit

end
