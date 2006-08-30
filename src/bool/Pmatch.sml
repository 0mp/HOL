structure Pmatch :> Pmatch =
struct

open HolKernel boolSyntax;

type thry   = {Tyop : string, Thy : string} ->
              {case_const : term, constructors : term list} option

val ERR = mk_HOL_ERR "Functional";


(*---------------------------------------------------------------------------
      Miscellaneous support
 ---------------------------------------------------------------------------*)

fun gtake f =
  let fun grab(0,rst) = ([],rst)
        | grab(n, x::rst) =
             let val (taken,left) = grab(n-1,rst)
             in (f x::taken, left) end
        | grab _ = raise ERR "gtake" "grab.empty list"
  in grab
  end;

fun list_to_string f delim =
  let fun stringulate [] = []
        | stringulate [x] = [f x]
        | stringulate (h::t) = f h::delim::stringulate t
  in
    fn l => String.concat (stringulate l)
  end;

val stringize = list_to_string int_to_string ", ";

fun enumerate l = map (fn (x,y) => (y,x)) (Lib.enumerate 0 l);

fun match_term thry tm1 tm2 = Term.match_term tm1 tm2;
fun match_type thry ty1 ty2 = Type.match_type ty1 ty2;

fun match_info db s = db s

(*---------------------------------------------------------------------------
 * This datatype carries some information about the origin of a
 * clause in a function definition.
 *---------------------------------------------------------------------------*)

datatype pattern = GIVEN   of term * int
                 | OMITTED of term * int

fun psubst theta (GIVEN (tm,i)) = GIVEN(subst theta tm, i)
  | psubst theta (OMITTED (tm,i)) = OMITTED(subst theta tm, i);

fun dest_pattern (GIVEN (tm,i)) = ((GIVEN,i),tm)
  | dest_pattern (OMITTED (tm,i)) = ((OMITTED,i),tm);

val pat_of = #2 o dest_pattern;
val row_of_pat = #2 o #1 o dest_pattern;

fun not_omitted (GIVEN(tm,_)) = tm
  | not_omitted (OMITTED _) = raise ERR"not_omitted" ""
val givens = mapfilter not_omitted;


(*---------------------------------------------------------------------------
 * Produce an instance of a constructor, plus genvars for its arguments.
 *---------------------------------------------------------------------------*)

fun fresh_constr ty_match colty gv c =
  let val (_, Ty) = dest_const c
      val (L,ty) = strip_fun Ty
      val ty_theta = ty_match ty colty
      val c' = inst ty_theta c
      val gvars = map (inst ty_theta o gv) L
  in (c', gvars)
  end;


(*---------------------------------------------------------------------------*
 * Goes through a list of rows and picks out the ones beginning with a       *
 * pattern = Literal, or all those beginning with a variable if the pattern  *
 * is a variable.                                                            *
 *---------------------------------------------------------------------------*)

fun mk_groupl Literal rows =
  let fun func (row as ((prefix, p::rst), rhs)) (in_group,not_in_group) =
               if (is_var Literal andalso is_var p) orelse p = Literal
               then if is_var Literal
                    then (((prefix,p::rst), rhs)::in_group, not_in_group)
                    else (((prefix,rst), rhs)::in_group, not_in_group)
               else (in_group, row::not_in_group)
        | func _ _ = raise ERR "mk_groupc" ""
  in
    itlist func rows ([],[])
  end;

(*---------------------------------------------------------------------------*
 * Goes through a list of rows and picks out the ones beginning with a       *
 * pattern with constructor = Name.                                          *
 *---------------------------------------------------------------------------*)

fun mk_group Name rows =
  let fun func (row as ((prefix, p::rst), rhs)) (in_group,not_in_group) =
            let val (pc,args) = strip_comb p
            in if ((#1(dest_const pc) = Name) handle HOL_ERR _ => false)
               then (((prefix,args@rst), rhs)::in_group, not_in_group)
               else (in_group, row::not_in_group)
            end
        | func _ _ = raise ERR "mk_group" ""
  in
    itlist func rows ([],[])
  end;


(*---------------------------------------------------------------------------*
 * Partition the rows among literals. Not efficient.                         *
 *---------------------------------------------------------------------------*)

fun partitionl _ _ (_,_,_,[]) = raise ERR"partitionl" "no rows"
  | partitionl gv ty_match
              (constructors, colty, res_ty, rows as (((prefix,_),_)::_)) =
let  fun part {constrs = [],      rows, A} = rev A
       | part {constrs = c::crst, rows, A} =
         let val (in_group, not_in_group) = mk_groupl c rows
             val in_group' =
                 if (null in_group)  (* Constructor not given *)
                 then [((prefix, []), OMITTED (mk_arb res_ty, ~1))]
                 else in_group
             val gvars = if is_var c then [c] else []
         in
         part{constrs = crst,
              rows = not_in_group,
              A = {constructor = c,
                   new_formals = gvars,
                   group = in_group'}::A}
         end
in part{constrs=constructors, rows=rows, A=[]}
end;


(*---------------------------------------------------------------------------*
 * Partition the rows. Not efficient.                                        *
 *---------------------------------------------------------------------------*)

fun partition _ _ (_,_,_,[]) = raise ERR"partition" "no rows"
  | partition gv ty_match
              (constructors, colty, res_ty, rows as (((prefix,_),_)::_)) =
let val fresh = fresh_constr ty_match colty gv
     fun part {constrs = [],      rows, A} = rev A
       | part {constrs = c::crst, rows, A} =
         let val (c',gvars) = fresh c
             val (Name,Ty) = dest_const c'
             val (in_group, not_in_group) = mk_group Name rows
             val in_group' =
                 if (null in_group)  (* Constructor not given *)
                 then [((prefix, #2(fresh c)), OMITTED (mk_arb res_ty, ~1))]
                 else in_group
         in
         part{constrs = crst,
              rows = not_in_group,
              A = {constructor = c',
                   new_formals = gvars,
                   group = in_group'}::A}
         end
in part{constrs=constructors, rows=rows, A=[]}
end;


(*---------------------------------------------------------------------------
 * Misc. routines used in mk_case
 *---------------------------------------------------------------------------*)

fun mk_patl c =
  let val L = if is_var c then 1 else 0
      fun build (prefix,tag,plist) =
          let val (args,plist') = gtake I (L, plist)
              val c' = if is_var c then hd args else c
           in (prefix,tag, c'::plist') end
  in map build
  end;

fun mk_pat c =
  let val L = length(#1(strip_fun(type_of c)))
      fun build (prefix,tag,plist) =
          let val (args,plist') = gtake I (L, plist)
           in (prefix,tag,list_mk_comb(c,args)::plist') end
  in map build
  end;

local val counter = ref 0
in
fun vary vlist =
  let val slist = ref (map (fst o dest_var) vlist)
      val _ = counter := 0
      fun pass str =
         if Lib.mem str (!slist)
         then (counter := !counter + 1; pass ("v"^int_to_string(!counter)))
         else (slist := str :: !slist; str)
  in
    fn ty => mk_var(pass "v", ty)
  end
end;

fun v_to_prefix (prefix, v::pats) = (v::prefix,pats)
  | v_to_prefix _ = raise ERR"mk_case" "v_to_prefix"

fun v_to_pats (v::prefix,tag, pats) = (prefix, tag, v::pats)
  | v_to_pats _ = raise ERR"mk_case""v_to_pats";

(* -------------------------------------------------------------- *)
(* A literal is either a numeric, string, or character literal.   *)
(* Boolean literals are handled as constructors of the bool type. *)
(* -------------------------------------------------------------- *)

val is_literal = Literal.is_literal

fun is_lit_or_var tm = is_literal tm orelse is_var tm

fun is_zero_emptystr_or_var tm =
    Literal.is_zero tm orelse Literal.is_emptystring tm orelse is_var tm

fun mk_switch_tm1 _ [] = raise ERR "mk_switch_tm" "no literals"
  | mk_switch_tm1 gv (literals as (lit::lits)) =
    let val lty = type_of lit
        val v = gv lty
        fun mk_arg lit = if is_var lit then gv (lty --> alpha) else gv alpha
        val args = map mk_arg literals
        open boolSyntax
        fun mk_switch [] = mk_const("ARB", lty)
          | mk_switch ((lit,arg)::litargs) =
                 if is_var lit then mk_comb(arg, v)
                 else boolSyntax.mk_cond(mk_eq(v, lit), arg, mk_switch litargs)
    in list_mk_abs(args@[v], mk_switch (zip literals args))
    end

fun mk_switch_tm _ [] = raise ERR "mk_switch_tm" "no literals"
  | mk_switch_tm gv (literals as (lit::lits)) =
    let val lty = type_of lit
        val v = gv lty
        fun mk_arg lit = if is_var lit then gv (lty --> alpha) else gv alpha
        val args = map mk_arg literals
        open boolSyntax
        fun mk_switch [] = mk_const("ARB", lty)
          | mk_switch ((lit,arg)::litargs) =
                 if is_var lit then mk_comb(arg, v)
                 else boolSyntax.mk_bool_case(arg, mk_switch litargs, mk_eq(v, lit))
    in list_mk_abs(args@[v], mk_switch (zip literals args))
    end

fun depth_conv conv tm =
  conv tm
  handle HOL_ERR _ =>
  if is_abs tm then let val (v,bdy) = dest_abs tm
                    in mk_abs(v, depth_conv conv bdy)
                    end
  else if is_comb tm then
    let val (tm1,tm2) = dest_comb tm
        val tm1' = depth_conv conv tm1
        val tm2' = depth_conv conv tm2
    in mk_comb(tm1', tm2')
    end
  else tm


(*----------------------------------------------------------------------------
      Translation of pattern terms into nested case expressions.

    This performs the translation and also builds the full set of patterns.
    Thus it supports the construction of induction theorems even when an
    incomplete set of patterns is given.
 ----------------------------------------------------------------------------*)

fun mk_case ty_info ty_match FV range_ty =
 let
 fun mk_case_fail s = raise ERR"mk_case" s
 val fresh_var = vary FV
 val dividel = partitionl fresh_var ty_match
 val divide = partition fresh_var ty_match
 fun expandl literals ty ((_,[]), _) = mk_case_fail"expandl_var_row"
   | expandl literals ty (row as ((prefix, p::rst), rhs)) =
       if is_var p
       then let fun expnd l =
                     ((prefix, l::rst), psubst[p |-> l] rhs)
            in map expnd literals  end
       else [row]
 fun expand constructors ty ((_,[]), _) = mk_case_fail"expand_var_row"
   | expand constructors ty (row as ((prefix, p::rst), rhs)) =
       if is_var p
       then let val fresh = fresh_constr ty_match ty fresh_var
                fun expnd (c,gvs) =
                  let val capp = list_mk_comb(c,gvs)
                  in ((prefix, capp::rst), psubst[p |-> capp] rhs)
                  end
            in map expnd (map fresh constructors)  end
       else [row]
 fun mk{rows=[],...} = mk_case_fail"no rows"
   | mk{path=[], rows = ((prefix, []), rhs)::_} =  (* Done *)
        let val (tag,tm) = dest_pattern rhs
        in ([(prefix,tag,[])], tm)
        end
   | mk{path=[], rows = _::_} = mk_case_fail"blunder"
   | mk{path as u::rstp, rows as ((prefix, []), rhs)::rst} =
        mk{path = path,
           rows = ((prefix, [fresh_var(type_of u)]), rhs)::rst}
   | mk{path = u::rstp, rows as ((_, p::_), _)::_} =
     let val (pat_rectangle,rights) = unzip rows
         val col0 = map(Lib.trye hd o #2) pat_rectangle
     in
     if all is_var col0
     then let val rights' = map(fn(v,e) => psubst[v|->u] e) (zip col0 rights)
              val pat_rectangle' = map v_to_prefix pat_rectangle
              val (pref_patl,tm) = mk{path = rstp,
                                      rows = zip pat_rectangle' rights'}
          in (map v_to_pats pref_patl, tm)
          end
     else
     if all is_lit_or_var col0 andalso
        not (all is_zero_emptystr_or_var col0)
     then let val pty = type_of p
              val {Thy=ty_thy,Tyop=ty_name,...} = dest_thy_type pty
              val other_var = fresh_var pty
              val constructors = rev (mk_set (rev (filter is_literal col0))) @ [other_var]
              val switch_tm = mk_switch_tm fresh_var constructors
                 val nrows = flatten (map (expandl constructors pty) rows)
                 val subproblems = dividel(constructors, pty, range_ty, nrows)
                 val groups        = map #group subproblems
                 and new_formals   = map #new_formals subproblems
                 and constructors' = map #constructor subproblems
                 val news = map (fn (nf,rows) => {path = nf@rstp, rows=rows})
                                (zip new_formals groups)
                 val rec_calls = map mk news
                 val (pat_rect,dtrees) = unzip rec_calls
                 val case_functions = map list_mk_abs(zip new_formals dtrees)
                 val switch_tm' = inst [alpha |-> range_ty] switch_tm
                 val tree = List.foldl (fn (a,tm) => beta_conv (mk_comb(tm,a)))
                                       switch_tm' (case_functions@[u])
                 val tree' = depth_conv beta_conv tree
                 val pat_rect1 = flatten(map2 mk_patl constructors' pat_rect)
          in
              (pat_rect1,tree')
          end
     else
     let val pty = type_of p
         val {Tyop = ty_name, Thy,...} = dest_thy_type pty
     in
     case ty_info {Thy = Thy, Tyop = ty_name}
     of NONE => mk_case_fail("Not a known datatype: "^ty_name)
      | SOME{case_const,constructors} =>
        let val {Name = case_const_name, Thy,...} = dest_thy_const case_const
            val nrows = flatten (map (expand constructors pty) rows)
            val subproblems = divide(constructors, pty, range_ty, nrows)
            val groups      = map #group subproblems
            and new_formals = map #new_formals subproblems
            and constructors' = map #constructor subproblems
            val news = map (fn (nf,rows) => {path = nf@rstp, rows=rows})
                           (zip new_formals groups)
            val rec_calls = map mk news
            val (pat_rect,dtrees) = unzip rec_calls
            val case_functions = map list_mk_abs(zip new_formals dtrees)
            val types = map type_of (case_functions@[u])
            val case_const' = mk_thy_const{Name = case_const_name,
                                           Thy = Thy,
                                           Ty = list_mk_fun(types, range_ty)}
            val tree = list_mk_comb(case_const', case_functions@[u])
            val pat_rect1 = flatten(map2 mk_pat constructors' pat_rect)
        in
            (pat_rect1,tree)
        end
     end end
 in mk
 end;


(*---------------------------------------------------------------------------
     Repeated variable occurrences in a pattern are not allowed.
 ---------------------------------------------------------------------------*)

fun FV_multiset tm =
   case dest_term tm
     of VAR v => [mk_var v]
      | CONST _ => []
      | COMB(Rator,Rand) => FV_multiset Rator @ FV_multiset Rand
      | LAMB _ => raise ERR"FV_multiset" "lambda";

fun no_repeat_vars pat =
 let fun check [] = true
       | check (v::rst) =
         if Lib.op_mem aconv v rst
         then raise ERR"no_repeat_vars"
              (concat(quote(#1(dest_var v)))
                     (concat" occurs repeatedly in the pattern "
                      (quote(Hol_pp.term_to_string pat))))
         else check rst
 in check (FV_multiset pat)
 end;


(*---------------------------------------------------------------------------
     Routines to repair the bound variable names found in cases
 ---------------------------------------------------------------------------*)

fun subst_inst (term_sub,type_sub) tm =
    Term.subst term_sub (Term.inst type_sub tm);

fun pat_match1 (pat,exp) given_pat =
 let val sub = Term.match_term pat given_pat
 in (subst_inst sub pat, subst_inst sub exp);
    sub
 end

fun pat_match2 pat_exps given_pat = tryfind (C pat_match1 given_pat) pat_exps
                                    handle HOL_ERR _ => ([],[])

fun distinguish pat_tm_mats =
    snd (List.foldr (fn ({redex,residue}, (vs,done)) =>
                         let val residue' = variant vs residue
                             val vs' = Lib.insert residue' vs
                         in (vs', {redex=redex, residue=residue'} :: done)
                         end)
                    ([],[]) pat_tm_mats)

fun reduce_mats pat_tm_mats =
    snd (List.foldl (fn (mat as {redex,residue}, (vs,done)) =>
                         if mem redex vs then (vs, done)
                         else (redex :: vs, mat :: done))
                    ([],[]) pat_tm_mats)

fun purge_wildcards term_sub = filter (fn {redex,residue} =>
        not (String.sub (fst (dest_var residue), 0) = #"_")
        handle _ => false) term_sub

fun pat_match3 pat_exps given_pats =
     ((distinguish o reduce_mats o purge_wildcards o flatten) ## flatten)
           (unzip (map (pat_match2 pat_exps) given_pats))

(* Reconstructed code from TypeBasePure, to avoid circularity. *)

fun case_const_of {case_const : term, constructors : term list} = case_const

fun constructors_of {case_const : term, constructors : term list} = constructors

fun type_names ty =
  let val {Thy,Tyop,Args} = Type.dest_thy_type ty
  in {Thy=Thy,Tyop=Tyop}
  end;

(*---------------------------------------------------------------------------*)
(* Is a constant a constructor for some datatype.                            *)
(*---------------------------------------------------------------------------*)

fun is_constructor tybase c =
  let val (_,ty) = strip_fun (type_of c)
  in case match_info tybase (type_names ty)
     of NONE => false
      | SOME tyinfo => op_mem same_const c (constructors_of tyinfo)
  end handle HOL_ERR _ => false;

(*---------------------------------------------------------------------------*)
(* Syntax operations on the (extensible) set of case expressions.            *)
(*---------------------------------------------------------------------------*)

fun mk_case' tybase (exp, plist) =
  case match_info tybase (type_names (type_of exp))
   of NONE => raise ERR "mk_case" "unable to analyze type"
    | SOME tyinfo =>
       let val c = case_const_of tyinfo
           val fns = map (fn (p,R) => list_mk_abs(snd(strip_comb p),R)) plist
           val ty' = list_mk_fun (map type_of fns@[type_of exp],
                                  type_of (snd (hd plist)))
           val theta = Type.match_type (type_of c) ty'
       in list_mk_comb(inst theta c,fns@[exp])
       end;

(*---------------------------------------------------------------------------*)
(* dest_case destructs one level of pattern matching. To deal with nested    *)
(* patterns, use strip_case.                                                 *)
(*---------------------------------------------------------------------------*)

local fun build_case_clause((ty,constr),rhs) =
 let val (args,tau) = strip_fun (type_of constr)
     fun peel  [] N = ([],N)
       | peel (_::tys) N =
           let val (v,M) = dest_abs N
               val (V,M') = peel tys M
           in (v::V,M')
           end
     val (V,rhs') = peel args rhs
     val theta = Type.match_type (type_of constr) (list_mk_fun (map type_of V, ty))
     val constr' = inst theta constr
 in
   (list_mk_comb(constr',V), rhs')
  end
in
fun dest_case tybase M =
  let val (c,args) = strip_comb M
      val (cases,arg) = front_last args
  in case match_info tybase (type_names (type_of arg))
      of NONE => raise ERR "dest_case" "unable to destruct case expression"
       | SOME tyinfo =>
          let val d = case_const_of tyinfo
          in if same_const c d
           then let val constrs = constructors_of tyinfo
                    val constrs_type = map (pair (type_of arg)) constrs
                in (c, arg, map build_case_clause (zip constrs_type cases))
                end
           else raise ERR "dest_case" "unable to destruct case expression"
          end
  end
end

fun is_case tybase M =
  let val (c,args) = strip_comb M
      val (tynames as {Tyop=tyop,...}) = type_names (type_of (last args))
  in case match_info tybase tynames
      of NONE => raise ERR "is_case" ("unknown type operator: "^Lib.quote tyop)
       | SOME tyinfo => same_const c (case_const_of tyinfo)
  end
  handle HOL_ERR _ => false;


val is_literal =  Literal.is_literal

fun is_lit_eq tm =
    if is_eq tm then
      let val (a,b) = dest_eq tm
      in is_var a andalso is_literal b
      end
    else false;

local fun dest tybase (pat,rhs) =
  let val patvars = free_vars pat
  in if is_case tybase rhs
     then let val (case_tm,exp,clauses) = dest_case tybase rhs
              val (pats,rhsides) = unzip clauses
          in if is_lit_eq exp
             then let val (v,lit) = dest_eq exp
                  in if mem v patvars
                     then flatten
                             (map (dest tybase)
                               (zip [subst [v |-> lit] pat, pat] rhsides))
                     else [(pat,rhs)]
                  end
             else if mem exp patvars andalso
                     null_intersection [exp] (free_varsl rhsides)
             then flatten
                     (map (dest tybase)
                       (zip (map (fn p => subst [exp |-> p] pat) pats) rhsides))
             else [(pat,rhs)]
          end
     else [(pat,rhs)]
  end
in
fun strip_case tybase M =
  case total (dest_case tybase) M
   of NONE => (M,[])
    | SOME(case_tm,exp,cases) =>
         if is_lit_eq exp
         then let val (v,lit) = dest_eq exp
              in (v, flatten (map (dest tybase)
                               (zip [lit, v] (map snd cases))))
              end
         else (exp, flatten (map (dest tybase) cases))
end;


fun rename_case thy sub cs =
 if not (is_case thy cs) then subst_inst sub cs
 else
   let val (cnst,arg,pat_exps) = dest_case thy cs
       val pat_exps' = map (fn (pat,exp) =>
                            (rename_case thy sub pat,
                             rename_case thy sub exp))
                       pat_exps
       val arg' = rename_case thy sub arg
       val cs' = mk_case' thy (arg', pat_exps')
   in cs'
   end

(* Test:

``(checkPrefix : 'a list # 'a list -> 'a list option)
     ((subl :'a list),(supl :'a list)) =
   case (subl,supl) of
      (([] :'a list),(v3 :'a list)) -> SOME supl
   || ((subhd :'a)::(subtl :'a list),([] :'a list)) ->
        (NONE :'a list option)
   || (subhd::subtl,(suphd :'a)::(suptl :'a list)) ->
        (if subhd = suphd then
           checkPrefix (subtl,suptl)
         else
           (NONE :'a list option))``;

val thy = fn (ty as {Thy : string, Tyop : string}) =>
          case TypeBase.read ty of
            SOME tyi => SOME
             {constructors = TypeBasePure.constructors_of tyi,
              case_const   = TypeBasePure.case_const_of tyi}
          | NONE     => NONE;

val eqs = ``(checkPrefix (([]:'a list),(supl :'a list)) = SOME supl) /\
            (checkPrefix (subhd::subtl, ([]:'a list)) = NONE) /\
            (checkPrefix (subhd::subtl,suphd::suptl) =
                if subhd = suphd then checkPrefix (subtl,suptl)
                                 else NONE)``;

Pmatch.mk_functional thy eqs;

*)


local fun paired1{lhs,rhs} = (lhs,rhs)
      and paired2{Rator,Rand} = (Rator,Rand)
      fun err s = raise ERR "mk_functional" s
      fun msg s = HOL_MESG ("mk_functional: "^s)
in
fun mk_functional thy eqs =
 let val clauses = strip_conj eqs
     val (L,R) = unzip (map (dest_eq o snd o strip_forall) clauses)
     val (funcs,pats) = unzip(map dest_comb L)
     val fs = Lib.op_mk_set aconv funcs
     val f0 = if length fs = 1 then hd fs else err "function name not unique"
     val f  = if is_var f0 then f0 else mk_var(dest_const f0)
     val _  = map no_repeat_vars pats
     val rows = zip (map (fn x => ([],[x])) pats) (map GIVEN (enumerate R))
     val fvs = free_varsl R
     val a = variant fvs (mk_var("a", type_of(Lib.trye hd pats)))
     val FV = a::fvs
     val range_ty = type_of (Lib.trye hd R)
     val (patts, case_tm) = mk_case (match_info thy) (match_type thy)
                                     FV range_ty {path=[a], rows=rows}
     fun func (_,(tag,i),[pat]) = tag (pat,i)
       | func _ = err "error in pattern-match translation"
     val patts1 = map func patts
     val patts2 = sort(fn p1=>fn p2=> row_of_pat p1 < row_of_pat p2) patts1
     val finals = map row_of_pat patts2
     val originals = map (row_of_pat o #2) rows
     fun int_eq i1 (i2:int) =  (i1=i2)
     val inaccessibles = gather(fn x => not(op_mem int_eq x finals)) originals
     fun accessible p = not(op_mem int_eq (row_of_pat p) inaccessibles)
     val patts3 = (case inaccessibles of [] => patts2
                        |  _ => filter accessible patts2)
     val _ = case inaccessibles of [] => ()
             | _ => msg("The following input rows (counting from zero) are\
       \ inaccessible: "^stringize inaccessibles^".\nThey have been ignored.")
     (* The next lines repair bound variable names in the nested case term. *)
     val (a',case_tm') =
         let val (_,pat_exps) = strip_case thy case_tm
             val sub = pat_match3 pat_exps pats (* better pats than givens patts3 *)
         in (subst_inst sub a, rename_case thy sub case_tm)
         end handle HOL_ERR _ => (a,case_tm)
 in
   {functional = list_mk_abs ([f,a'], case_tm'),
    pats = patts3}
 end
end;

end;
