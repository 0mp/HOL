structure type_grammar :> type_grammar =
struct

datatype grammar_rule =
  SUFFIX of string list
| INFIX of {opname : string, parse_string : string} list *
           HOLgrammars.associativity

datatype type_structure =
         TYOP of {Thy : string, Tyop : string, Args : type_structure list}
       | PARAM of int

datatype grammar = TYG of (int * grammar_rule) list *
                          (string, type_structure) Binarymap.dict;

open HOLgrammars

fun default_typrinter G pps ty = PP.add_string pps "<a type>"

val type_printer = ref default_typrinter
val initialised_printer = ref false

fun initialise_typrinter f =
    if not (!initialised_printer) then
      (type_printer := f; initialised_printer := true)
    else
      raise Feedback.HOL_ERR {origin_structure = "type_grammar",
                              origin_function = "initialised_printer",
                              message = "Printer function already initialised"}

fun pp_type g pps ty = (!type_printer) g pps ty

fun structure_to_type st =
    case st of
      TYOP {Thy,Tyop,Args} =>
      Type.mk_thy_type {Thy = Thy, Tyop = Tyop,
                        Args = map structure_to_type Args}
    | PARAM n => Type.mk_vartype ("'"^str (chr (n + ord #"a")))

fun params0 acc (PARAM i) = Binaryset.add(acc, i)
  | params0 acc (TYOP{Args,...}) = foldl (fn (t,set) => params0 set t) acc Args
val params = params0 (Binaryset.empty Int.compare)

val num_params = Binaryset.numItems o params

val std_suffix_precedence = 100



fun merge r1 r2 =
  case (r1, r2) of
    (SUFFIX slist1, SUFFIX slist2) => SUFFIX(Lib.union slist1 slist2)
  | (INFIX(rlist1, a1), INFIX(rlist2, a2)) => let
    in
      if a1 = a2 then INFIX(Lib.union rlist1 rlist2, a1)
      else
        raise GrammarError
          "Attempt to merge two infix types with different associativities"
    end
  | _ => raise GrammarError "Attempt to merge suffix and infix type"

fun insert_sorted0 (k, v) [] = [(k, v)]
  | insert_sorted0 kv1 (wholething as (kv2::rest)) = let
      val (k1, v1) = kv1
      val (k2, v2) = kv2
    in
      if (k1 < k2) then kv1::wholething
      else
        if k1 = k2 then  (k1, merge v1 v2) :: rest
        else
          kv2 :: insert_sorted0 kv1 rest
    end

fun insert_sorted (k, v) (G0 : (int * grammar_rule) list) = let
  val G1 = insert_sorted0 (k,v) G0
  fun merge_adj_suffixes [] = []
    | merge_adj_suffixes [x] = [x]
    | merge_adj_suffixes (x1::x2::xs) = let
      in
        case (x1, x2) of
          ((p1, SUFFIX slist1), (p2, SUFFIX slist2)) =>
            merge_adj_suffixes ((p1, SUFFIX (Lib.union slist1 slist2))::xs)
        | _ => x1 :: merge_adj_suffixes (x2 :: xs)
      end
in
  merge_adj_suffixes G1
end



fun new_binary_tyop (TYG(G,abbrevs)) {precedence, infix_form, opname,
                                      associativity} =
    let
      val rule1 =
          if isSome infix_form then
            (precedence, INFIX([{parse_string = valOf infix_form,
                                 opname = opname}],
                               associativity))
          else (precedence, INFIX([{parse_string = opname, opname = opname}],
                                  associativity))
      val rule2 = (std_suffix_precedence, SUFFIX[opname])
    in
      TYG (insert_sorted rule1 (insert_sorted rule2 G), abbrevs)
    end

fun new_tyop (TYG(G,abbrevs)) name =
  TYG (insert_sorted (std_suffix_precedence, SUFFIX[name]) G, abbrevs)

val empty_grammar = TYG ([], Binarymap.mkDict String.compare)

fun rules (TYG (G, dict)) = G
fun abbreviations (TYG (G, dict)) = dict

fun check_structure st = let
  fun param_numbers (PARAM i, pset) = Binaryset.add(pset, i)
    | param_numbers (TYOP{Args,...}, pset) = foldl param_numbers pset Args
  val pset = param_numbers (st, Binaryset.empty Int.compare)
  val plist = Binaryset.listItems pset
  fun check_for_gaps expecting [] = ()
    | check_for_gaps expecting (h::t) =
      if h <> expecting then
        raise GrammarError
                ("Expecting to find parameter #"^Int.toString expecting)
      else
        check_for_gaps (expecting + 1) t
in
  check_for_gaps 0 plist
end

fun new_abbreviation (TYG(G, dict0)) (s, st) = let
  val _ = check_structure st
  val G0 = TYG(G, Binarymap.insert(dict0,s,st))
in
  new_tyop G0 s
end

fun remove_abbreviation(TYG(G, dict0)) s =
    TYG(G, #1 (Binarymap.remove(dict0, s)) handle Binarymap.NotFound => dict0)

fun rev_append [] acc = acc
  | rev_append (x::xs) acc = rev_append xs (x::acc)

fun merge_abbrevs G (d1, d2) = let
  fun merge_dictinsert (k,v,newdict) =
      case Binarymap.peek(newdict,k) of
        NONE => Binarymap.insert(newdict,k,v)
      | SOME v0 =>
        if v0 <> v then
          (Feedback.HOL_WARNING "parse_type" "merge_grammars"
                                ("Conflicting entries for abbreviation "^k^
                                 "; arbitrarily keeping map to "^
                                 PP.pp_to_string (!Globals.linewidth)
                                                 (pp_type G)
                                                 (structure_to_type v0));
           newdict)
        else
          newdict
in
    Binarymap.foldr merge_dictinsert d1 d2
end

fun merge_grammars (G1, G2) = let
  (* both grammars are sorted, with no adjacent suffixes *)
  val TYG (grules1, abbrevs1) = G1
  val TYG (grules2, abbrevs2) = G2
  fun merge_acc acc (gs as (g1, g2)) =
    case gs of
      ([], _) => rev_append acc g2
    | (_, []) => rev_append acc g1
    | ((g1rule as (g1k, g1v))::g1rest, (g2rule as (g2k, g2v))::g2rest) => let
      in
        case Int.compare (g1k, g2k) of
          LESS => merge_acc (g1rule::acc) (g1rest, g2)
        | GREATER => merge_acc (g2rule::acc) (g1, g2rest)
        | EQUAL => merge_acc ((g1k, merge g1v g2v)::acc) (g1rest, g2rest)
      end
in
  TYG (merge_acc [] (grules1, grules2), merge_abbrevs G2 (abbrevs1, abbrevs2))
end

fun prettyprint_grammar pps (G as TYG (g,abbrevs)) = let
  open Portable Lib
  val {add_break,add_newline,add_string,begin_block,end_block,...} =
      with_ppstream pps
  fun print_suffix s = let
    val oarity =
        case Binarymap.peek(abbrevs, s) of
          NONE => valOf (Type.op_arity (hd (Type.decls s)))
        | SOME st => num_params st
    fun print_ty_n_tuple n =
        case n of
          0 => ()
        | 1 => add_string "TY "
        | n => (add_string "(";
                pr_list (fn () => add_string "TY") (fn () => add_string ", ")
                        (fn () => ()) (List.tabulate(n,K ()));
                add_string ")")
  in
    print_ty_n_tuple oarity;
    add_string s
  end

  fun print_abbrev (s, st) = let
    fun print_lhs () =
      case num_params st of
        0 => add_string s
      | 1 => (add_string "'a "; add_string s)
      | n => (begin_block INCONSISTENT 0;
              add_string "(";
              pr_list (pp_type G pps o structure_to_type o PARAM)
                      (fn () => add_string ",")
                      (fn () => add_break(1,0))
                      (List.tabulate(n, I));
             add_string ") ";
             add_string s)
  in
    begin_block CONSISTENT 0;
    print_lhs ();
    add_string " =";
    add_break(1,2);
    pp_type G pps (structure_to_type st);
    end_block()
  end

  fun print_abbrevs () =
      if Binarymap.numItems abbrevs > 0 then let
        in
          add_newline();
          add_string "Type abbreviations:";
          add_break(2,0);
          begin_block CONSISTENT 0;
          pr_list print_abbrev (fn () => add_newline()) (fn () => ())
                  (Binarymap.listItems abbrevs);
          end_block()
        end
      else ()

  fun print_infix {opname,parse_string} = let
  in
    add_string "TY ";
    add_string parse_string;
    add_string " TY";
    if opname <> parse_string then
      add_string (" ["^opname^"]")
    else
      ()
  end

  fun print_rule0 r =
    case r of
      SUFFIX sl => let
      in
        add_string "TY  ::=  ";
        begin_block INCONSISTENT 0;
        pr_list print_suffix (fn () => add_string " |")
                (fn () => add_break(1,0)) sl;
        end_block ()
      end
    | INFIX(oplist, assoc) => let
        val assocstring =
            case assoc of
              LEFT => "L-"
            | RIGHT => "R-"
            | NONASSOC => "non-"
      in
        add_string "TY  ::=  ";
        begin_block INCONSISTENT 0;
        pr_list print_infix (fn () => add_string " |")
                (fn () => add_break(1,0)) oplist;
        add_string (" ("^assocstring^"associative)");
        end_block()
      end;
  fun print_rule (n, r) = let
    val precstr = StringCvt.padRight #" " 7 ("("^Int.toString n^")")
  in
    add_string precstr;
    print_rule0 r;
    add_newline()
  end
in
  begin_block CONSISTENT 0;
  add_string "Rules:";
  add_newline();
  app print_rule g;
  print_abbrevs();
  end_block()
end;

end
