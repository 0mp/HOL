signature parse_term = sig
    type 'a PStack
    type 'a qbuf= 'a qbuf.qbuf
    val initial_pstack : 'a PStack
    val is_final_pstack : 'a PStack -> bool
    val top_nonterminal : Term.term PStack -> Absyn.absyn

    exception PrecConflict of
      term_grammar.stack_terminal * term_grammar.stack_terminal
    exception ParseTermError of string locn.located

    val mk_prec_matrix :
        term_grammar.grammar ->
        (term_grammar.stack_terminal * term_grammar.stack_terminal, order)
          Polyhash.hash_table

    val parse_term :
      term_grammar.grammar ->
      (''a qbuf -> Pretype.pretype) ->
      (''a qbuf * ''a PStack) ->
      (''a qbuf * ''a PStack) * unit option

end

