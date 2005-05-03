structure term_pp :> term_pp =
struct

open Portable HolKernel term_grammar
     HOLtokens HOLgrammars GrammarSpecials;

val PP_ERR = mk_HOL_ERR "term_pp";

(*---------------------------------------------------------------------------
   Miscellaneous syntax stuff.
 ---------------------------------------------------------------------------*)

val dest_pair = sdest_binop (",", "pair") (PP_ERR "dest_pair" "");
val is_pair = Lib.can dest_pair;

fun mk_pair (fst,snd) = let
  val fsty = type_of fst
  val sndty = type_of snd
  val commaty = fsty --> sndty -->
                mk_thy_type{Tyop="prod",Thy="pair",Args=[fsty,sndty]}
  val c = mk_thy_const{Name=",", Thy="pair", Ty = commaty}
in
  list_mk_comb(c,[fst,snd])
end;

fun isSuffix s1 s2 = (* s1 is a suffix of s2 *) let
  val ss = Substring.all s2
  val (pref, suff) = Substring.position s1 ss
in
  Substring.size suff = String.size s1
end

fun acc_strip_comb M rands =
 let val (Rator,Rand) = dest_comb M
 in acc_strip_comb Rator (Rand::rands)
 end
 handle HOL_ERR _ => (M,rands);

fun strip_comb tm = acc_strip_comb tm [];

fun string_of_nspaces n = String.concat (List.tabulate(n, (fn _ => " ")))
val isPrefix = String.isPrefix

fun lose_constrec_ty {Name,Ty,Thy} = {Name = Name, Thy = Thy}

fun mk_casearrow(t1, t2) = let
  val t1_ty = type_of t1
  val t2_ty = type_of t2
  val arrow_t = mk_thy_const{Name = case_arrow_special, Thy = "bool",
                             Ty = t1_ty --> t2_ty --> t1_ty --> t2_ty}
in
  list_mk_comb(arrow_t, [t1, t2])
end

fun mk_casesplit(t1, t2) = let
  val t1_ty = type_of t1
  val split_t = mk_thy_const{Name = case_split_special, Thy = "bool",
                             Ty = t1_ty --> t1_ty --> t1_ty}
in
  list_mk_comb(split_t, [t1, t2])
end

fun list_mk_split [] = raise PP_ERR "list_mk_split" "Empty list"
  | list_mk_split [t] = t
  | list_mk_split (h::t) = mk_casesplit(h, list_mk_split t)

fun mk_case(split_on, cases) = let
  val (cty as (ty1,ty2)) = dom_rng (type_of cases)
  val case_t = mk_thy_const{Name = case_special, Thy = "bool",
                            Ty = ty1 --> (ty1 --> ty2) --> ty2}
in
  list_mk_comb(case_t, [split_on, cases])
end;

(* while f is still of functional type, dest_abs the abs term and apply the
   f to the variable just stripped from the abs *)
fun apply_absargs f abs =
    if can dom_rng (type_of f) then let
        val (v, body) = dest_abs abs
      in
        apply_absargs (mk_comb(f, v)) body
      end
    else
      (f, abs)

(*---------------------------------------------------------------------------
       Type antiquotations (required in term parser)
 ---------------------------------------------------------------------------*)

fun ty_antiq ty = mk_var("ty_antiq",ty)

fun dest_ty_antiq tm =
  case with_exn dest_var tm (ERR "dest_ty_antiq" "not a type antiquotation")
   of ("ty_antiq",Ty) => Ty
    |  _ => raise ERR "dest_ty_antiq" "not a type antiquotation";

val is_ty_antiq = Lib.can dest_ty_antiq


exception CaseConversionFailed
fun convert_case tm = let
  val (casef, args) = strip_comb tm
  val {Name = casefname, Thy = casefthy, ...} = dest_thy_const casef
  val prim_case_t = prim_mk_const {Name = casefname, Thy = casefthy}
  val (prim_fargs, _) = strip_fun (type_of prim_case_t)
  val _ = length prim_fargs = length args orelse raise CaseConversionFailed
  val (cases, split_on) = front_last args
  val split_on_ty = type_of split_on
  val (tyopname, _) = dest_type split_on_ty
  val cs0 = type_constructors tyopname
  val _ = length cs0 <> 0 orelse raise CaseConversionFailed
  val _ = length cases = length cs0 orelse
          raise CaseConversionFailed
  (* life is complicated at this point by the fact that the constructors *)
  (* may be polymorphic, and the actual split_on term may be an instance *)
  (* of that polymorphic type *)
  val (_, basety) = strip_fun (type_of (hd cs0))
  (* We rely on the fact that types stored in the TypeBase will *)
  (* never be functions, so we can just strip arrows to get at the *)
  (* possibly polymorphic base type *)
  val substitution = Type.match_type basety split_on_ty
  val cs = map (inst substitution) cs0

  fun mk_arrow (constructor, case_t) =
    mk_casearrow(apply_absargs constructor case_t)
  val arrows = ListPair.map mk_arrow (cs, cases)
               handle HOL_ERR _ => raise CaseConversionFailed
  (* this previous might fail if someone has a case term that has a split *)
  (* term which isn't actually an abstraction of the right number of *)
  (* variables. *)
  (* For example, the defining theorem for list_case: *)
  (* |- (list_case x f [] = x) /\ (list_case x f (h::t) = f h t) *)
  (* In neither conjunct is the f an abstraction over two variables *)
  val split = list_mk_split arrows
in
  mk_case(split_on, split)
end

(* ----------------------------------------------------------------------
    A flag controlling whether to print escaped syntax with a dollar
    or enclosing parentheses.  Thus whether the term mk_comb(+, 3) comes
    out as
      $+ 3
    or
      (+) 3
    The parser accepts either form.
   ---------------------------------------------------------------------- *)

val dollar_escape = ref true

fun dollarise s = if !dollar_escape then "$" ^ s
                  else "(" ^ s ^ ")"

val _ = Feedback.register_btrace ("pp_dollar_escapes", dollar_escape);

open term_pp_types
fun grav_name (Prec(n, s)) = s | grav_name _ = ""
fun grav_prec (Prec(n,s)) = n | grav_prec _ = ~1


fun dest_atom tm = dest_var tm handle HOL_ERR _ => dest_const tm

fun pneeded_by_style (rr: term_grammar.rule_record, pgrav, fname, fprec) =
  case #paren_style rr of
    Always => true
  | OnlyIfNecessary => false
  | ParoundName => grav_name pgrav <> fname
  | ParoundPrec => grav_prec pgrav <> fprec

fun countP P [] = 0
  | countP P (x::xs) = if P x then 1 + countP P xs else countP P xs
val numTMs = countP (fn TM => true | _ => false)

fun find_partial f  =
 let fun find [] = NONE
       | find (x::xs) =
           case f x
            of NONE => find xs
             | result => result
 in find end;


fun splitP P thelist = let
  fun with_acc acc [] = acc
    | with_acc (inlist, outlist) (x::xs) = let
      in
        if P x then with_acc (x::inlist, outlist) xs
        else with_acc (inlist, x::outlist) xs
      end
in
  with_acc ([], []) (List.rev thelist)
end

fun grule_term_names G grule = let
  fun suffix rr = (#term_name rr, SUFFIX (STD_suffix [rr]))
  fun prefix rr = (#term_name rr, PREFIX (STD_prefix [rr]))
  fun mkifix a rr = (#term_name rr, INFIX (STD_infix ([rr], a)))
  fun closefix rr = (#term_name rr, CLOSEFIX [rr])
in
  case grule of
    PREFIX (STD_prefix list) => map prefix list
  | PREFIX (BINDER list) =>
      map (fn b => (binder_to_string G b, PREFIX (BINDER [b]))) list
  | SUFFIX (STD_suffix list) => map suffix list
  | SUFFIX TYPE_annotation => []
  | INFIX (STD_infix(list, a)) => map (mkifix a) list
  | INFIX RESQUAN_OP => [(resquan_special, grule)]
  | INFIX (FNAPP lst) =>
      (fnapp_special, INFIX (FNAPP [])) :: map (mkifix LEFT) lst
  | INFIX VSCONS => [(vs_cons_special, INFIX VSCONS)]
  | CLOSEFIX lst => map closefix lst
  | LISTRULE lspeclist => let
      fun process lspec = [(#cons lspec, LISTRULE [lspec]),
                           (#nilstr lspec, LISTRULE [lspec])]
    in
      List.concat (map process lspeclist)
    end
end

exception SimpleExit
exception DoneExit

(* fun symbolic s = List.all HOLsym (String.explode s) *)

fun symbolic s = HOLsym (String.sub(s,String.size(s)-1));

(* term tm can be seen to have name s according to grammar G *)
fun has_name G s tm = let
  val oinfo = term_grammar.overload_info G
in
  if is_const tm then
    case Overload.overloading_of_term oinfo tm of
      SOME s' => s' = s
    | NONE => false
  else if is_var tm then fst (dest_var tm) = s
  else false
end

datatype bvar
    = Simple of term
    | Restricted of {Bvar : term, Restrictor : term}

fun bv2term (Simple t) = t
  | bv2term (Restricted {Bvar,...}) = Bvar



fun rule_to_rr rule =
  case rule of
    INFIX (STD_infix (slist, _)) => slist
  | PREFIX (STD_prefix slist) => slist
  | SUFFIX (STD_suffix slist) => slist
  | CLOSEFIX slist => slist
  | _ => []

(* gives the "wrong" lexicographic order, but is more likely to
   resolve differences with one comparison because types/terms with
   the same name are rare, but it's quite reasonable for many
   types/terms to share the same theory *)
fun nthy_compare ({Name = n1, Thy = thy1}, {Name = n2, Thy = thy2}) =
  case String.compare(n1, n2) of
    EQUAL => String.compare(thy1, thy2)
  | x => x

val prettyprint_bigrecs = ref true;

val _ = register_btrace ("pp_bigrecs", prettyprint_bigrecs)

fun first_tok [] = raise Fail "Shouldn't happen term_pp 133"
  | first_tok (RE (TOK s)::_) = s
  | first_tok (_ :: t) = first_tok t

fun decdepth n = if n < 0 then n else n - 1

fun pp_term (G : grammar) TyG = let
  val {restr_binders,lambda,endbinding,type_intro,res_quanop} = specials G
  val overload_info = overload_info G
  val spec_table =
       let val toks = grammar_tokens G
           val table = Polyhash.mkPolyTable(50, Fail "")
       in app (fn s => Polyhash.insert table (s, ())) toks;
          table
       end
  val num_info = numeral_info G
  val rule_table = Polyhash.mkPolyTable(50, Fail "")
  fun insert (grule, n) = let
    val keys_n_rules = grule_term_names G grule
    fun myinsert t (k, v) = let
      val existing = Polyhash.peek t k
      val newvalue =
        case existing of
          NONE => [v]
        | SOME vs => v::vs
    in
      Polyhash.insert t (k, newvalue)
    end
  in
    app (fn (s,rule) => myinsert rule_table (s, (n, rule))) keys_n_rules;
    n + 1
  end
  val _ = foldl insert 0 (grammar_rules G)
  fun lookup_term s = Polyhash.peek rule_table s
  val comb_prec = #1 (hd (valOf (lookup_term fnapp_special)))
    handle Option =>
      raise PP_ERR "pp_term" "Grammar has no function application"
  val recsel_info = (* (precedence, upd_tok) option *)
    case lookup_term recsel_special of
      SOME [(n, INFIX (STD_infix([{elements = [RE(TOK s)],...}], _)))] =>
        SOME (n, s)
    | SOME _ =>
        raise PP_ERR "pp_term" "Invalid rule for record field select operator"
    | NONE => NONE
  val recupd_info = (* (precedence, upd_tok) option *)
    case lookup_term recupd_special of
      SOME [(n, INFIX (STD_infix([{elements = [RE(TOK s)],...}], _)))] =>
        SOME (Prec(n, recupd_special), s)
    | SOME _ =>
        raise PP_ERR "pp_term" "Invalid rule for record update operator"
    | NONE => NONE
  val recfupd_info = (* (precedence, with_tok) option *)
    case lookup_term recfupd_special of
      SOME [(n, INFIX (STD_infix([{elements = [RE(TOK s)],...}], _)))] =>
        SOME (Prec(n, recfupd_special), s)
    | SOME _ =>
        raise PP_ERR "pp_term" "Invalid rule for record f-update operator"
    | NONE => NONE
  val recwith_info = (* (precedence, with_tok) option *)
    case (lookup_term recwith_special) of
      SOME [(n, INFIX (STD_infix([{elements = [RE(TOK s)],...}], _)))] =>
        SOME (n, s)
    | SOME _ =>
        raise PP_ERR "pp_term"
          "Invalid form of rule for record with \"operator\""
    | NONE => NONE
  val reclist_info = (* (leftdelim, rightdelim, sep) option *)
    case lookup_term reccons_special of
      SOME [(_, LISTRULE[{separator, leftdelim, rightdelim,...}])] =>
        SOME (leftdelim, rightdelim, separator)
    | SOME _ =>
        raise PP_ERR "pp_term"
          "Invalid form of rule for record update list"
    | NONE => NONE


  val resquan_op_prec =
    case (lookup_term resquan_special) of
      SOME [] => raise Fail "term_pp : This really shouldn't happen"
    | SOME (x::xs) => SOME (#1 x)
    | NONE => NONE
  val vscons_prec = #1 (hd (valOf (lookup_term vs_cons_special)))
    handle Option =>
      raise PP_ERR "pp_term" "Grammar has no vstruct cons"
  val open_res_list_allowed =
    case resquan_op_prec of
      NONE => false
    | SOME p => p < vscons_prec

  val uprinters = user_printers G
  val printers_exist = Binarymap.numItems uprinters > 0

  (* This code will print paired abstractions "properly" only if
        1. the term has an UNCURRY constant in the right place, and
        2. the term has a preferred printing form in the overloading map.
     Both conditions above might be varied.  In 1., we could check for just
     the constant pair$UNCURRY, and not any constant called UNCURRY.  In 2.,
     we could check to see if the string "UNCURRY" mapped to a term instead.

     Another option again might be to look to see if the term is a constant
     and prints as "UNCURRY"...  The possibilities are endless.  The
     particular choice made above means that the printer does the right
     thing if given a paired abstraction to print wrt an "earlier" grammar,
     such as that used in boolTheory. *)
  fun my_dest_abs tm =
      case dest_term tm of
        LAMB p => p
      | COMB(Rator,Rand) => let
          val _ =
              fst (dest_const Rator)= "UNCURRY" andalso
              isSome (Overload.overloading_of_term overload_info Rator) orelse
              raise PP_ERR "my_dest_abs" "term not an abstraction"
          val (v1, body0) = my_dest_abs Rand
          val (v2, body) = my_dest_abs body0
        in
          (mk_pair(v1, v2), body)
        end
      | _ => raise PP_ERR "my_dest_abs" "term not an abstraction"

  fun my_is_abs tm = can my_dest_abs tm
  fun my_strip_abs tm = let
    fun recurse acc t = let
      val (v, body) = my_dest_abs t
    in
      recurse (v::acc) body
    end handle HOL_ERR _ => (List.rev acc, t)
  in
    recurse [] tm
  end

  (* allow any constant that overloads to the string "LET" to be treated as
     a let. *)
  fun is_let0 n tm = let
    val (let_tm,f_tm) = dest_comb(rator tm)
  in
    Overload.overloading_of_term overload_info let_tm = SOME "LET" andalso
    (length (#1 (my_strip_abs f_tm)) >= n orelse is_let0 (n + 1) f_tm)
  end handle HOL_ERR _ => false
  val is_let = is_let0 1



  fun dest_vstruct bnder res t =
      case bnder of
        NONE => let
        in
          case (Lib.total my_dest_abs t, res) of
            (SOME (bv, body), _) => (Simple bv, body)
          | (NONE, NONE) =>
               raise PP_ERR "dest_vstruct" "term not an abstraction"
          | (NONE, SOME s) => let
            in
              case dest_term t of
                COMB (Rator, Rand) => let
                in
                  case dest_term Rator of
                    COMB(rator1, rand1) =>
                    if has_name G s rator1 andalso my_is_abs Rand then let
                        val (bv, body) = my_dest_abs Rand
                      in
                        (Restricted{Bvar = bv, Restrictor = rand1}, body)
                      end
                    else raise PP_ERR "dest_vstruct" "term not an abstraction"
                  | _ => raise PP_ERR "dest_vstruct" "term not an abstraction"
                end
              | _ => raise PP_ERR "dest_vstruct" "term not an abstraction"
            end
        end
      | SOME s => let
        in
          case (dest_term t) of
            COMB(Rator,Rand) => let
            in
              if has_name G s Rator andalso my_is_abs Rand then let
                  val (bv, body) = my_dest_abs Rand
                in
                  (Simple bv, body)
                end
              else
                case res of
                  NONE => raise PP_ERR "dest_vstruct" "term not an abstraction"
                | SOME s => let
                  in
                    case (dest_term Rator) of
                      COMB(rator1, rand1) =>
                      if has_name G s rator1 andalso my_is_abs Rand then let
                          val (bv, body) = my_dest_abs Rand
                        in
                            (Restricted{Bvar = bv, Restrictor = rand1}, body)
                        end
                      else
                        raise PP_ERR "dest_vstruct" "term not an abstraction"
                    | _ =>
                      raise PP_ERR "dest_vstruct" "term not an abstraction"
                  end
            end
          | _ => raise PP_ERR "dest_vstruct" "term not an abstraction"
        end


  fun strip_vstructs bnder res tm = let
    fun strip acc t = let
      val (bvar, body) = dest_vstruct bnder res t
    in
      strip (bvar::acc) body
    end handle HOL_ERR _ => (List.rev acc, t)
  in
    strip [] tm
  end

  fun strip_nvstructs bnder res n tm = let
    fun strip n acc tm =
        if n <= 0 then (List.rev acc, tm)
        else let
            val (bvar, body) = dest_vstruct bnder res tm
          in
            strip (n - 1) (bvar :: acc) body
          end
  in
    strip n [] tm
  end

  val allterm_uprinter = Binarymap.peek(uprinters, {Name = "", Thy = ""})
  val polyty_uprinter = Binarymap.peek(uprinters, {Name = "'a", Thy = ""})


  fun pr_term binderp showtypes showtypes_v vars_seen pps tm
              pgrav lgrav rgrav depth = let
    val _ =
        if printers_exist then let
            fun sysprint (pg,lg,rg) depth tm =
                pr_term false showtypes showtypes_v vars_seen pps tm
                        pg lg rg depth
            val printfn_for_ty =
                case Lib.total dest_thy_type (type_of tm) of
                  NONE => polyty_uprinter
                | SOME {Tyop,Thy,Args} =>
                  Binarymap.peek(uprinters, {Name = Tyop, Thy = Thy})
            fun printwith f = (f sysprint (pgrav, lgrav, rgrav) depth pps tm;
                               raise SimpleExit)
                handle UserPP_Failed => ()
          in
            case (printfn_for_ty, allterm_uprinter) of
              (SOME f, _) => printwith f
            | (NONE, SOME f) => printwith f
            | (NONE, NONE) => ()
          end
        else ()

    val {fvars_seen, bvars_seen} = vars_seen
    val full_pr_term = pr_term
    val pr_term = pr_term binderp showtypes showtypes_v vars_seen pps
    val {add_string, add_break, begin_block, end_block,...} =
      with_ppstream pps
    fun block_by_style (addparens, rr, pgrav, fname, fprec) = let
      val needed =
        case #1 (#block_style (rr:rule_record)) of
          AroundSameName => grav_name pgrav <> fname
        | AroundSamePrec => grav_prec pgrav <> fprec
        | AroundEachPhrase => true
        | NoPhrasing => false
      fun bblock() = uncurry begin_block (#2 (#block_style rr))
    in
      if needed orelse addparens then (bblock, end_block) else (I, I)
    end
    fun pbegin b = if b then add_string "(" else ()
    fun pend b = if b then add_string ")" else ()
    fun spacep b = if b then add_break(1, 0) else ()
    fun sizedbreak n = add_break(n, 0)

    (* els is a list of pp_elements; args is a list of terms to be inserted
       in place of RE TM elements.  Returns the unused args *)
    fun print_ellist (lprec, cprec, rprec) (els, args) = let
      val recurse = print_ellist (lprec, cprec, rprec)
    in
      case els of
        [] => args
      | (e :: es) => let
        in
          case e of
            PPBlock(more_els, (sty, ind)) => let
              val _ = begin_block sty ind
              val rest = recurse (more_els, args)
              val _ = end_block()
            in
              recurse (es, rest)
            end
          | HardSpace n => (add_string (string_of_nspaces n);
                            recurse (es, args))
          | BreakSpace (n, m) => (add_break(n,m); recurse (es, args))
          | RE (TOK s) => (add_string s; recurse (es, args))
          | RE TM => (pr_term (hd args) Top Top Top (decdepth depth);
                      recurse (es, tl args))
          | FirstTM => (pr_term (hd args) cprec lprec cprec (decdepth depth);
                        recurse (es, tl args))
          | LastTM => (pr_term (hd args) cprec cprec rprec (decdepth depth);
                       recurse (es, tl args))
          | EndInitialBlock _ => raise Fail "term_pp - encountered EIB"
          | BeginFinalBlock _ => raise Fail "term_pp - encountered BFB"
        end
    end



    fun pr_vstruct bv = let
      val pr_t =
        if showtypes then full_pr_term true true showtypes_v vars_seen pps
        else full_pr_term true false showtypes_v vars_seen pps
    in
      case bv of
        Simple tm => let
        in
          if (is_pair tm orelse is_var tm) then
            pr_t tm Top Top Top (decdepth depth)
          else
            raise PP_ERR "pr_vstruct"
              "Can only handle pairs and vars as vstructs"
        end
      | Restricted{Bvar, Restrictor} => let
        in
          begin_block CONSISTENT 0;
          add_string "(";
          pr_vstruct (Simple Bvar);
          add_string (res_quanop);
          add_break(0,2);
          pr_term Restrictor Top Top Top (decdepth depth);
          add_string ")";
          end_block ()
        end
    end

    (* this function is only called in circumstances when all of a
       vstruct list is restricted with the same term and when the
       relative precedences of the res_quan_op (traditionally "::") is
       less than that of VSCONS.  If this situation pertains, then we
       can print out all of the vstruct items in a row, and then
       finish off with a single :: <tm>. For example \x y z::Q.

       The accompanying can_print_vstructl function spots when the
       situation as described above pertains.

       One final wrinkle has to be dealt with:
         The restricting term might have an occurrence in it of
         something that needs to be printed so that it looks like the
         endbinding token.  If this happens, then the restriction needs
         to be parenthesised.  In particular, the standard syntax has
         "." as the endbinding token and as the infix record selection
         operator, so that if you write
             !x y :: (rec.fld1). body
         the parenthesisation needs to be preserved.

         So, we have one last auxiliary function which determines whether
         or not the restrictor might print an endbinding token. *)

    infix might_print nmight_print
    fun (r as {Name,Thy}) nmight_print str = let
      val actual_name0 =
        case Overload.overloading_of_nametype overload_info r of
          NONE => Name
        | SOME s => s
      fun testit s = if isPrefix s actual_name0 then SOME s else NONE
      val actual_name =
        case find_partial testit [recsel_special, recupd_special,
                                  recfupd_special] of
          NONE => actual_name0
        | SOME s => s
      val rule = lookup_term actual_name
    in
      case rule of
        NONE => Name = str
      | SOME rrlist =>
          List.exists (mem str o term_grammar.rule_tokens G o #2) rrlist
    end

    fun tm might_print str =
      case (dest_term tm) of
        COMB(Rator, Rand) => Rator might_print str orelse Rand might_print str
      | LAMB(_,Body) => Body might_print str
      | VAR(Name,Ty) => Name = str
      | CONST x => (lose_constrec_ty x) nmight_print str


    fun pr_res_vstructl restrictor res_op vsl = let
      val simples = map (Simple o bv2term) vsl
      val add_final_parens = restrictor might_print endbinding
    in
      begin_block CONSISTENT 2;
      begin_block INCONSISTENT 2;
      pr_list pr_vstruct (fn () => ()) (fn () => add_break(1,0)) simples;
      end_block();
      add_string res_op;
      pbegin add_final_parens;
      pr_term restrictor Top Top Top (decdepth depth);
      pend add_final_parens;
      end_block ()
    end
    fun can_print_vstructl vsl = let
      fun recurse acc [] = SOME acc
        | recurse acc ((Simple _)::_) = NONE
        | recurse acc (Restricted{Restrictor = t,...}::xs) = let
          in
            if t = acc then recurse acc xs else NONE
          end
    in
      case vsl of
        [] => raise PP_ERR "can_print_vstructl" "Empty list!"
      | (Simple _::xs) => NONE
      | (Restricted{Restrictor = t,...}::xs) => recurse t xs
    end

    (* the pr_vstructl function figures out which way to print a given
       list of vstructs *)
    fun pr_vstructl vsl =
      case can_print_vstructl vsl of
        SOME r => pr_res_vstructl r res_quanop vsl
      | _ => let
        in
          begin_block INCONSISTENT 2;
          pr_list pr_vstruct (fn () => ()) (fn () => add_break(1,0)) vsl;
          end_block ()
        end

    fun pr_abs tm = let
      val addparens = lgrav <> RealTop orelse rgrav <> RealTop
      val restr_binder =
        find_partial (fn (b,s) => if b = LAMBDA then SOME s else NONE)
        restr_binders
      val (bvars, body) = strip_vstructs NONE restr_binder tm
      val bvars_seen_here = List.concat (map (free_vars o bv2term) bvars)
      val old_seen = !bvars_seen
    in
      pbegin addparens;
      begin_block CONSISTENT 2;
      add_string lambda;
      pr_vstructl bvars;
      add_string endbinding; add_break (1,0);
      bvars_seen := bvars_seen_here @ old_seen;
      pr_term body Top Top Top (decdepth depth);
      bvars_seen := old_seen;
      end_block();
      pend addparens
    end

    fun atom_name tm =
      fst (dest_var tm handle HOL_ERR _ => dest_const tm)
    fun can_pr_numeral stropt = List.exists (fn (k,s') => s' = stropt) num_info
    fun pr_numeral injtermopt tm = let
      open Overload
      val numty = Type.mk_thy_type {Tyop="num", Thy="num", Args=[]}
      val num2numty = numty --> numty
      val numinfo_search_string = Option.map (fst o dest_const) injtermopt
      val inj_record =
        case injtermopt of
          NONE => {Name = nat_elim_term, Thy = "arithmetic",
                   Ty = numty --> numty}
        | SOME t => dest_thy_const t
      val injty = #Ty inj_record
      val is_a_real_numeral = (* i.e. doesn't need a suffix *)
          case info_for_name overload_info fromNum_str of
            NONE => false
          | SOME oi => mem inj_record (#actual_ops oi)
    in
      pbegin showtypes;
      add_string (Arbnum.toString (Literal.dest_numeral tm));
      if not is_a_real_numeral orelse !Globals.show_numeral_types
      then let
        val (k, _) =
          valOf (List.find (fn (_, s') => s' = numinfo_search_string) num_info)
      in
        add_string (str k)
      end
      else ();
      if showtypes then
        (add_string (" "^type_intro); add_break (0,0);
         type_pp.pp_type_with_depth TyG pps (decdepth depth) (#2 (dom_rng injty)))
      else ();
      pend showtypes
    end

    fun pr_comb tm t1 t2 = let
      val add_l =
        case lgrav of
           Prec (n, _) => (n >= comb_prec)
         | _ => false
      val add_r =
        case rgrav of
          Prec (n, _) => (n > comb_prec)
        | _ => false
      val addparens = add_l orelse add_r
      val _ = case total Literal.dest_string_lit tm
               of NONE => ()
                | SOME s => (add_string (Lib.mlquote s); raise SimpleExit)
      val _ =
        if Literal.is_numeral tm andalso can_pr_numeral NONE then
          (pr_numeral NONE tm; raise SimpleExit)
        else
          ()
      val _ =
        (if Literal.is_numeral t2
            andalso can_pr_numeral (SOME (atom_name t1))
         then (pr_numeral (SOME t1) t2; raise SimpleExit)
         else ()) handle SimpleExit => raise SimpleExit | _ => ()
      val _ =
        if my_is_abs tm then (pr_abs tm; raise SimpleExit)
        else ()




      val _ = (* check for set comprehensions *)
        if
          is_const t1 andalso fst (dest_const t1) = "GSPEC" andalso
          my_is_abs t2 then let
            val (_, body) = my_dest_abs t2
            val (l, r) = dest_pair body
          in
            begin_block CONSISTENT 0;
            add_string "{"; begin_block CONSISTENT 0;
            pr_term l Top Top Top (decdepth depth);
            add_string " |"; spacep true;
            pr_term r Top Top Top (decdepth depth);
            end_block(); add_string "}"; end_block(); raise SimpleExit
          end handle HOL_ERR _ => ()
        else ()

      exception NotReallyARecord
      val _ = (* check for record field selection *)
        if is_const t1 then let
          val rname_opt = Overload.overloading_of_term overload_info t1
        in
          case rname_opt of
            SOME s => let
              val fldname =
                  if isSome recsel_info then
                    if isPrefix recsel_special s then
                      SOME (String.extract(s, size recsel_special, NONE), t2)
                    else if is_substring bigrec_subdivider_string s andalso
                            !prettyprint_bigrecs
                    then let
                        open Overload
                        val brss = bigrec_subdivider_string
                        val (f, x) = dest_comb t2
                        val _ = is_const f orelse raise NotReallyARecord
                        val fname = valOf (overloading_of_term overload_info f)
                        val _ = is_substring (brss ^ "sf") fname orelse
                                raise NotReallyARecord
                        open Substring
                        val (_, brsssguff) = position brss (all s)
                        val dropguff = slice(brsssguff, String.size brss, NONE)
                        val dropdigits = dropl Char.isDigit dropguff
                        val fldname = string(slice(dropdigits, 1, NONE))
                      in
                        SOME (fldname, x)
                      end handle HOL_ERR _ => NONE
                               | NotReallyARecord => NONE
                               | Option => NONE
                    else NONE
                  else NONE
            in
              case fldname of
                SOME(fldname, t2) => let
                  val (prec0, fldtok) = valOf recsel_info
                  (* assumes that field selection is always left associative *)
                  val add_l =
                      case lgrav of
                        Prec(n, _) => n >= prec0
                      | _ => false
                  val add_r =
                      case rgrav of
                        Prec(n, _) => n > prec0
                      | _ => false
                  val prec = Prec(prec0, recsel_special)
                  val add_parens = add_l orelse add_r
                  val lprec = if add_parens then Top else lgrav
                in
                  begin_block INCONSISTENT 0;
                  pbegin add_parens;
                  pr_term t2 prec lprec prec (decdepth depth);
                  add_string fldtok;
                  add_break(0,0);
                  add_string fldname;
                  pend add_parens;
                  end_block (); raise SimpleExit
                end
              | NONE => ()
            end
          | NONE => ()
        end
        else ()

      val _ = (* check for record update *)
        if isSome recwith_info andalso isSome reclist_info andalso
           isSome recfupd_info andalso isSome recupd_info
        then let
          open Overload
          (* function to determine if t is a record update *)
          fun is_record_update t =
            if is_comb t andalso is_const (rator t) then let
              val rname = overloading_of_term overload_info (rator t)
            in
              case rname of
                SOME s =>
                (!prettyprint_bigrecs andalso isSuffix "_fupd" s andalso
                 is_substring (bigrec_subdivider_string ^ "sf") s) orelse
                isPrefix recfupd_special s
              | NONE => false
            end else false
          (* descend the rands of a term until one that is not a record
             update is found.  Return this and the list of rators up to
             this point. *)
          fun find_first_non_update acc t =
            if is_comb t andalso is_record_update (rator t) then
              find_first_non_update ((rator t)::acc) (rand t)
            else
              (List.rev acc, t)
          fun categorise_bigrec_updates v = let
            fun bigrec_update t =
                if is_comb t then
                  case overloading_of_term overload_info (rator t) of
                    SOME s => if is_substring bigrec_subdivider_string s then
                                SOME (s, rand t)
                              else NONE
                  | NONE => NONE
                else NONE
            fun strip_o acc tlist =
                case tlist of
                  [] => acc
                | t::ts => let
                    val (f, args) = strip_comb t
                    val {Name,Thy,...} = dest_thy_const f
                  in
                    if Name = "o" andalso Thy = "combin" then
                      strip_o acc (hd (tl args) :: hd args :: ts)
                    else strip_o (t::acc) ts
                  end handle HOL_ERR _ => strip_o (t::acc) ts
            fun strip_bigrec_updates t = let
              val internal_upds = strip_o [] [t]
            in
              List.mapPartial bigrec_update internal_upds
            end
            fun categorise_bigrec_update (s, value) = let
              (* first strip suffix, and decide if a normal update *)
              val sz = size s
              val (s, value, value_upd) = let
                (* suffix will be "_fupd" *)
                val (f, x) = dest_comb value
                val {Thy, Name, ...} = dest_thy_const f
              in
                if Thy = "combin" andalso Name = "K" then
                  (String.extract(s, 0, SOME (sz - 5)), x, true)
                else
                  (String.extract(s, 0, SOME (sz - 5)), value, false)
              end handle HOL_ERR _ =>
                         (String.extract(s,0,SOME (sz - 5)), value, false)

              val ss = Substring.all s
              val (_, ss) = (* drop initial typename *)
                  Substring.position bigrec_subdivider_string ss
              val ss = (* drop bigrec_subdivider_string *)
                  Substring.slice(ss, size bigrec_subdivider_string, NONE)
              val ss = (* drop subrecord number *)
                  Substring.dropl Char.isDigit ss
              val ss = (* drop underscore before field name *)
                  Substring.slice(ss, 1, NONE)
            in
              (Substring.string ss, value, value_upd)
            end handle Subscript => raise NotReallyARecord
          in
            map categorise_bigrec_update (strip_bigrec_updates v)
          end
          fun categorise_update t = let
            (* t is an update, possibly a bigrec monster.  Here we generate
               a list of real updates (i.e., the terms corresponding to the
               new value in the update), each with an accompanying field
               string, and a boolean, which is true iff the update is a value
               update (not a "fupd") *)
            val (fld, value) = dest_comb t
            val rname = valOf (Overload.overloading_of_term overload_info fld)
          in
            if isPrefix recfupd_special rname then let
                val (f, x) = dest_comb value
                val {Thy, Name,...} = dest_thy_const f
                val fldname = String.extract(rname,size recfupd_special, NONE)
              in
                if Thy = "combin" andalso Name = "K" then [(fldname, x, true)]
                else [(fldname, value, false)]
              end handle HOL_ERR _ =>
                         [(String.extract(rname,size recfupd_special, NONE),
                           value, false)]
            else (* is a big record - examine value *)
              assert (not o null) (categorise_bigrec_updates value)
              handle HOL_ERR _ => raise NotReallyARecord
          end
        in
          if is_record_update t1 then let
            val (updates0, base) = find_first_non_update [] t2
            val updates = List.concat (map categorise_update (t1::updates0))
            val (with_prec, with_tok) = valOf recwith_info
            val (ldelim, rdelim, sep) = valOf reclist_info
            fun print_update depth (fld, value, normal_upd) = let
              val (upd_prec, updtok) =
                if normal_upd then valOf recupd_info
                else valOf recfupd_info
            in
              begin_block INCONSISTENT 2;
              add_string fld ;
              add_string " ";
              add_string updtok;
              add_break(1,0);
              pr_term value upd_prec upd_prec Top (decdepth depth);
              end_block ()
            end
            fun print_updlist updates = let
              fun recurse depth upds =
                  if depth = 0 then add_string "..."
                  else
                    case upds of
                      [] => () (* should never happen *)
                    | [u] => print_update (decdepth depth) u
                    | u::us => (print_update (decdepth depth) u;
                                print_ellist(Top,Top,Top) (sep, []);
                                recurse (decdepth depth) us)
            in
              print_ellist (Top,Top,Top) (ldelim, []);
              begin_block INCONSISTENT 0;
              recurse depth updates;
              end_block ();
              print_ellist (Top,Top,Top) (rdelim, []);
              ()
            end
          in
            if is_const base andalso fst (dest_const base) = "ARB" then
              (print_updlist updates; raise SimpleExit)
            else let
              val add_l =
                case lgrav of
                  Prec(n, _) => n > with_prec
                | _ => false
              val add_r =
                case rgrav of
                  Prec(n, _) => n > with_prec
                | _ => false
              val addparens = add_l orelse add_r
              val lprec = if addparens then Top else lgrav
              val with_grav = Prec(with_prec, recwith_special)
            in
              pbegin addparens;
              begin_block INCONSISTENT 0;
              pr_term base with_grav lprec with_grav (decdepth depth);
              add_string " ";
              add_string with_tok;
              add_break (1,0);
              if length updates = 1 then print_update depth (hd updates)
              else print_updlist updates;
              end_block();
              pend addparens;
              raise SimpleExit
            end
          end handle NotReallyARecord => ()
          else ()
        end
        else ()

      val prec = Prec(comb_prec, fnapp_special)
      val lprec = if addparens then Top else lgrav
      val rprec = if addparens then Top else rgrav
    in
      pbegin addparens;
      begin_block INCONSISTENT 2;
      pr_term t1 prec lprec prec (decdepth depth);
      add_break (1, 0);
      pr_term t2 prec prec rprec (decdepth depth);
      end_block();
      pend addparens
    end handle SimpleExit => ()

    fun pr_sole_name n rules = let
      (* This function prints a solitary name n.  The rules are possibly
         relevant rules from the grammar.  If one is a list rule, and our
         n is the name of the nil case, then we should print that
         list's delimiters around nothing.
         Otherwise, the presence of a rule with our name n in it, is a
         probable indication that our name will need a $ printed out in
         front of it. *)
      fun check_rule rule =
        case rule of
          LISTRULE lrules => List.find (fn r => #nilstr r = n) lrules
        | _ => NONE
      val nilrule = find_partial check_rule rules
    in
      case nilrule of
        SOME r => (ignore (print_ellist (Top,Top,Top) (#leftdelim r, []));
                   ignore (print_ellist (Top,Top,Top) (#rightdelim r, [])))
      | NONE => let
          (* if only rule is a list form rule and we've got to here, it
             will be a rule allowing this to the cons part of a list form.
             Such functions don't need to be dollar-ed *)
        in
          case rules of
            [LISTRULE _] => add_string n
          | _ =>
              if isSome (Polyhash.peek spec_table n) then
                add_string (dollarise n)
              else add_string n
        end
    end

    fun pr_comb_with_rule frule fterm args Rand = let
      val {fname,fprec,f} = fterm
      fun block_up_els acc els =
        case els of
          [] => List.rev acc
        | (e::es) => let
          in
            case e of
              EndInitialBlock bi =>
                block_up_els [PPBlock(List.rev acc, bi)] es
            | BeginFinalBlock bi => let
                val block_of_rest = block_up_els [] es
              in
                List.rev (PPBlock(block_of_rest, bi)::acc)
              end
            | x => block_up_els (x::acc) es
          end
    in
      case frule of
        INFIX(STD_infix(lst, fassoc)) => let
          val rr = hd lst
          val elements = #elements rr
          fun check_grav a grav =
            case grav of
              Prec(n, _) =>
                (n > fprec) orelse (n = fprec andalso a <> fassoc)
            | _ => false
          val parens_needed_outright =
            check_grav RIGHT lgrav orelse check_grav LEFT rgrav
          val parens_needed_by_style =
            pneeded_by_style(rr, pgrav, fname, fprec)
          val addparens = parens_needed_outright orelse parens_needed_by_style
          val prec = Prec(fprec, fname)
          val lprec = if addparens then Top else lgrav
          val rprec = if addparens then Top else rgrav
          val arg_terms = args @ [Rand]
          val pp_elements = block_up_els [] ((FirstTM::elements) @ [LastTM])
          val (begblock, endblock) =
            block_by_style(addparens, rr, pgrav, fname, fprec)
        in
          pbegin addparens; begblock();
          print_ellist (lprec, prec, rprec) (pp_elements, arg_terms);
          endblock (); pend addparens
        end
      | INFIX RESQUAN_OP => raise Fail "Res. quans shouldn't arise"
      | INFIX (FNAPP _) => raise PP_ERR "pr_term" "fn apps can't arise"
      | INFIX VSCONS => raise PP_ERR "pr_term" "vs cons can't arise"
      | SUFFIX (STD_suffix lst) => let
          val rr = hd lst
          val elements = #elements rr
          val parens_needed_outright =
            case lgrav of
              Prec(n, _) => n > fprec
            | _ => false
          val parens_needed_by_style =
            pneeded_by_style (rr, pgrav, fname, fprec)
          val addparens = parens_needed_outright orelse parens_needed_by_style
          val lprec = if addparens then Top else lgrav
          val prec = Prec(fprec, fname)
          val real_args = args @ [Rand]
          val pp_elements = block_up_els [] (FirstTM :: elements)
          val (begblock, endblock) =
            block_by_style(addparens, rr, pgrav, fname, fprec)
        in
          pbegin addparens; begblock();
          print_ellist (lprec, prec, Top) (pp_elements, real_args);
          endblock(); pend addparens
        end
      | SUFFIX TYPE_annotation =>
        raise Fail "Type annotation shouldn't arise"
      | PREFIX (STD_prefix lst) => let
          val rr = hd lst
          val elements = #elements rr
          val parens_needed_outright =
            case rgrav of
              Prec(n, _) => n > fprec
            | _ => false
          val addparens = parens_needed_outright orelse
            pneeded_by_style(rr, pgrav, fname, fprec)
          val rprec = if addparens then Top else rgrav
          val pp_elements = block_up_els [] (elements @ [LastTM])
          val real_args = args @ [Rand]
          val prec = Prec(fprec, fname)
          val (begblock, endblock) =
            block_by_style(addparens, rr, pgrav, fname, fprec)
        in
          pbegin addparens; begblock();
          print_ellist (Top, prec, rprec) (pp_elements, real_args);
          endblock(); pend addparens
        end
      | PREFIX (BINDER _) => let
          fun find (BinderString bs, s) = if bs = fname then SOME s else NONE
            | find _ = NONE
          val restr_binder = find_partial find restr_binders
          val (bvs, body) = strip_vstructs (SOME fname) restr_binder tm
          val bvars_seen_here = List.concat (map (free_vars o bv2term) bvs)
          val old_seen = !bvars_seen
          val addparens =
            case rgrav of
              Prec(n, _) => n > fprec
            | _ => false
        in
          pbegin addparens; begin_block INCONSISTENT 2;
          add_string fname;
          spacep (not (symbolic fname));
          pr_vstructl bvs;
          add_string endbinding; spacep true;
          begin_block CONSISTENT 0;
          bvars_seen := bvars_seen_here @ old_seen;
          pr_term body Top Top Top (decdepth depth);
          bvars_seen := old_seen;
          end_block ();
          end_block();
          pend addparens
        end
      | CLOSEFIX lst => let
          val rr = hd lst
          val elements = #elements rr
        in
          uncurry begin_block (#2 (#block_style rr)) ;
          print_ellist (Top, Top, Top) (elements, args @ [Rand]);
          end_block()
        end
      | LISTRULE lrules => let
          val (r as {nilstr, cons, ...}) =
            valOf (List.find (fn r => #cons r = fname) lrules)
          val sep = #separator r
          val rdelim = #rightdelim r
          val ldelim = #leftdelim r
          (* list will never be empty *)
          fun pr_list tm = let
            fun recurse depth tm = let
              val (_, args) = strip_comb tm
              val head = hd args
              val tail = List.nth(args, 1)
            in
              if depth = 0 then add_string "..."
              else if has_name G nilstr tail then
                (* last element *)
                pr_term head Top Top Top (decdepth depth)
              else let
              in
                pr_term head Top Top Top (decdepth depth);
                print_ellist (Top,Top,Top) (sep, []);
                recurse (decdepth depth) tail
              end
            end
          in
            print_ellist (Top,Top,Top) (ldelim, []) ;
            begin_block INCONSISTENT 0;
            recurse depth tm;
            end_block();
            ignore (print_ellist (Top,Top,Top) (rdelim, []))
          end
        in
          pr_list tm
        end
    end

    fun pr_let0 tm = let
      fun find_base acc tm =
        if is_let tm then let
          val (let_tm, args) = strip_comb tm
        in
          find_base (List.nth(args, 1)::acc) (hd args)
        end
        else (acc, tm)
      fun pr_leteq (bv, tm2) = let
        val (args, rhs_t) = strip_vstructs NONE NONE tm2
        val bvars_seen_here = List.concat (map (free_vars o bv2term) args)
        val old_seen = (free_vars (bv2term bv)) @ (!bvars_seen)
      in
        begin_block INCONSISTENT 2;
        pr_vstruct bv; spacep true;
        pr_list pr_vstruct (fn () => ()) (fn () => spacep true) args;
        bvars_seen := bvars_seen_here @ old_seen;
        spacep (not (null args));
        add_string "="; spacep true;
        begin_block INCONSISTENT 2;
        pr_term rhs_t Top Top Top (decdepth depth);
        end_block();
        bvars_seen := old_seen;
        end_block()
      end
      val (values, abstr) = find_base [] tm
      val (varnames, body) =
          strip_nvstructs NONE NONE (length values) abstr
      val name_value_pairs = ListPair.zip (varnames, values)
    in
      (* put a block around the "let ... in" phrase *)
      begin_block CONSISTENT 0;
      add_string "let ";
      (* put a block around the variable bindings *)
      begin_block INCONSISTENT 0;
      pr_list pr_leteq (fn () => add_string " and")
              (fn () => spacep true) name_value_pairs;
      end_block(); (* end of variable binding block *)
      spacep true; add_string "in";
      end_block(); (* end of "let ... in" phrase block *)
      if is_let body then (add_break(1,0); pr_let0 body)
      else
        (add_break(1,2);
         (* a lie! but it works *)
         pr_term body RealTop RealTop RealTop (decdepth depth))
    end

    fun pr_let lgrav rgrav tm = let
      val addparens = lgrav <> RealTop orelse rgrav <> RealTop
      val old_bvars_seen = !bvars_seen
    in
      pbegin addparens;
      begin_block CONSISTENT 0;
      pr_let0 tm;
      end_block();
      pend addparens;
      bvars_seen := old_bvars_seen
    end

    fun print_ty_antiq tm = let
      val ty = dest_ty_antiq tm
    in
      begin_block CONSISTENT 2;
      add_string "(ty_antiq(";
      add_break(0,0);
      add_string "`:";
      type_pp.pp_type_with_depth TyG pps (decdepth depth) ty;
      add_string "`))";
      end_block()
    end

    val _ = if is_ty_antiq tm then (print_ty_antiq tm; raise SimpleExit)
            else ()


    (* used to determine whether or not to print out disambiguating type
       information when showtypes_v is true *)
    fun const_is_polymorphic (r as {Name,Thy}) = let
      val genconst = prim_mk_const r
    in
      Type.polymorphic (type_of genconst)
    end handle HOL_ERR _ => false
    (* the exception is possible if the constant is out of date *)

    fun const_has_multi_ovl (r as {Name,Thy}) =
      case Overload.overloading_of_nametype overload_info r of
        NONE => false
      | SOME s =>
          case Overload.info_for_name overload_info s of
            NONE => false (* seems pretty unlikely *)
          | SOME {actual_ops,...} => length actual_ops > 1

    fun const_is_ambiguous (r as {Name,Thy}) =
      const_is_polymorphic r orelse const_has_multi_ovl r

  in
    if depth = 0 then add_string "..."
    else
      case dest_term tm of
        VAR(vname, Ty) => let
          val vrule = lookup_term vname
          fun add_type () = let
          in
            add_string (" "^type_intro); add_break (0,0);
            type_pp.pp_type_with_depth TyG pps (decdepth depth) Ty
          end
          val new_freevar =
            showtypes andalso (not (mem tm (!fvars_seen))) andalso
            not (mem tm (!bvars_seen)) andalso not binderp
          val _ = if new_freevar then fvars_seen := tm :: (!fvars_seen) else ()
          val print_type =
            showtypes_v orelse
            showtypes andalso (binderp orelse new_freevar)
        in
          begin_block INCONSISTENT 2; pbegin print_type;
          if isSome vrule then pr_sole_name vname (map #2 (valOf vrule))
          else
            if isSome (Polyhash.peek spec_table vname) then
              add_string (dollarise vname)
            else
              add_string vname;
          if print_type then add_type() else ();
          pend print_type; end_block()
        end
      | CONST{Name, Thy, Ty} => let
          fun add_prim_name () = add_string (Thy ^ "$" ^ Name)
          fun with_type action = let
          in
            pbegin true;
            action();
            add_string (" "^type_intro);
            type_pp.pp_type_with_depth TyG pps (decdepth depth) Ty;
            pend true
          end
          val r = {Name = Name, Thy = Thy}
          fun normal_const () = let
            fun cope_with_rules s = let
              val crules = lookup_term s
            in
              if isSome crules then
                pr_sole_name s (map #2 (valOf crules))
              else if s = "0" andalso can_pr_numeral NONE then
                pr_numeral NONE tm
              else if Name="EMPTYSTRING" andalso Thy="string" then
                add_string "\"\""
              else add_string s
            end
          in
            case Overload.overloading_of_term overload_info tm of
              NONE => add_prim_name()
            | SOME s =>
                (* term is overloaded *)
                if isPrefix recsel_special s orelse
                   isPrefix recupd_special s orelse
                   isPrefix recfupd_special s
                then
                  (* if overloaded to a record special, check to see if it *)
                  (* has a normal name in the map that we could use instead. *)
                  (* This way we will print out something that can still be *)
                  (* parsed back to the original term, without having to go *)
                  (* for full uglification with dollared syntax.  *)

                  (* Note that if we've got this far, we can't print out *)
                  (* the special record syntax for some other reason, so *)
                  (* is our "fall-back" action *)
                  case Overload.info_for_name overload_info Name of
                    NONE => add_prim_name()
                  | SOME {actual_ops,...} =>
                    if List.exists
                         (fn r => #Thy r = Thy andalso #Name r = Name)
                         actual_ops
                    then
                      cope_with_rules Name
                    else
                      add_prim_name()
                else
                  cope_with_rules s
          end
        in
          case (showtypes_v, const_is_polymorphic r, const_has_multi_ovl r) of
            (true, false, true) => add_prim_name()
          | (true, true, true) => with_type add_prim_name
          | (true, true, false) => with_type normal_const
          | _ => normal_const()
        end
      | COMB(Rator, Rand) => let
          val (f, args) = strip_comb Rator
          val () = (* check for case expressions *)
              if is_const f then
                case Overload.overloading_of_term overload_info f of
                  SOME "case" =>
                  (let
                     val newt = convert_case tm
                     val (t1, t2) = dest_comb newt
                   in
                     pr_term newt pgrav lgrav rgrav depth;
                     raise SimpleExit
                   end handle CaseConversionFailed => ())
                | _ => ()
              else ()

          fun is_atom tm = is_const tm orelse is_var tm
          fun pr_atomf fname =
           let val candidate_rules = lookup_term fname
               fun is_list (r as {nilstr, cons, ...}:listspec) tm =
                    (has_name G nilstr tm)
                    orelse
                    is_comb tm andalso
                      let val (t0, tail) = dest_comb tm
                      in is_list r tail andalso is_comb t0
                         andalso has_name G cons (rator t0)
                      end
               val restr_binder =
                  find_partial (fn (b,s) => if s=fname then SOME b else NONE)
                          restr_binders
               val restr_binder_rule =
                let val condition = isSome restr_binder andalso
                                    length args = 1 andalso my_is_abs Rand
                in if condition
                   then let val optrule = lookup_term
                                  (binder_to_string G (valOf restr_binder))
                            fun ok_rule (_, r) =
                                case r of PREFIX(BINDER _) => true
                                        | otherwise => false
                        in
                           case optrule
                            of SOME rule_list => List.find ok_rule rule_list
                             | otherwise => NONE
                        end
                   else NONE
                end
           in
             case candidate_rules of
               NONE =>
                 if is_let tm then pr_let lgrav rgrav tm
                 else let
                 in
                   case restr_binder of
                     NONE => pr_comb tm Rator Rand
                   | SOME LAMBDA =>
                       if isSome restr_binder_rule then pr_abs tm
                       else pr_comb tm Rator Rand
                   | SOME (BinderString bs) =>
                         if isSome restr_binder_rule then
                           pr_comb_with_rule(#2(valOf restr_binder_rule))
                           {fprec = #1 (valOf restr_binder_rule),
                            fname = binder_to_string G (valOf restr_binder),
                            f = f} args Rand
                         else
                           pr_comb tm Rator Rand
                 end
             | SOME crules0 =>
              let fun suitable_rule rule =
                  case rule of
                    INFIX(STD_infix(rrlist, _)) =>
                      numTMs (rule_elements (#elements (hd rrlist))) + 1 =
                      length args
                  | INFIX RESQUAN_OP => raise Fail "Can't happen 90212"
                  | PREFIX (STD_prefix list) =>
                      numTMs (rule_elements (#elements (hd list))) =
                      length args
                  | PREFIX (BINDER _) => my_is_abs Rand andalso length args = 0
                  | SUFFIX (STD_suffix list) =>
                      numTMs (rule_elements (#elements (hd list))) =
                      length args
                  | SUFFIX Type_annotation => raise Fail "Can't happen 90210"
                  | CLOSEFIX list =>
                      numTMs (rule_elements (#elements (hd list))) - 1 =
                      length args
                  | INFIX (FNAPP _) => raise Fail "Can't happen 90211"
                  | INFIX VSCONS => raise Fail "Can't happen 90213"
                  | LISTRULE list => is_list (hd list) tm
                val crules = List.filter (suitable_rule o #2) crules0
                fun is_lrule (LISTRULE _) = true | is_lrule _ = false
                fun is_binder_rule (PREFIX (BINDER s)) = true
                  | is_binder_rule _ = false
                val (lrules, others0) = splitP (is_lrule o #2) crules
                val (brules, others) = splitP (is_binder_rule o #2) others0
              in
                if not (null brules) then
                  pr_comb_with_rule (#2 (hd brules))
                    {fprec = #1 (hd brules), fname=fname, f=f} args Rand
                else
                  if not (null lrules) then
                    pr_comb_with_rule (#2 (hd lrules))
                      {fprec = #1 (hd lrules), fname=fname, f=f} args Rand
                  else
                    if not (null others) then let
                      val preferred =
                        List.find (#preferred o hd o rule_to_rr o #2) others
                    in
                      case preferred of
                        SOME (p,r) =>
                          pr_comb_with_rule r {fprec=p, fname=fname, f=f}
                          args Rand
                      | NONE => pr_comb tm Rator Rand
                    end
                    else
                      pr_comb tm Rator Rand
              end
           end (* pr_atomf *)
          fun maybe_pr_atomf () =
            case Overload.overloading_of_term overload_info f of
              SOME s => pr_atomf s
            | NONE => if is_var f then pr_atomf (fst (dest_var f))
                      else pr_comb tm Rator Rand
        in
          if showtypes_v then
            if is_const f then let
              val {Name,Thy,Ty} = dest_thy_const f
            in
              if const_is_ambiguous {Name = Name, Thy = Thy} then
                pr_comb tm Rator Rand
              else
                maybe_pr_atomf()
            end
            else pr_comb tm Rator Rand
          else maybe_pr_atomf()
        end
      | LAMB(Bvar, Body) => pr_abs tm
  end handle SimpleExit => ()
  fun start_names() = {fvars_seen = ref [], bvars_seen = ref []}
in
  fn pps => fn t =>
    let in
       Portable.begin_block pps CONSISTENT 0;
       pr_term false
               (!Globals.show_types orelse !Globals.show_types_verbosely)
               (!Globals.show_types_verbosely)
               (start_names())
               pps t RealTop RealTop RealTop (!Globals.max_print_depth);
       Portable.end_block pps
    end
end

(* testing
use "term_pp.sml";
val G = let
  open term_grammar
  infix Gmerge
in
  stdhol Gmerge simple_arith Gmerge semantics_rules
end
fun p tm =
  Portable.pp_to_string 75
   (fn pp => fn tm => pp_term G parse_type.BaseHOLgrammar pp tm) tm;
fun pr q = print (p (Term q) ^ "\n")

new_type {Name = "fmap", Arity = 2};

val G' = [(0, parse_type.INFIX("->", "fun", parse_type.RIGHT)),
     (1, parse_type.INFIX("=>", "fmap", parse_type.NONASSOC)),
     (2, parse_type.INFIX("+", "sum", parse_type.LEFT)),
     (3, parse_type.INFIX("#", "prod", parse_type.RIGHT)),
     (100, parse_type.SUFFIX("list", true)),
     (101, parse_type.SUFFIX("fun", false)),
     (102, parse_type.SUFFIX("prod", false)),
     (103, parse_type.SUFFIX("sum", false))];
fun p ty =
  Portable.pp_to_string 75
   (fn pp => fn ty => type_pp.pp_type G' pp ty type_pp.Top 100) ty;

p (Type`:(bool,num)fmap`)

*)

end; (* term_pp *)
