structure Parse :> Parse =
struct

open Feedback HolKernel HOLgrammars GrammarSpecials term_grammar
infixr -->

type pp_element = term_grammar.pp_element
type PhraseBlockStyle = term_grammar.PhraseBlockStyle
type ParenStyle = term_grammar.ParenStyle
type block_info = term_grammar.block_info
type associativity = HOLgrammars.associativity

val ERROR = mk_HOL_ERR "Parse";
val WARN  = HOL_WARNING "Parse"


val quote = Lib.mlquote

datatype fixity = RF of term_grammar.rule_fixity | Prefix | Binder

fun acc_strip_comb M rands =
  let val {Rator,Rand} = dest_comb M
  in acc_strip_comb Rator (Rand::rands)
  end
  handle HOL_ERR _ => (M,rands);

fun strip_comb tm = acc_strip_comb tm [];

val dest_forall = dest_binder ("!","bool") (ERROR"dest_forall" "");

fun strip_forall fm =
 let val {Bvar,Body} = dest_forall fm
     val (bvs,core) = strip_forall Body
 in (Bvar::bvs, core)
 end handle HOL_ERR _ => ([],fm);

fun lhs tm = #2(dest_binop("=","min") (ERROR"lhs" "") tm);

fun ftoString [] = ""
  | ftoString (QUOTE s :: rest) = s ^ ftoString rest
  | ftoString (ANTIQUOTE x :: rest) = "..." ^ ftoString rest

(*---------------------------------------------------------------------------
    Fixity stuff
 ---------------------------------------------------------------------------*)

datatype fixity
    = RF of rule_fixity
    | Prefix
    | Binder

fun Infix x = x;  (* namespace hackery *)
fun Suffix x = x;
fun Closefix x = x;
fun TruePrefix x = x;

val Infix        = fn (a,i) => RF (term_grammar.Infix (a,i))
val Infixl       = fn i => Infix(LEFT, i)
val Infixr       = fn i => Infix(RIGHT, i)
val Suffix       = fn n => RF (term_grammar.Suffix n)
val Closefix     = RF term_grammar.Closefix
val TruePrefix   = fn n => RF (term_grammar.TruePrefix n)


(*---------------------------------------------------------------------------
         pervasive type grammar
 ---------------------------------------------------------------------------*)

(* type grammar *)
val the_type_grammar = ref parse_type.empty_grammar
val type_grammar_changed = ref false
fun type_grammar() = !the_type_grammar

(*---------------------------------------------------------------------------
         pervasive term grammar
 ---------------------------------------------------------------------------*)

val the_term_grammar = ref term_grammar.stdhol
val term_grammar_changed = ref false
fun term_grammar () = (!the_term_grammar)

fun current_grammars() = (type_grammar(), term_grammar());

(*---------------------------------------------------------------------------
         local grammars
 ---------------------------------------------------------------------------*)

val the_lty_grm = ref parse_type.empty_grammar
val the_ltm_grm = ref term_grammar.stdhol
fun current_lgrms() = (!the_lty_grm, !the_ltm_grm);


fun fixity s =
  case term_grammar.get_precedence (term_grammar()) s
   of SOME rf => RF rf
    | NONE => if Lib.mem s (term_grammar.binders (term_grammar()))
                 then Binder
                 else Prefix

(*---------------------------------------------------------------------------
       Mysterious stuff
 ---------------------------------------------------------------------------*)

(* type parsing *)
fun remove_ty_aq t =
  if is_ty_antiq t then dest_ty_antiq t
  else raise ERROR "type parser" "antiquotation is not of a type"


val typ1_rec = {vartype = Pretype.Vartype, tyop = Pretype.Tyop,
                antiq = Pretype.fromType o remove_ty_aq}

val typ2_rec = {vartype = Pretype.Vartype, tyop = Pretype.Tyop,
                antiq = Pretype.fromType}

val type_parser1 =
  ref (parse_type.parse_type typ1_rec false (type_grammar()))

val type_parser2 =
  ref (parse_type.parse_type typ2_rec false (type_grammar()))


(*---------------------------------------------------------------------------
        pretty printing types
 ---------------------------------------------------------------------------*)

val type_printer = ref (type_pp.pp_type (type_grammar()))
val grammar_term_printer =
  ref (term_pp.pp_term (term_grammar()) (type_grammar()))
fun pp_grammar_term pps t = (!grammar_term_printer) pps t
val term_printer = ref pp_grammar_term

fun get_term_printer () = (!term_printer)

fun set_term_printer new_pp_term = let
  val old_pp_term = !term_printer
in
  term_printer := new_pp_term;
  old_pp_term
end



fun update_type_fns () =
  if !type_grammar_changed then let in
     type_parser1 := parse_type.parse_type typ1_rec false (type_grammar());
     type_parser2 := parse_type.parse_type typ2_rec false (type_grammar());
     type_printer := type_pp.pp_type (type_grammar());
     type_grammar_changed := false
  end
  else ()

fun pp_type pps ty = let in
   update_type_fns();
   Portable.add_string pps ":";
   !type_printer pps ty
 end

val type_to_string = Portable.pp_to_string 75 pp_type
fun print_type ty = Portable.output(Portable.std_out, type_to_string ty);

fun type_pp_with_delimiters ppfn pp ty =
  let open Portable Globals
  in add_string pp (!type_pp_prefix);
     ppfn pp ty;
     add_string pp (!type_pp_suffix)
  end


fun pp_with_bquotes ppfn pp x =
  let open Portable in add_string pp "`"; ppfn pp x; add_string pp "`" end

fun print_from_grammars (tyG, tmG) =
  (type_pp.pp_type tyG, term_pp.pp_term tmG tyG)


(*---------------------------------------------------------------------------
              Parsing types
 ---------------------------------------------------------------------------*)

local open parse_type
in
fun parse_Type parser q =
 let open optmonad monadic_parse fragstr
     infix >> >->
     val (rest, parse_result) = (parse (token (item #":") >> parser)) q
 in
   case parse_result
    of SOME pt => Pretype.toType pt
     | NONE =>
        let val errstring = String.concat
           ["Couldn't make any sense with remaining input of ",
            Lib.quote (ftoString rest)]
        in
           raise ERROR "hol_type parser" errstring
        end
 end
end;

fun Type q = let in
   update_type_fns();
   parse_Type (!type_parser2) q
 end

fun == q x = Type q;


(*---------------------------------------------------------------------------
             Parsing into abstract syntax
 ---------------------------------------------------------------------------*)

fun do_parse G ty =
 let open optmonad parse_term
     val pt = parse_term G ty
              handle PrecConflict(st1, st2)
              => raise ERROR "Term" (String.concat
                 ["Grammar introduces precedence conflict between tokens ",
                  term_grammar.STtoString G st1, " and ",
                  term_grammar.STtoString G st2])
 in fn q =>
  let val ((cs,p), _) = pt (q, initial_pstack)
        handle term_tokens.LEX_ERR s =>
          raise ERROR "term parser" ("Lexical error - "^s)
  in
  if is_final_pstack p then
  let infix ++ >>
      open fragstr
  in case (many (comment ++ grab_whitespace) >> eof) cs
      of (_,SOME _) =>
           (top_nonterminal p handle ParseTermError s => raise ERROR "Term" s)
       | (_,NONE) => raise ERROR "term parser" (String.concat
                ["Can't make sense of remaining: ", Lib.quote (ftoString cs)])
  end
  else raise ERROR "term parser" (String.concat
           ["Parse failed with ", Lib.quote(ftoString cs), " remaining"])
 end end;


val the_absyn_parser: (term frag list -> Absyn.absyn) ref =
    ref (do_parse (!the_term_grammar) (!type_parser1))

fun update_term_fns() = let
  val _ = update_type_fns()
in
  if !term_grammar_changed then let
  in
    grammar_term_printer := term_pp.pp_term (term_grammar()) (type_grammar());
    the_absyn_parser := do_parse (!the_term_grammar) (!type_parser1);
    term_grammar_changed := false
  end
  else ()
end

(*---------------------------------------------------------------------------
      Interlude: prettyprinting terms and theorems
 ---------------------------------------------------------------------------*)

fun pp_term pps t = let in update_term_fns(); !term_printer pps t end
fun term_to_string t = Portable.pp_to_string (!Globals.linewidth) pp_term t;
fun print_term t = Portable.output(Portable.std_out, term_to_string t);

fun term_pp_with_delimiters ppfn pp tm =
  let open Portable Globals
  in add_string pp (!term_pp_prefix);
     ppfn pp tm;
     add_string pp (!term_pp_suffix)
  end

fun pp_thm ppstrm th =
 let open Portable
    fun repl ch alist =
         String.implode (itlist (fn _ => fn chs => (ch::chs)) alist [])
    val {add_string,add_break,begin_block,end_block,...} = with_ppstream ppstrm
    val pp_term = pp_term ppstrm
    fun pp_terms b L =
      (begin_block INCONSISTENT 1; add_string "[";
       if b then pr_list pp_term (fn () => add_string ",")
                                 (fn () => add_break(1,0)) L
       else add_string (repl #"." L); add_string "]";
       end_block())
 in
    begin_block INCONSISTENT 0;
    if !Globals.max_print_depth = 0 then add_string " ... "
    else let open Globals
             val (tg,asl,st,sa) = (tag th, hyp th, !show_tags, !show_assums)
         in if not st andalso not sa andalso null asl then ()
            else (if st then Tag.pp_tag ppstrm tg else ();
                  add_break(1,0);
                  pp_terms sa asl; add_break(1,0)
                 );
            add_string "|- ";
            pp_term (concl th)
         end;
    end_block()
 end;

fun thm_to_string thm = Portable.pp_to_string (!Globals.linewidth) pp_thm thm;
fun print_thm thm     = Portable.output(Portable.std_out, thm_to_string thm);

(*---------------------------------------------------------------------------
       Construction of the term parser
 ---------------------------------------------------------------------------*)

fun to_vstruct t = let
  open Absyn
  fun ultimately s (IDENT s')      = (s = s')
    | ultimately s (TYPED (t', _)) = ultimately s t'
    | ultimately s _ = false
in
  case t of
    IDENT s      => VIDENT s
  | TYPED (t,ty) => VTYPED(to_vstruct t, ty)
  | AQ x         => VAQ x
  | APP(APP(comma, t1), t2) =>
      if ultimately "," comma then VPAIR(to_vstruct t1, to_vstruct t2)
      else raise Fail "term not suitable as varstruct"
  | _ => raise Fail "term not suitable as varstruct"
end

fun reform_def (t1, t2) =
 (to_vstruct t1, t2)
  handle Fail _ =>
   let open Absyn
       val (f, args) = strip_app t1
       val newrhs = List.foldr (fn (a,body) => LAM(to_vstruct a,body)) t2 args
   in (to_vstruct f, newrhs)
   end

fun munge_let binding_term body = let
  open Absyn
  fun strip_and(APP(APP(IDENT"and",t1),t2)) A = strip_and t1 (strip_and t2 A)
    | strip_and tm acc = tm::acc
  val binding_clauses = strip_and binding_term []
  fun is_eq tm = case tm of APP(APP(IDENT "=", _), _) => true | _ => false
  fun dest_eq (APP(APP(IDENT "=", t1), t2)) = (t1, t2)
    | dest_eq _ = raise Fail "(pre-)term not an equality"
  val _ = List.all is_eq binding_clauses
    orelse raise ERROR "Term" "let with non-equality"
  val (L,R) = ListPair.unzip (map (reform_def o dest_eq) binding_clauses)
  val central_abstraction = List.foldr LAM body L
in
  List.foldl (fn(arg, b) => APP(APP(IDENT "LET", b), arg))
  central_abstraction R
end

fun traverse applyp f t = let
  open Absyn
  val traverse = traverse applyp f
in
  if applyp t then f traverse t
  else case t of
    APP(t1,t2)   => APP(traverse t1, traverse t2)
  | LAM(vs,t)    => LAM(vs, traverse t)
  | TYPED(t,pty) => TYPED(traverse t, pty)
  | allelse      => allelse
end


fun remove_lets t0 = let
  open Absyn
  fun let_remove f (APP(APP(IDENT "let", t1), t2)) = munge_let (f t1) (f t2)
    | let_remove _ _ = raise Fail "Can't happen"
  val t1 = traverse (fn APP(APP(IDENT "let", _), _) => true
                      | otherwise => false) let_remove t0
  val _ =
    traverse (fn IDENT("and") => true | _ => false)
    (fn _ => raise ERROR "Term" "Invalid use of reserved word and") t1
in
  t1
end

fun Absyn q = let in
  update_term_fns();
  remove_lets (!the_absyn_parser q)
end

local open Parse_support Absyn
  fun binder(VIDENT s)      = make_binding_occ s
    | binder(VPAIR(v1,v2))  = make_vstruct [binder v1, binder v2] NONE
    | binder(VAQ x)         = make_aq_binding_occ x
    | binder(VTYPED(v,pty)) = make_vstruct [binder v] (SOME pty)
in
  fun absyn_to_preterm_in_env ginfo t = let
    open parse_term Absyn Parse_support
    val to_ptmInEnv = absyn_to_preterm_in_env ginfo
  in
    case t of
      APP(APP(IDENT "gspec special", t1), t2) =>
        make_set_abs (to_ptmInEnv t1, to_ptmInEnv t2)
    | APP(t1, t2)   => list_make_comb (map to_ptmInEnv [t1, t2])
    | IDENT s       => make_atom ginfo s
    | QIDENT p      => make_qconst ginfo p
    | LAM(vs, t)    => bind_term "\\" [binder vs] (to_ptmInEnv t)
    | TYPED(t, pty) => make_constrained (to_ptmInEnv t) pty
    | AQ t          => make_aq t
  end
end;

fun absyn_to_preterm absyn = let
  val _ = update_term_fns()
  val oinfo = term_grammar.overload_info (term_grammar())
in
  Parse_support.make_preterm (absyn_to_preterm_in_env oinfo absyn)
end;

fun Preterm q =
 let val absyn = Absyn q
     val oinfo = term_grammar.overload_info (term_grammar())
 in
    Parse_support.make_preterm (absyn_to_preterm_in_env oinfo absyn)
 end

fun absyn_to_term G =
 let val oinfo = term_grammar.overload_info G
 in
   fn absyn =>
     Preterm.typecheck (SOME(term_to_string, type_to_string))
        (Parse_support.make_preterm
             (absyn_to_preterm_in_env oinfo absyn))
 end;

(*---------------------------------------------------------------------------
    not good enough to have

            Term = absyn_to_term (term_grammar()) o Absyn

    as term_grammar may be updated as a result of evaluating
    parse_ptie.
 ---------------------------------------------------------------------------*)

fun Term q = absyn_to_term (term_grammar()) (Absyn q)

fun -- q x = Term q;

fun typedTerm qtm ty =
   let fun trail s = [QUOTE (s^"):"), ANTIQUOTE(ty_antiq ty), QUOTE""]
   in
   Term (case (Lib.front_last qtm)
        of ([],QUOTE s) => trail ("("^s)
         | (QUOTE s::rst, QUOTE s') => (QUOTE ("("^s)::rst) @ trail s'
         | _ => raise ERROR"typedTerm" "badly formed quotation")
   end;

fun parse_from_grammars (tyG, tmG) = let
  val ty_parser = parse_type.parse_type typ2_rec false tyG
  (* this next parser is used within the term parser *)
  val ty_parser' = parse_type.parse_type typ1_rec false tyG
  val tm_parser = absyn_to_term tmG o remove_lets o do_parse tmG ty_parser'
in
  (parse_Type ty_parser, tm_parser)
end

(*----------------------------------------------------------------------*
 * parse_in_context                                                     *
 *----------------------------------------------------------------------*)

local
  open Preterm Pretype
  fun name_eq s M = ((s = #Name(dest_var M)) handle HOL_ERR _ => false)
  fun has_any_uvars pty =
    case pty
     of UVar (ref NONE)        => true
      | UVar (ref (SOME pty')) => has_any_uvars pty'
      | Tyop(s, args)          => List.exists has_any_uvars args
      | Vartype _              => false
  fun give_types_to_fvs ctxt boundvars tm = let
    val gtf = give_types_to_fvs ctxt
  in
    case tm of
      Var{Name, Ty} => let
      in
        if has_any_uvars Ty andalso not(Lib.mem tm boundvars) then
          case List.find (fn ctxttm => name_eq Name ctxttm) ctxt of
            NONE => ()
          | SOME ctxt_tm =>
              unify Ty (Pretype.fromType (type_of ctxt_tm))
              handle HOL_ERR _ =>
                (Lib.say ("\nUnconstrained variable "^Name^" in quotation "^
                          "can't have type\n\n" ^
                          type_to_string (type_of ctxt_tm) ^
                          "\n\nas given by context.\n\n");
                 raise ERROR "parse_in_context" "unify failed")
        else
          ()
      end
    | Comb{Rator, Rand} => (gtf boundvars Rator; gtf boundvars Rand)
    | Abs{Bvar, Body} => gtf (Bvar::boundvars) Body
    | Constrained(ptm, _) => gtf boundvars ptm
    | _ => ()
  end
in
  fun parse_in_context0 FVs q = let
    val ptm = Preterm q
  in
    typecheck_phase1 (SOME(term_to_string, type_to_string)) ptm;
    give_types_to_fvs FVs [] ptm;
    to_term (overloading_resolution ptm)
  end

  fun parse_in_context FVs q =
    Lib.with_flag (Globals.notify_on_tyvar_guess,false)
                  (parse_in_context0 FVs) q
end

(*---------------------------------------------------------------------------
     Making temporary and persistent changes to the grammars.
 ---------------------------------------------------------------------------*)

val grm_updates = ref [] : (string * string) list ref;

fun update_grms p = grm_updates := (p :: !grm_updates);


fun temp_add_type s = let open parse_type in
   the_type_grammar := new_tyop (!the_type_grammar) s;
   type_grammar_changed := true;
   term_grammar_changed := true
 end;

fun add_type s = let in
   temp_add_type s;
   update_grms ("temp_add_type", Lib.quote s)
 end

fun temp_add_infix_type {Name, ParseName, Assoc, Prec} =
 let open parse_type
 in the_type_grammar
       := new_binary_tyop (!the_type_grammar)
              {precedence = Prec, infix_form = ParseName,
               opname = Name, associativity = Assoc};
    type_grammar_changed := true;
    term_grammar_changed := true
 end

fun add_infix_type (x as {Name, ParseName, Assoc, Prec}) = let in
  temp_add_infix_type x;
  update_grms ("temp_add_infix_type", String.concat
                  ["{Name = ", quote Name,
                   ", ParseName = ",
                   case ParseName of NONE => "NONE"
                                   | SOME s => "SOME "^quote s,
                   ", Assoc = ", assocToString Assoc,
                   ", Prec = ", Int.toString Prec, "}"])
 end

(* Not persistent? *)
fun temp_set_associativity (i,a) = let in
   the_term_grammar := set_associativity_at_level (term_grammar()) (i,a);
   term_grammar_changed := true
 end


fun temp_add_infix(s, prec, associativity) =
 let open term_grammar Portable
 in
   the_term_grammar :=
   add_rule (!the_term_grammar)
    {term_name = s, block_style = (AroundSamePrec, (INCONSISTENT, 0)),
     fixity = Infix(associativity, prec),
     pp_elements = [HardSpace 1, RE (TOK s), BreakSpace(1,0)],
     paren_style = OnlyIfNecessary};
   term_grammar_changed := true
  end handle GrammarError s => raise ERROR "add_infix" ("Grammar Error: "^s)

fun add_infix (s, prec, associativity) = let in
  temp_add_infix(s,prec,associativity);
  update_grms ("temp_add_infix", String.concat
                  ["(", quote s, ", ", Int.toString prec, ", ",
                        assocToString associativity,")"])
 end;


local open term_grammar
in
fun fixityToString Prefix  = "Prefix"
  | fixityToString Binder  = "Binder"
  | fixityToString (RF rf) = term_grammar.rule_fixityToString rf

fun relToString TM = "TM"
  | relToString (TOK s) = "TOK "^quote s
end

fun rellistToString [] = ""
  | rellistToString [x] = relToString x
  | rellistToString (x::xs) = relToString x ^ ", " ^ rellistToString xs

fun block_infoToString (Portable.CONSISTENT, n) =
        "(CONSISTENT, "^Int.toString n^")"
  | block_infoToString (Portable.INCONSISTENT, n) =
    "(INCONSISTENT, "^Int.toString n^")"

fun ParenStyleToString Always = "Always"
  | ParenStyleToString OnlyIfNecessary = "OnlyIfNecessary"
  | ParenStyleToString ParoundName = "ParoundName"
  | ParenStyleToString ParoundPrec = "ParoundPrec"

fun BlockStyleToString AroundSameName = "AroundSameName"
  | BlockStyleToString AroundSamePrec = "AroundSamePrec"
  | BlockStyleToString AroundEachPhrase = "AroundEachPhrase"


fun ppToString pp =
  case pp
   of PPBlock(ppels, bi) =>
      "PPBlock(["^pplistToString ppels^"], "^ block_infoToString bi^")"
    | EndInitialBlock bi => "EndInitialBlock "^block_infoToString bi
    | BeginFinalBlock bi => "BeginFinalBlock "^block_infoToString bi
    | HardSpace n => "HardSpace "^Int.toString n^""
    | BreakSpace(n,m) => "BreakSpace("^Int.toString n^", "^Int.toString m^")"
    | RE rel => relToString rel
    | _ => raise Fail "Don't want to print out First or Last TM values"
and
    pplistToString [] = ""
  | pplistToString [x] = ppToString x
  | pplistToString (x::xs) = ppToString x ^ ", " ^ pplistToString xs


fun standard_spacing name fixity =
 let open term_grammar  (* to get fixity constructors *)
     val bstyle = (AroundSamePrec, (Portable.INCONSISTENT, 0))
     val pstyle = OnlyIfNecessary
     val pels =  (* not sure if Closefix case will ever arise *)
       case fixity
        of RF (Infix _)      => [HardSpace 1, RE (TOK name), BreakSpace(1,0)]
         | RF (TruePrefix _) => [RE(TOK name), HardSpace 1]
         | RF (Suffix _)     => [HardSpace 1, RE(TOK name)]
         | RF Closefix       => [RE(TOK name)]
         | Prefix => []
         | Binder => []
in
  {term_name = name, fixity = fixity, pp_elements = pels,
   paren_style = pstyle, block_style = bstyle}
end

fun temp_set_grammars(tyG, tmG) = let
in
  the_term_grammar := tmG;
  the_type_grammar := tyG;
  term_grammar_changed := true;
  type_grammar_changed := true
end


fun temp_add_binder(name, prec) = let in
   the_term_grammar := add_binder (!the_term_grammar) (name, prec);
   term_grammar_changed := true
 end

val std_binder_precedence = 0;

fun add_binder (name, prec) = let in
    temp_add_binder(name, prec);
    update_grms ("temp_add_binder", String.concat
        ["(", quote name, ", std_binder_precedence)"])
  end

fun temp_add_rule {term_name,fixity,pp_elements,paren_style,block_style} =
 (case fixity
   of Prefix => Feedback.HOL_MESG"Fixities of Prefix do not affect the grammar"
    | Binder => let in
        temp_add_binder(term_name, std_binder_precedence);
        term_grammar_changed := true
      end
    | RF rf => let in
        the_term_grammar := term_grammar.add_rule (!the_term_grammar)
              {term_name=term_name, fixity=rf, pp_elements=pp_elements,
               paren_style=paren_style, block_style=block_style};
        term_grammar_changed := true
      end
 ) handle GrammarError s => raise ERROR "add_rule" ("Grammar error: "^s)

fun add_rule (r as {term_name, fixity, pp_elements,
                    paren_style, block_style = (bs,bi)}) = let in
  temp_add_rule r;
  update_grms ("temp_add_rule", String.concat
       ["{term_name = ", quote term_name,
        ", fixity = ", fixityToString fixity, ",\n",
        "pp_elements = [", pplistToString pp_elements, "],\n",
        "paren_style = ", ParenStyleToString paren_style,",\n",
        "block_style = (", BlockStyleToString bs, ", ",
                           block_infoToString bi,")}"])
 end

fun temp_add_listform x = let open term_grammar in
    the_term_grammar := add_listform (term_grammar()) x;
    term_grammar_changed := true
  end

fun add_listform (x as {separator,leftdelim,rightdelim,cons,nilstr}) = let in
    temp_add_listform x;
    update_grms ("temp_add_listform", String.concat
                    ["{separator = ",   quote separator,
                     ", leftdelim = ",  quote leftdelim,
                     ", rightdelim = ", quote rightdelim,
                     ", cons = ",       quote cons,
                     ", nilstr = ",     quote nilstr,
                     "}"])
 end

fun temp_add_bare_numeral_form x =
 let val _ = Lib.can Term.prim_mk_const{Name="NUMERAL", Thy="arithmetic"}
             orelse raise ERROR "add_numeral_form"
            ("Numeral support not present; try load \"arithmeticTheory\"")
 in
    the_term_grammar := term_grammar.add_numeral_form (term_grammar()) x;
    term_grammar_changed := true
 end

fun add_bare_numeral_form (c, stropt) = let in
  temp_add_bare_numeral_form (c, stropt);
  update_grms ("temp_add_bare_numeral_form", String.concat
     ["(#", quote(str c), ", ",
      case stropt of NONE => "NONE" | SOME s => "SOME "^quote s,")"])
 end

fun temp_give_num_priority c = let open term_grammar in
    the_term_grammar := give_num_priority (term_grammar()) c;
    term_grammar_changed := true
  end

fun give_num_priority c = let in
  temp_give_num_priority c;
  update_grms ("temp_give_num_priority",
                  String.concat ["#", Lib.quote(str c)])
 end

fun temp_remove_numeral_form c = let in
   the_term_grammar := term_grammar.remove_numeral_form (term_grammar()) c;
   term_grammar_changed := true
  end

fun remove_numeral_form c = let in
  temp_remove_numeral_form c;
  update_grms ("temp_remove_numeral_form",
                  String.concat ["#", Lib.quote(str c)])
  end

fun temp_associate_restriction (bs, s) =
 let val lambda = #lambda (specials (term_grammar()))
     val b = if lambda = bs then LAMBDA else BinderString bs
 in
    the_term_grammar :=
    term_grammar.associate_restriction (term_grammar()) (b, s);
    term_grammar_changed := true
 end

fun associate_restriction (bs, s) = let in
   temp_associate_restriction (bs, s);
   update_grms ("temp_associate_restriction",
       String.concat["(", quote bs, ", ", quote s, ")"])
 end

fun temp_remove_rules_for_term s = let open term_grammar in
    the_term_grammar := remove_standard_form (term_grammar()) s;
    term_grammar_changed := true
  end

fun remove_rules_for_term s = let in
   temp_remove_rules_for_term s;
   update_grms ("temp_remove_rules_for_term", quote s)
 end

fun temp_remove_termtok r = let open term_grammar in
  the_term_grammar := remove_form_with_tok (term_grammar()) r;
  term_grammar_changed := true
 end

fun remove_termtok (r as {term_name, tok}) = let in
   temp_remove_termtok r;
   update_grms ("temp_remove_termtok", String.concat
        ["{term_name = ", quote term_name, ", tok = ", quote tok, "}"])
 end

fun temp_set_fixity (s,f) = let in
  remove_termtok {term_name=s, tok=s};
  case f of Prefix => () | _ => temp_add_rule (standard_spacing s f)
 end

fun set_fixity (s,f) = let in
    temp_set_fixity (s,f);
    update_grms ("temp_set_fixity",
         String.concat ["(", quote s, ", ", fixityToString f, ")"])
 end

fun temp_prefer_form_with_tok r = let open term_grammar in
    the_term_grammar := prefer_form_with_tok (term_grammar()) r;
    term_grammar_changed := true
 end

fun prefer_form_with_tok (r as {term_name,tok}) = let in
    temp_prefer_form_with_tok r;
    update_grms ("temp_prefer_form_with_tok", String.concat
       ["{term_name = ", quote term_name, ", tok = ", quote tok, "}"])
 end

fun temp_clear_prefs_for_term s = let open term_grammar in
    the_term_grammar := clear_prefs_for s (term_grammar());
    term_grammar_changed := true
  end

fun clear_prefs_for_term s = let in
    temp_clear_prefs_for_term s;
    update_grms ("temp_clear_prefs_for_term", quote s)
 end

(*-------------------------------------------------------------------------
        Overloading
 -------------------------------------------------------------------------*)

fun temp_overload_on_by_nametype s {Name, Thy, Ty} =
 let open term_grammar
 in the_term_grammar
       := fupdate_overload_info
          (Overload.add_actual_overloading
              {opname=s, realname=Name, realthy=Thy, realtype=Ty})
             (term_grammar());
    term_grammar_changed := true
 end

fun overload_on_by_nametype s (r as {Name, Thy, Ty}) = let in
   temp_overload_on_by_nametype s r;
   update_grms ("temp_overload_on_by_nametype", String.concat
     [quote s, " {Name = ", quote Name, ", ", "Thy = ", quote Thy, ", ",
      "Ty = ", Portable.pp_to_string 75 (TheoryPP.pp_type "U" "T") Ty, "}"])
 end

fun temp_overload_on (s, t) =
  temp_overload_on_by_nametype s (dest_thy_const t)
  handle HOL_ERR _ => raise ERROR "overload_on"
    "Can't have non-constants as targets of overloading"
       | Overload.OVERLOAD_ERR s => raise ERROR "temp_overload_on" s

fun overload_on (s, t) =
  overload_on_by_nametype s (dest_thy_const t)
  handle HOL_ERR _ => raise ERROR "overload_on"
    "Can't have non-constants as targets of overloading"
       | Overload.OVERLOAD_ERR s => raise ERROR "overload_on" s

fun temp_clear_overloads_on s = let open term_grammar in
  the_term_grammar :=
    fupdate_overload_info
    (Overload.remove_overloaded_form s) (term_grammar());
  case Term.decls s of
    [] => ()
  | (c::_) => temp_overload_on(s,c);
  term_grammar_changed := true
end

fun clear_overloads_on s = let in
  temp_clear_overloads_on s;
  update_grms ("temp_clear_overloads_on", quote s)
end

fun temp_add_record_field (fldname, term) = let
  val recfldname = recsel_special^fldname
in
  temp_overload_on(recfldname, term)
end

fun add_record_field (fldname, term) = let
  val recfldname = recsel_special^fldname
in
  overload_on(recfldname, term)
end

fun temp_add_record_update (fldname, term) = let
  val recfldname = recupd_special ^ fldname
in
  temp_overload_on(recfldname, term)
end

fun add_record_update (fldname, term) = let
  val recfldname = recupd_special ^ fldname
in
  overload_on(recfldname, term)
end

fun temp_add_record_fupdate (fldname, term) = let
  val recfldname = recfupd_special ^ fldname
in
  temp_overload_on(recfldname, term)
end

fun add_record_fupdate (fldname, term) = let
  val recfldname = recfupd_special ^ fldname
in
  overload_on(recfldname, term)
end

fun temp_add_numeral_form (c, stropt) = let
  val _ =
    Lib.can Term.prim_mk_const{Name="NUMERAL", Thy="arithmetic"}
    orelse
      raise ERROR "add_numeral_form"
      ("Numeral support not present; try load \"arithmeticTheory\"")
  val num = Type.mk_type {Tyop="num", Args = []}
  val fromNum_type = num --> alpha
  val const_record =
    case stropt of
      NONE => {Name = nat_elim_term, Thy = "arithmetic", Ty = num --> num}
    | SOME s =>
        case Term.decls s of
          [] => raise ERROR "add_numeral_form" ("No constant with name "^s)
        | h::_ => dest_thy_const h
in
  temp_add_bare_numeral_form (c, stropt);
  temp_overload_on_by_nametype (fromNum_str) const_record
end

fun add_numeral_form (c, stropt) = let in
  temp_add_numeral_form (c, stropt);
  update_grms ("temp_add_numeral_form",
               String.concat
               ["(#", quote (str c), ", ",
                case stropt of NONE => "NONE" | SOME s => "SOME "^quote s, ")"
               ])
end


(*---------------------------------------------------------------------------
     Visibility of identifiers
 ---------------------------------------------------------------------------*)

fun hide s =
  the_term_grammar := term_grammar.hide_constant s (!the_term_grammar)
fun reveal s =
  case Term.decls s of
    [] => WARN "reveal" (s^" not a constant; reveal ignored")
  | cs => let
    in
      app (fn c => temp_overload_on (s, c)) cs
    end

fun known_constants() = term_grammar.known_constants (term_grammar())

fun hidden s =
  let val declared = Term.all_consts()
      val names = map (#Name o Term.dest_const) declared
  in
    Lib.mem s (Lib.subtract names (known_constants()))
  end

fun set_known_constants sl = let
  val (ok_names, bad_names) = partition (not o null o Term.decls) sl
  val _ =
    case bad_names of
      [] => ()
    | _ =>
        List.app (fn s => WARN"set_known_constants"
                  (s^" not a constant; ignored"))
        bad_names
in
  app reveal ok_names
end

(* Call this function to get a call to reveal to happen in the
   theory file generated by export_theory(); if this isn't called,
   things will fail to parse as constants in later theories.

   This function is called by new_definition and friends, so it shouldn't
   be necessary for users to call it in most circumstances. *)
fun remember_const s = update_grms ("reveal", mlquote s);
fun add_const s      = (reveal s; remember_const s);

(*---------------------------------------------------------------------------
     Updating the global and local grammars when a theory file is
     loaded.

     The function "update_grms" updates both the local and global
     grammars by pointer swapping. Ugh! Relies on fact that no
     other state than that of the current global grammars changes
     in a call to f.

     TODO: handle exceptions coming from application of "f" to "x"
           and print out informative messages.
 ---------------------------------------------------------------------------*)

fun update_grms f x = let
  val _ = f x                          (* update global grammars *)
    handle HOL_ERR {origin_structure, origin_function, message} =>
      (WARN "update_grms"
       ("Update to global grammar failed in "^origin_function^
        " with message: "^message^"\nproceeding anyway."))

  val (tyG, tmG) = current_grammars()  (* save global grm. values *)
  val (tyL0,tmL0) = current_lgrms()    (* read local grm. values *)
  val _ = the_type_grammar := tyL0     (* mv locals into globals *)
  val _ = the_term_grammar := tmL0
  val _ = f x                          (* update global (really local) grms *)
    handle HOL_ERR {origin_structure, origin_function, message} =>
      (WARN "update_grms"
       ("Update to local grammar failed in "^origin_function^
        " with message: "^message^"\nproceeding anyway."))
  val (tyL1, tmL1) = current_grammars()
  val _ = the_lty_grm := tyL1          (* mv updates into locals *)
  val _ = the_ltm_grm := tmL1
in
  the_type_grammar := tyG;             (* restore global grm. values *)
  the_term_grammar := tmG
end



fun merge_grm (gname, (tyG0, tmG0)) (tyG1, tmG1) =
  (parse_type.merge_grammars (tyG0, tyG1),
   term_grammar.merge_grammars (tmG0, tmG1)
  )
  handle HOLgrammars.GrammarError s
   => (Feedback.HOL_WARNING "Parse" "mk_local_grms"
       (String.concat["Error ", s, " while merging grammar ",
                      gname, "; ignoring it.\n"])
      ; (tyG1, tmG1));

fun mk_local_grms [] = raise ERROR "mk_local_grms" "no grammars"
  | mk_local_grms ((n,gg)::t) =
      let val (ty_grm0,tm_grm0) = itlist merge_grm t gg
      in the_lty_grm := ty_grm0;
         the_ltm_grm := tm_grm0
      end;

fun parent_grammars () = let
  open Theory
  fun echo s = (quote s, s)
  fun grm_string "min" = echo "min_grammars"
    | grm_string s     = echo (s^"Theory."^s^"_grammars")
  val ct = current_theory()
in
  case parents ct of
    [] => raise ERROR "parent_grammars"
                        ("no parents found for theory "^quote ct)
  | plist => map grm_string plist
 end;


local fun sig_addn s = String.concat
       ["val ", s, "_grammars : parse_type.grammar * term_grammar.grammar"]
      open Portable
in
fun setup_grammars thyname =
 let val _ = grm_updates := []
 in
  adjoin_to_theory
  {sig_ps = SOME (fn pps => Portable.add_string pps (sig_addn thyname)),
   struct_ps = SOME (fn ppstrm =>
     let val {add_string,add_break,begin_block,end_block,add_newline,...}
              = with_ppstream ppstrm
         val B  = begin_block CONSISTENT
         val IB = begin_block INCONSISTENT
         val EB = end_block
         fun pr_sml_list pfun L =
           (begin_block CONSISTENT 0; add_string "[";
            begin_block INCONSISTENT 0;
               pr_list pfun (fn () => add_string ",")
                            (fn () => add_break(0,0))  L;
            end_block(); add_string "]"; end_block())
         fun pp_update(f,x) =
            (B 5;
               add_string "val _ = update_grms"; add_break(1,0);
               add_string f; add_break(1,0);
               B 0; add_string x;  (* can be more fancy *)
               EB(); EB())
         fun pp_pair f1 f2 (x,y) =
              (B 0; add_string"(";
                    B 0; f1 x;
                         add_string",";add_break(0,0);
                         f2 y;
                    EB(); add_string")"; EB())
         val (names,rules) = partition (equal"reveal" o fst)
                                (List.rev(!grm_updates))
         val reveals = map snd names
     in
       B 0;
         add_string "local open Portable GrammarSpecials Parse";
         add_newline();
         add_string "in"; add_newline();
         add_string "val _ = mk_local_grms [";
             IB 0; pr_list (pp_pair add_string add_string)
                          (fn () => add_string ",")
                          (fn () => add_break(1,0)) (parent_grammars());
             EB();
         add_string "]"; add_newline();
         B 10; add_string "val _ = List.app (update_grms reveal)";
              add_break(1,0);
              pr_sml_list add_string reveals;
         EB(); add_newline();
         pr_list pp_update (fn () => ()) add_newline rules;
         add_newline();
         add_string (String.concat
             ["val ", thyname, "_grammars = Parse.current_lgrms()"]);
         add_newline();
         add_string "end"; add_newline();
       EB()
     end)}
 end
end

val _ = Theory.pp_thm := pp_thm;
val _ = Theory.after_new_theory setup_grammars;


fun export_theorems_as_docfiles dirname thms = let
  val {arcs,...} = Path.fromString dirname
  fun check_arcs checked arcs =
    case arcs of
      [] => checked
    | x::xs => let
        val nextlevel = Path.concat (checked, x)
      in
        if FileSys.access(nextlevel, []) then
          if FileSys.isDir nextlevel then check_arcs nextlevel xs
          else raise Fail (nextlevel ^ " exists but is not a directory")
        else let
        in
          FileSys.mkDir nextlevel
          handle (OS.SysErr(s, erropt)) => let
            val part2 = case erropt of SOME err => OS.errorMsg err | NONE => ""
          in
            raise Fail ("Couldn't create directory "^nextlevel^": "^s^" - "^
                        part2)
          end;
          check_arcs nextlevel xs
        end
      end
  val dirname = check_arcs "" arcs
  fun write_thm (thname, thm) = let
    open Theory TextIO
    val outstream = openOut (Path.concat (dirname, thname^".doc"))
  in
    output(outstream, "\\THEOREM "^thname^" "^current_theory()^"\n");
    output(outstream, thm_to_string thm);
    output(outstream, "\n\\ENDTHEOREM\n");
    closeOut outstream
  end
in
  app write_thm thms
end

fun export_theory_as_docfiles dirname = let
  val thms = axioms() @ definitions() @ theorems()
in
  export_theorems_as_docfiles dirname thms
end

(*---------------------------------------------------------------------------
     pp_element values that are brought across from term_grammar.
     Tremendous potential for confusion: TM and TOK are constructed
     values, but not constructors, here. Other things of this ilk
     are the constructors for the datatypes pp_element,
     PhraseBlockStyle, and ParenStyle.
 ---------------------------------------------------------------------------*)

fun TM x = x; fun TOK x = x;   (* remove constructor status *)

val TM = term_grammar.RE term_grammar.TM
val TOK = term_grammar.RE o term_grammar.TOK

(*---------------------------------------------------------------------------
     Install grammar rules for the theory "min".
 ---------------------------------------------------------------------------*)

val _ = List.app temp_add_type ["bool", "ind"];
val _ = temp_add_infix_type
            {Name="fun", ParseName=SOME"->", Prec=50, Assoc=RIGHT};

val _ = List.app reveal ["=", "==>", "@"];
val _ = temp_add_binder ("@", std_binder_precedence);

(*---------------------------------------------------------------------------
   Using the standard rules for infixes for ==> and = seems to result in bad
   pretty-printing of goals.  I think the following customised printing
   spec works better.  The crucial difference is that the blocking style
   is CONSISTENT rather than INCONSISTENT.
 ---------------------------------------------------------------------------*)

val _ = temp_add_rule
         {term_name   = "==>",
          block_style = (AroundSamePrec, (Portable.CONSISTENT, 0)),
          fixity      = Infix(RIGHT, 200),
          pp_elements = [HardSpace 1, TOK "==>", BreakSpace(1,0)],
          paren_style = OnlyIfNecessary};

val _ = temp_add_rule
         {term_name   = "=",
          block_style = (AroundSamePrec, (Portable.CONSISTENT, 0)),
          fixity      = Infix(NONASSOC, 100),
          pp_elements = [HardSpace 1, TOK "=", BreakSpace(1,0)],
          paren_style = OnlyIfNecessary};

val min_grammars = current_grammars();

end