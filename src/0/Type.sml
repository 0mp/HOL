(* ===================================================================== *)
(* FILE          : Type.sml                                              *)
(* DESCRIPTION   : HOL types.                                            *)
(*                                                                       *)
(* AUTHOR        : (c) Konrad Slind, University of Calgary               *)
(* DATE          : August 26, 1991                                       *)
(* UPDATE        : October 94. Type signature implementation moved from  *)
(*                 symtab.sml, which is now gone.                        *)
(* Modified      : September 22, 1997, Ken Larsen  (functor removal)     *)
(*                 April 12, 1998, Konrad Slind                          *)
(*                 July, 2000, Konrad Slind                              *)
(* ===================================================================== *)

structure Type : RawType =
struct

open Feedback Lib KernelTypes;   infix |->;

type hol_type = KernelTypes.hol_type;

val ERR = mk_HOL_ERR "Type";
val WARN = HOL_WARNING "Type";


(*---------------------------------------------------------------------------
              Create the signature for HOL types
 ---------------------------------------------------------------------------*)

structure TypeSig = 
  SIG(type ty = KernelTypes.tyconst
      fun key (r,_) = r
      val ERR = ERR
      val table_size = 311) 


(*---------------------------------------------------------------------------*
 * Builtin type operators (fun, bool, ind). These are in every HOL           *
 * signature, and it is convenient to nail them down here.                   *
 *---------------------------------------------------------------------------*)

local open TypeSig
in
val INITIAL{const=fun_tyc,...}  = insert (mk_id("fun",  "min"), 2);
val INITIAL{const=bool_tyc,...} = insert (mk_id("bool", "min"), 0);
val INITIAL{const=ind_tyc,...}  = insert (mk_id("ind",  "min"), 0);
end

infixr 3 -->;
fun (X --> Y) = Tyapp (fun_tyc,  [X,Y]);
val bool      = Tyapp (bool_tyc, []);
val ind       = Tyapp (ind_tyc,  []);


(*---------------------------------------------------------------------------*
 * Create a compound type, in a specific segment, and in the current theory. *
 *---------------------------------------------------------------------------*)

fun make_type (tyc as (_,arity)) Args (fnstr,name) = 
  if arity = length Args then Tyapp(tyc,Args) else 
  raise ERR fnstr (String.concat 
      [name," needs ", int_to_string arity, 
       " arguments, but was given ", int_to_string(length Args)]);

fun mk_thy_type {Thy,Tyop,Args} = 
 case TypeSig.lookup (Tyop,Thy) 
  of SOME{const,...} => make_type const Args ("mk_thy_type",fullname(Tyop,Thy))
   | NONE => raise ERR "mk_thy_type"
                 (Tyop^" has not been declared in theory "^quote Thy^".")

local fun dest e = 
        let val (c,_) = #const e
        in {Tyop=KernelTypes.name_of c, Thy=KernelTypes.seg_of c}
        end
in 
val decls = map dest o TypeSig.resolve
end;

fun first_decl fname Tyop =
 case TypeSig.resolve Tyop
  of []            => raise ERR fname (Lib.quote Tyop^" has not been declared")
   | [{const,...}]  => const
   | {const,...}::_ => (WARN fname "more than one possibility"; const)

fun mk_type (Tyop,Args) =
  make_type (first_decl "mk_type" Tyop) Args ("mk_type",Tyop);

(* currently unused *)
fun current_tyops s = 
  map (fn {const as (id,i),...} => (KernelTypes.dest_id id,i)) 
      (TypeSig.resolve s);

(*---------------------------------------------------------------------------*
 * Take a type apart.                                                        *
 *---------------------------------------------------------------------------*)

local open KernelTypes
in
fun break_type (Tyapp p) = p | break_type _ = raise ERR "break_type" "";

fun dest_thy_type (Tyapp((tyc,_),A)) = {Thy=seg_of tyc,Tyop=name_of tyc,Args=A}
  | dest_thy_type _ = raise ERR "dest_thy_type" "";

fun dest_type (Tyapp((tyc,_),A)) = (name_of tyc, A)
  | dest_type _ = raise ERR "dest_type" ""
end;

(*---------------------------------------------------------------------------*
 *          Invert -->                                                       *
 *---------------------------------------------------------------------------*)

fun dom_rng ty =
    case dest_thy_type ty
     of {Thy="min", Tyop="fun", Args=[x,y]} => (x,y)
      | _ => raise ERR "dom_rng" "not a function type";


(*---------------------------------------------------------------------------
       Declared types in a theory segment
 ---------------------------------------------------------------------------*)

fun thy_types s = 
  let fun xlate {const=(id,arity), ...} = (KernelTypes.name_of id, arity)
  in map xlate (TypeSig.slice s)
  end;


(*---------------------------------------------------------------------------*
 *         Type variables                                                    *
 *---------------------------------------------------------------------------*)

val alpha = Tyv "'a"
val beta  = Tyv "'b";
val gamma = Tyv "'c"
val delta = Tyv "'d"
val evar  = Tyv "'e"
val fvar =  Tyv "'f"

fun mk_vartype "'a" = alpha  | mk_vartype "'b" = beta
  | mk_vartype "'c" = gamma  | mk_vartype "'d" = delta
  | mk_vartype "'e" = evar   | mk_vartype "'f" = fvar
  | mk_vartype s = if Lexis.allowed_user_type_var s then Tyv s
                   else raise ERR "mk_vartype" "incorrect syntax"

fun dest_vartype (Tyv s) = s
  | dest_vartype _ = raise ERR "dest_vartype" "not a type variable";

fun is_vartype (Tyv _) = true | is_vartype _ = false;
val is_type = not o is_vartype;

(*---------------------------------------------------------------------------*
 * The variables in a type.                                                  *
 *---------------------------------------------------------------------------*)

local fun tyvars (Tyapp(_,Args)) vlist = tyvarsl Args vlist
        | tyvars v vlist = Lib.insert v vlist
      and tyvarsl L vlist = rev_itlist tyvars L vlist
in
fun type_vars ty = rev(tyvars ty [])
fun type_varsl L = rev(tyvarsl L [])
end;


(*---------------------------------------------------------------------------
     Does a type variable occur in a type
 ---------------------------------------------------------------------------*)

fun type_var_in v =
 if is_vartype v
 then let fun occ (Tyapp(_,Args)) = Lib.exists occ Args
            | occ w = (v=w)
      in occ end
 else raise ERR "type_var_occurs" "not a type variable";

(*---------------------------------------------------------------------------
    Does there exist a type variable v in a type such that P(v) holds.
    Returns false if there are no type variables in the type. 
 ---------------------------------------------------------------------------*)

fun exists_tyvar P =
 let fun occ (w as Tyv _) = P w
       | occ (Tyapp(_,Args)) = Lib.exists occ Args
 in occ end;

(*---------------------------------------------------------------------------*
 * Substitute in a type, trying to preserve existing structure.              *
 *---------------------------------------------------------------------------*)

fun ty_sub [] _ = SAME
  | ty_sub theta (Tyapp(tyc,Args)) 
      = (case delta_map (ty_sub theta) Args
          of SAME => SAME
           | DIFF Args' => DIFF (Tyapp(tyc, Args')))
  | ty_sub theta v =
      case Lib.subst_assoc (equal v) theta
       of NONE    => SAME
        | SOME ty => DIFF ty

fun type_subst theta = delta_apply (ty_sub theta);


(*---------------------------------------------------------------------------*
 * Is a type polymorphic?                                                    *
 *---------------------------------------------------------------------------*)

fun polymorphic (Tyv _) = true
  | polymorphic (Tyapp(_,Args)) = exists polymorphic Args


(*---------------------------------------------------------------------------
         This matching algorithm keeps track of identity bindings 
         v |-> v in a separate area. This eliminates the need for
         post-match normalization of substitutions coming from the
         matching algorithm, as was done in earlier implementations.
 ---------------------------------------------------------------------------*)

local 
  fun lookup x ids =
   let fun look [] = if Lib.mem x ids then SOME x else NONE
         | look ({redex,residue}::t) = if x=redex then SOME residue else look t
   in look end
in
fun tymatch (v as Tyv _) ty (p as (S,ids)) =
      (case lookup v ids S
        of NONE     => if v=ty then (S,v::ids) else ((v |-> ty)::S,ids)
         | SOME ty1 => if ty1=ty then p else raise ERR "tymatch" "")
  | tymatch (Tyapp(c1,A1)) (Tyapp(c2,A2)) B =
      if c1=c2 then rev_itlist2 tymatch A1 A2 B else raise ERR "tymatch" ""
  | tymatch _  _  _ = raise ERR "tymatch" ""

fun match_type pat ob = fst(tymatch pat ob ([],[]))
end;


(*---------------------------------------------------------------------------
        An order on types
 ---------------------------------------------------------------------------*)

fun compare (Tyv s1, Tyv s2) = String.compare (s1,s2)
  | compare (Tyv _, _) = LESS
  | compare (Tyapp _, Tyv _) = GREATER
  | compare (Tyapp((c1,_),A1), Tyapp((c2,_),A2)) = 
      case KernelTypes.compare (c1, c2)
       of EQUAL => Lib.list_compare compare (A1,A2)
        |   x   => x;



(*---------------------------------------------------------------------------
     Automatically generated type variables. The goofy names make
     it unlikely that the names will clash with user-created
     type variables.
 ---------------------------------------------------------------------------*)

local val gen_tyvar_prefix = "%%gen_tyvar%%"
      fun num2name i = gen_tyvar_prefix^Lib.int_to_string i
      val nameStrm   = Lib.mk_istream (fn x => x+1) 0 num2name
in
fun gen_tyvar () = Tyv(state(next nameStrm))

fun is_gen_tyvar (Tyv name) = String.isPrefix gen_tyvar_prefix name
  | is_gen_tyvar _ = false;
end;


end; (* Type *)
