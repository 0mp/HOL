structure Overload :> Overload =
struct

open HolKernel Lexis
infix ##

(* invariant on the type overloaded_op_info;
     base_type is the anti-unification of all the types in the actual_ops
     list
   invariant on the overload_info list:
     all members of the list have non-empty actual_ops lists
*)

type const_rec = {Name : string, Ty : hol_type, Thy : string}
type nthy_rec = {Name : string, Thy : string}

fun lose_constrec_ty {Name,Ty,Thy} = {Name = Name, Thy = Thy}

(* though const_rec's are stored, the Ty component is there just to
   tell us what the generic type of a term is, it will never be a
   specialisation of a polymorphic type *)

type overloaded_op_info =
  {base_type : Type.hol_type,
   actual_ops : const_rec list}

(* the overload info is thus a pair:
   * first component is for the "parsing direction"; it's a map from
     identifier name to an overloaded_op_info record.
   * second component is for the "printing direction"; it takes constant
     specifications {Name,Thy} records, and returns the preferred
     identifier. If no entry exists, the constant should be printed in
     thy$constant name form.
*)



type overload_info = ((string,overloaded_op_info) Binarymap.dict *
                      ({Name:string,Thy:string} * string) list)

val null_oinfo = (Binarymap.mkDict String.compare, [])

fun oinfo_ops (oi,_) = Binarymap.listItems oi
fun print_map (_, pm) = pm

fun update_assoc k v [] = [(k,v)]
  | update_assoc k v ((k',v')::kvs) = if k = k' then (k,v)::kvs
                                      else (k',v')::update_assoc k v kvs

exception OVERLOAD_ERR of string

local
  open stmonad Lib Type
  infix >- >>
  fun lookup n (env,avds) =
    case assoc1 n env of
      NONE => ((env,avds), NONE)
    | SOME (_,v) => ((env,avds), SOME v)
  fun extend x (env,avds) = ((x::env,avds), ())
  (* invariant on type generation part of state:
       not (next_var MEM sofar)
  *)
  fun newtyvar (env, (next_var, sofar)) = let
    val new_sofar = next_var::sofar
    val new_next = gen_variant tyvar_vary sofar (tyvar_vary next_var)
    (* new_next can't be in new_sofar because gen_variant ensures that
       it won't be in sofar, and tyvar_vary ensures it won't be equal to
       next_var *)
  in
    ((env, (new_next, new_sofar)), mk_vartype next_var)
  end

  fun au (ty1, ty2) =
    if ty1 = ty2 then return ty1
    else
      lookup (ty1, ty2) >-
      (fn result =>
       case result of
         NONE =>
           if not (is_vartype ty1) andalso not (is_vartype ty2) then let
             val (tyop1,args1) = dest_type ty1
             val (tyop2,args2) = dest_type ty2
           in
             if tyop1 = tyop2 then
               mmap au (ListPair.zip (args1, args2)) >-
               (fn tylist => return (mk_type(tyop1, tylist)))
             else
               newtyvar >- (fn new_ty =>
                            extend ((ty1, ty2), new_ty) >>
                            return new_ty)
           end
           else
             newtyvar >- (fn new_ty =>
                          extend ((ty1, ty2), new_ty) >>
                          return new_ty)
        | SOME v => return v)

  fun initial_state (ty1, ty2) = let
    val avoids = map dest_vartype (type_varsl [ty1, ty2])
    val first_var = gen_variant tyvar_vary avoids "'a"
  in
    ([], (first_var, avoids))
  end
  fun generate_iterates n f x =
    if n <= 0 then []
    else x::generate_iterates (n - 1) f (f x)

  fun canonicalise ty = let
    val tyvars = type_vars ty
    val replacements =
      map mk_vartype (generate_iterates (length tyvars) tyvar_vary "'a")
    val subst =
      ListPair.map (fn (ty1, ty2) => Lib.|->(ty1, ty2)) (tyvars, replacements)
  in
    type_subst subst ty
  end
in
  fun anti_unify ty1 ty2 = let
    val (_, result) = au (ty1, ty2) (initial_state (ty1, ty2))
  in
    canonicalise result
  end
end

(* find anti-unification for list of types *)
fun aul tyl =
    case tyl of
      [] => raise Fail "Overload.aul applied to empty list - shouldn't happen"
    | (h::t) => foldl (uncurry anti_unify) h t

fun fupd_actual_ops f {base_type, actual_ops} =
  {base_type = base_type, actual_ops = f actual_ops}

fun fupd_base_type f {base_type, actual_ops} =
  {base_type = f base_type, actual_ops = actual_ops}

fun fupd_dict_at_key k f dict = let
  val (newdict, kitem) = Binarymap.remove(dict,k)
in
  Binarymap.insert(newdict,k,f kitem)
end

fun info_for_name (overloads:overload_info) s =
  Binarymap.peek (#1 overloads, s)
fun is_overloaded (overloads:overload_info) s =
  isSome (info_for_name overloads s)

fun type_compare (ty1, ty2) = let
  val ty1_gte_ty2 = Lib.can (Type.match_type ty1) ty2
  val ty2_gte_ty1 = Lib.can (Type.match_type ty2) ty1
in
  case (ty1_gte_ty2, ty2_gte_ty1) of
    (true, true) => SOME EQUAL
  | (true, false) => SOME GREATER
  | (false, true) => SOME LESS
  | (false, false) => NONE
end

fun remove_overloaded_form s (oinfo:overload_info) = let
  val (op2cnst, cnst2op) = oinfo
  val (okopc, badopc) =
    (I ## map lose_constrec_ty o #actual_ops) (Binarymap.remove(op2cnst, s))
    handle Binarymap.NotFound => (op2cnst, [])
  (* will keep okopc, but should now remove from cnst2op all pairs of the form
       (c, s)
     where s is the s above *)
  val (okcop, badcop) = List.partition (fn (c,s') => s' <> s) cnst2op
in
  ((okopc, okcop), (badopc, map #1 badcop))
end

fun raw_map_insert s (new_op2cs, new_c2ops) (op2c_map, c2op_map) = let
  fun install_ty (r as {Name,Thy}) =
    {Name = Name, Thy = Thy, Ty = type_of (Term.prim_mk_const r)}
    handle HOL_ERR _ =>
      raise OVERLOAD_ERR ("No such constant: "^Thy^"$"^Name)
  val withtypes = map install_ty new_op2cs
  val new_c2op_map =
    foldl (fn (crec,ass) => update_assoc crec s ass) c2op_map new_c2ops
in
  case withtypes of
    [] => (op2c_map, new_c2op_map)
  | (r::rs) => let
      val au = foldl (fn (r1, t) => anti_unify (#Ty r1) t) (#Ty r) rs
    in
      (Binarymap.insert(op2c_map, s, {base_type = au, actual_ops = withtypes}),
       new_c2op_map)
    end
end

(* a predicate on pairs of operations and types that returns true if
   they're equal, given that two types are equal if they can match
   each other *)
fun ntys_equal {Ty = ty1,Name = n1, Thy = thy1}
               {Ty = ty2, Name = n2, Thy = thy2} =
  type_compare (ty1, ty2) = SOME EQUAL andalso n1 = n2 andalso thy1 = thy2


(* put a new overloading resolution into the database.  If it's already
   there for a given operator, don't mind.  In either case, make sure that
   it's at the head of the list, meaning that it will be the first choice
   in ambigous resolutions. *)
fun add_actual_overloading {opname, realname, realthy} oinfo = let
  val nthy_rec = {Name = realname, Thy = realthy}
  val cnst = prim_mk_const{Name = realname, Thy = realthy}
    handle HOL_ERR _ =>
      raise OVERLOAD_ERR ("No such constant: "^realthy^"$"^realname)
  val newrec = dest_thy_const cnst
  val (opc0, cop0) = oinfo
  val opc =
      case info_for_name oinfo opname of
        SOME {base_type, actual_ops} => let
          (* this name is already overloaded *)
          fun eq_nthy aop = #Name aop = realname andalso #Thy aop = realthy
        in
          case Lib.total (Lib.pluck eq_nthy) actual_ops of
            SOME (_, rest) => let
              (* a constant of same nthy pair was already in the map *)
              (* must replace it *)
              val newbase =
                  foldl (fn (r, ty) => anti_unify (#Ty r) ty) (#Ty newrec) rest
            in
              Binarymap.insert(opc0, opname,
                               {actual_ops = newrec::rest,
                                base_type = newbase})
            end
          | NONE => let
              (* no constant of this name in the map, so can just cons its *)
              (* record in *)
              val newbase = anti_unify base_type (#Ty newrec)
            in
              fupd_dict_at_key
                opname
                (fupd_actual_ops (cons newrec) o
                 fupd_base_type (fn b => newbase))
                opc0
            end
        end
      | NONE =>
        (* this name not overloaded at all *)
        Binarymap.insert(opc0, opname,
                         {actual_ops = [newrec], base_type = #Ty newrec})
  val cop = update_assoc nthy_rec opname cop0
in
  (opc, cop)
end


fun myfind f [] = NONE
  | myfind f (x::xs) = case f x of (v as SOME _) => v | NONE => myfind f xs

fun overloading_of_term (oinfo:overload_info) t =
  if not (Term.is_const t) then NONE
  else
    Option.map #2
    (Lib.assoc1 (lose_constrec_ty (Term.dest_thy_const t)) (#2 oinfo))

fun overloading_of_nametype (oinfo:overload_info) r =
  Option.map #2 (Lib.assoc1 r (#2 oinfo))

fun rev_append [] rest = rest
  | rev_append (x::xs) rest = rev_append xs (x::rest)

fun compare_crec ({Name = n1, Thy = thy1},
                  {Name = n2, Thy = thy2}) =
  case String.compare(thy1, thy2) of
    EQUAL => String.compare (n1, n2)
  | x => x

val show_alias_resolution = ref true
val _ = Feedback.register_btrace ("show_alias_printing_choices",
                                  show_alias_resolution)

fun merge_oinfos (O1:overload_info) (O2:overload_info) = let
  val O1ops_sorted = Binarymap.listItems (#1 O1)
  val O2ops_sorted = Binarymap.listItems (#1 O2)
  fun merge acc op1s op2s =
    case (op1s, op2s) of
      ([], x) => rev_append acc x
    | (x, []) => rev_append acc x
    | ((k1,op1)::op1s', (k2,op2)::op2s') => let
      in
        case String.compare (k1, k2) of
          LESS => merge ((k1,op1)::acc) op1s' op2s
        | EQUAL => let
            val name = k1
            val ty1 = #base_type op1
            val ty2 = #base_type op2
            val newty = anti_unify ty1 ty2
            val newopinfo =
              (name,
               {base_type = newty,
                actual_ops =
                Lib.op_union ntys_equal (#actual_ops op1) (#actual_ops op2)})
          in
            merge (newopinfo::acc) op1s' op2s'
          end
        | GREATER => merge ((k2, op2)::acc) op1s op2s'
      end
    infix ##
    val O1cops_sorted = Listsort.sort (compare_crec o (#1 ## #1)) (#2 O1)
    val O2cops_sorted = Listsort.sort (compare_crec o (#1 ## #1)) (#2 O2)
    fun merge_cops acc cop1s cop2s =
      case (cop1s, cop2s) of
        ([], x) => rev_append acc x
      | (x, []) => rev_append acc x
      | (r1::r1s, r2::r2s) => let
        in
          case compare_crec(#1 r1, #1 r2) of
            LESS => merge_cops (r1::acc) r1s cop2s
          | GREATER => merge_cops (r2::acc) cop1s r2s
          | EQUAL => let
            in
              if #2 r1 <> #2 r2 andalso !show_alias_resolution andalso
                 !Globals.interactive
              then
                HOL_MESG ("Constant " ^ #Thy (#1 r1) ^ "$" ^ #Name (#1 r1) ^
                          " now prints as " ^ quote(#2 r2))
              else ();
              merge_cops (r1::acc) r1s r2s
            end
        end
in
  (List.foldr (fn ((k,v),dict) => Binarymap.insert(dict,k,v))
   (Binarymap.mkDict String.compare)
   (merge [] O1ops_sorted O2ops_sorted),
   merge_cops [] O1cops_sorted O2cops_sorted)
end

fun keys dict = Binarymap.foldr (fn (k,v,l) => k::l) [] dict

fun known_constants (oi:overload_info) = keys (#1 oi)

fun remove_omapping crec str opdict = let
  val (dictlessk, kitem) = Binarymap.remove(opdict, str)
  fun ok_actual oprec = lose_constrec_ty oprec <> crec
  val new_rec = fupd_actual_ops (List.filter ok_actual) kitem
in
  if (null (#actual_ops new_rec)) then dictlessk
  else Binarymap.insert(dictlessk, str, new_rec)
end handle Binarymap.NotFound => opdict


fun remove_mapping str crec (oi:overload_info) =
  (remove_omapping crec str (#1 oi),
   List.filter (fn (r,str') => r <> crec orelse str <> str') (#2 oi))


end (* Overload *)
