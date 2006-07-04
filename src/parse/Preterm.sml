structure Preterm :> Preterm =
struct

open Feedback Lib GrammarSpecials;

val ERR = mk_HOL_ERR "Preterm"
val ERRloc = mk_HOL_ERRloc "Preterm"

type pretype = Pretype.pretype
type hol_type = Type.hol_type
type term = Term.term
type overinfo = {Name:string, Ty:pretype,
                 Info:Overload.overloaded_op_info, Locn:locn.locn}

datatype preterm = Var   of {Name:string,  Ty:pretype, Locn:locn.locn}
                 | Const of {Name:string,  Thy:string, Ty:pretype, Locn:locn.locn}
                 | Overloaded of overinfo
                 | Comb  of {Rator:preterm, Rand:preterm, Locn:locn.locn}
                 | Abs   of {Bvar:preterm, Body:preterm, Locn:locn.locn}
                 | Constrained of {Ptm:preterm, Ty:pretype, Locn:locn.locn}
                 | Antiq of {Tm:Term.term, Locn:locn.locn}
              (* | HackHack of bool -> bool *)
              (* Because of the Locn fields, preterms should *not* be compared
                 with the built-in equality, but should use eq defined below.
                 To check this has been done everywhere, uncomment this constructor. *)

(*---------------------------------------------------------------------------
     Read the location from a preterm.
 ---------------------------------------------------------------------------*)

fun locn (Var{Locn,...})         = Locn
  | locn (Const{Locn,...})       = Locn
  | locn (Overloaded{Locn,...})  = Locn
  | locn (Comb{Locn,...})        = Locn
  | locn (Abs{Locn,...})         = Locn
  | locn (Constrained{Locn,...}) = Locn
  | locn (Antiq{Locn,...})       = Locn

(*---------------------------------------------------------------------------
     Location-ignoring equality for preterms.
 ---------------------------------------------------------------------------*)

fun eq (Var{Name=Name,Ty=Ty,...})                  (Var{Name=Name',Ty=Ty',...})                   = Name=Name' andalso Ty=Ty'
  | eq (Const{Name=Name,Thy=Thy,Ty=Ty,...})        (Const{Name=Name',Thy=Thy',Ty=Ty',...})        = Name=Name' andalso Thy=Thy' andalso Ty=Ty'
  | eq (Overloaded{Name=Name,Ty=Ty,Info=Info,...}) (Overloaded{Name=Name',Ty=Ty',Info=Info',...}) = Name=Name' andalso Ty=Ty' andalso Info=Info'
  | eq (Comb{Rator=Rator,Rand=Rand,...})           (Comb{Rator=Rator',Rand=Rand',...})            = eq Rator Rator' andalso eq Rand Rand'
  | eq (Abs{Bvar=Bvar,Body=Body,...})              (Abs{Bvar=Bvar',Body=Body',...})               = eq Bvar Bvar' andalso eq Body Body'
  | eq (Constrained{Ptm=Ptm,Ty=Ty,...})            (Constrained{Ptm=Ptm',Ty=Ty',...})             = eq Ptm Ptm' andalso Ty=Ty'
  | eq (Antiq{Tm=Tm,...})                          (Antiq{Tm=Tm',...})                            = Tm=Tm'
  | eq  _                                           _                                             = false

(*---------------------------------------------------------------------------
     Simple map from a preterm to a term. The argument "shr" maps from
     pretypes to types. Should Overloaded nodes be translated, or
     should the process fail if one is encountered? Currently, we
     attempt to make some sort of constant (non-deterministic), but we
     could just as well fail, since Overloaded nodes should be gone
     by the time clean is called.

     shr takes a location for now, until Preterm has a location built-in.
 ---------------------------------------------------------------------------*)

fun clean shr =
 let fun
   cl(Var{Name,Ty,Locn})            = Term.mk_var(Name, shr Locn Ty)
 | cl(Const{Name,Thy,Ty,Locn})      = Term.mk_thy_const{Name=Name,Thy=Thy,Ty=shr Locn Ty}
 | cl(Comb{Rator,Rand,...})         = Term.mk_comb(cl Rator,cl Rand)
 | cl(Abs{Bvar,Body,...})           = Term.mk_abs(cl Bvar, cl Body)
 | cl(Antiq{Tm,...})                = Tm
 | cl(Constrained{Ptm,...})         = cl Ptm
 | cl(Overloaded{Name,Ty,Locn,...}) = Term.mk_const(Name, shr Locn Ty)
 in cl
 end;

local open Pretype
in
fun has_free_uvar (Tyop{Args,...})    = List.exists has_free_uvar Args
  | has_free_uvar (UVar(ref(SOME t))) = has_free_uvar t
  | has_free_uvar (UVar(ref NONE))    = true
  | has_free_uvar (Vartype _)         = false
end

fun tyVars ptm =  (* the pretype variables in a preterm *)
  case ptm of
    Var{Ty,...}             => Pretype.tyvars Ty
  | Const{Ty,...}           => Pretype.tyvars Ty
  | Comb{Rator,Rand,...}    => Lib.union (tyVars Rator) (tyVars Rand)
  | Abs{Bvar,Body,...}      => Lib.union (tyVars Bvar) (tyVars Body)
  | Antiq{Tm,...}           => map Type.dest_vartype (Term.type_vars_in_term Tm)
  | Constrained{Ptm,Ty,...} => Lib.union (tyVars Ptm) (Pretype.tyvars Ty)
  | Overloaded _            => raise Fail "Preterm.tyVars: applied to Overloaded"


(*---------------------------------------------------------------------------
    Translate a preterm to a term. Will "guess type variables"
    (assign names to type variables created during type inference),
    if a flag is set. No "Overloaded" nodes are allowed in the preterm:
    overloading resolution should already have gotten rid of them.
 ---------------------------------------------------------------------------*)

val _ =
    register_btrace ("notify type variable guesses",
                     Globals.notify_on_tyvar_guess)

fun to_term tm =
    if !Globals.guessing_tyvars then let
        fun cleanup tm = let
          open optmonad
          infix >> >-
          val clean = Pretype.clean o Pretype.remove_made_links
        in
          case tm of
            Var{Name,Ty,...} => Pretype.replace_null_links Ty >- (fn _ =>
                                return (Term.mk_var(Name, clean Ty)))
          | Const{Name,Thy,Ty,...} =>
                Pretype.replace_null_links Ty >- (fn _ =>
                return (Term.mk_thy_const{Name=Name, Thy=Thy, Ty=clean Ty}))
          | Comb{Rator, Rand,...} => cleanup Rator >- (fn Rator'
                                  => cleanup Rand  >- (fn Rand'
                                  => return (Term.mk_comb(Rator', Rand'))))
          | Abs{Bvar, Body,...} => cleanup Bvar >- (fn Bvar'
                                => cleanup Body >- (fn Body'
                                => return (Term.mk_abs(Bvar', Body'))))
          | Antiq{Tm,...} => return Tm
          | Constrained{Ptm,...} => cleanup Ptm
          | Overloaded _ => raise ERRloc "to_term" (locn tm)
                                         "applied to Overloaded"
        end
        val V = tyVars tm
        val (newV, result) = cleanup tm V
        val guessed_vars = List.take(newV, length newV - length V)
        val _ =
            if not (null guessed_vars) andalso !Globals.notify_on_tyvar_guess
               andalso !Globals.interactive
            then Feedback.HOL_MESG (String.concat
                                      ("inventing new type variable names: "
                                       :: Lib.commafy (List.rev guessed_vars)))
            else ()
      in
        valOf result
      end
    else let
        fun shr l ty =
            if has_free_uvar ty then
              raise ERRloc "typecheck.to_term" l
                           "Unconstrained type variable (and Globals.\
                           \guessing_tyvars is false)"
            else Pretype.clean (Pretype.remove_made_links ty)
      in
        clean shr tm
      end




(*---------------------------------------------------------------------------*
 *                                                                           *
 * Overloading removal.  Th function "remove_overloading_phase1" will        *
 * replace Overloaded _ nodes with Consts where it can be shown that only    *
 * one of the possible constants has a type compatible with the type of the  *
 * term as it has been inferred during the previous phase of type inference. *
 * This may in turn constrain other overloaded terms elsewhere in the tree.  *
 *                                                                           *
 *---------------------------------------------------------------------------*)

exception phase1_exn of locn.locn * string * hol_type
fun remove_overloading_phase1 ptm =
  case ptm of
    Comb{Rator, Rand, Locn} => Comb{Rator = remove_overloading_phase1 Rator,
                                    Rand = remove_overloading_phase1 Rand, Locn = Locn}
  | Abs{Bvar, Body, Locn} => Abs{Bvar = remove_overloading_phase1 Bvar,
                                 Body = remove_overloading_phase1 Body, Locn = Locn}
  | Constrained{Ptm, Ty, Locn} => Constrained{Ptm = remove_overloading_phase1 Ptm, Ty = Ty, Locn = Locn}
  | Overloaded{Name,Ty,Info,Locn} =>
     let fun testfn possty =
           let val pty0 = Pretype.fromType possty
               val pty = Pretype.rename_typevars pty0
           in Pretype.can_unify Ty pty
           end
         val possible_ops =
           List.filter (testfn o #Ty) (#actual_ops Info)
     in
      case possible_ops of
        [] =>
        raise phase1_exn(Locn, "No possible type for overloaded constant "^Name^"\n",
                         Pretype.toType Ty)
      | [{Ty = ty,Name,Thy}] => let
          val pty = Pretype.rename_typevars (Pretype.fromType ty)
          val _ = Pretype.unify pty Ty
        in
          Const{Name=Name, Thy=Thy, Ty=pty, Locn=Locn (*??*) }
        end
      | _ =>
        Overloaded{Name=Name, Ty=Ty,
                   Info=Overload.fupd_actual_ops (fn _ => possible_ops) Info,
                   Locn=Locn}
     end
  | _ => ptm;


fun remove_overloading ptm = let
  open seqmonad
  infix >- >> ++
  fun opt2seq m env =
    case m env of
      (env', NONE) => seq.empty
    | (env', SOME result) => seq.result (env', result)
  fun unify t1 t2 = opt2seq (Pretype.safe_unify t1 t2)
  (* Note that the order of the term traversal here is very important as
     the sub-terms "pulled out" will be "put back in" later under the
     assumption that the list is in the right order.  The traversal that
     puts the constants into the place of the Overloaded nodes must also
     traverse in the same order:
       Rator before Rand, Bvar before Body
     In accumulator style, that looks as below *)
  fun overloaded_subterms acc ptm =
    case ptm of
      Overloaded x => x::acc
    | Comb{Rator, Rand, ...} =>
        overloaded_subterms (overloaded_subterms acc Rand) Rator
    | Abs{Bvar,Body,...} =>
        overloaded_subterms (overloaded_subterms acc Body) Bvar
    | Constrained{Ptm,...} => overloaded_subterms acc Ptm
    | _ => acc
  val overloads = overloaded_subterms [] ptm
  val _ = if length overloads >= 30
          then HOL_WARNING "Preterm" "remove_overloading"
           (String.concat["many overloaded symbols in term: ",
                          "overloading resolution might take a long time."])
          else ()
  fun workfunction list =
    case list of
      [] => return []
    | ({Name,Ty,Info,Locn,...}:overinfo)::xs => let
        val actual_ops = #actual_ops Info
        fun tryit {Ty = ty, Name = n, Thy = thy} =
          let val pty0 = Pretype.fromType ty
              val pty = Pretype.rename_typevars pty0
          in unify pty Ty >> return (Const{Name=n, Ty=Ty, Thy=thy, Locn=Locn})
          end
      in
        tryall tryit actual_ops >- (fn c =>
        workfunction xs >- (fn cs =>
        return (c::cs)))
      end
in
  workfunction overloads
end

fun do_overloading_removal ptm0 = let
  open seq
  val ptm = remove_overloading_phase1 ptm0
  val result = remove_overloading ptm []
  fun apply_subst subst = app (fn (r, value) => r := SOME value) subst
  fun do_csubst clist ptm =
    case clist of
      [] => (ptm, [])
    | (c::cs) => let
      in
        (* must take care to keep order of traversal same as traversal in
           overloaded_subterms above *)
        case ptm of
          Comb{Rator, Rand, Locn} => let
            (* Rator before Rand *)
            val (Rator', clist') = do_csubst clist Rator
            val (Rand', clist'') = do_csubst clist' Rand
          in
            (Comb{Rator = Rator', Rand = Rand', Locn = Locn}, clist'')
          end
        | Abs{Bvar, Body, Locn} => let
            (* Bvar before Body *)
            val (Bvar', clist') = do_csubst clist Bvar
            val (Body', clist'') = do_csubst clist' Body
          in
            (Abs{Bvar = Bvar', Body = Body', Locn = Locn}, clist'')
          end
        | Constrained{Ptm,Ty,Locn} => let
            val (Ptm', clist') = do_csubst clist Ptm
          in
            (Constrained{Ptm = Ptm', Ty = Ty, Locn = Locn}, clist')
          end
        | Overloaded _ => (c,cs)
        | _ => (ptm, clist)
      end
in
  case cases result of
    NONE => raise ERRloc "do_overloading_removal" (locn ptm0)
      "Couldn't find a sensible resolution for overloaded constants"
  | SOME ((env,clist),xs) =>
      if not (!Globals.guessing_overloads)
         orelse !Globals.notify_on_tyvar_guess
      then
        case cases xs
         of NONE => (apply_subst env; #1 (do_csubst clist ptm))
          | SOME _ => let in
              if not (!Globals.guessing_overloads)
                 then raise ERRloc "do_overloading_removal" (locn ptm0)
                         "More than one resolution of overloading possible"
                 else ();
              if !Globals.interactive then
                Feedback.HOL_MESG
                  "more than one resolution of overloading was possible"
              else ();
              apply_subst env;
              #1 (do_csubst clist ptm)
            end
      else
        (apply_subst env; #1 (do_csubst clist ptm))
end

fun remove_elim_magics ptm =
  case ptm of
    Var _ => ptm
  | Const _ => ptm
  | Antiq _ => ptm
  | Comb{Rator = (rator as Const{Name, ...}), Rand = ptm1, Locn} =>
      if Name = nat_elim_term then ptm1
      else Comb{Rator = rator, Rand = remove_elim_magics ptm1, Locn = Locn}
  | Comb{Rator, Rand, Locn} => Comb{Rator = remove_elim_magics Rator,
                                    Rand = remove_elim_magics Rand, Locn = Locn}
  | Abs{Bvar, Body, Locn} => Abs{Bvar = remove_elim_magics Bvar,
                                 Body = remove_elim_magics Body, Locn = Locn}
  | Constrained{Ptm, Ty, Locn} => Constrained{Ptm = remove_elim_magics Ptm, Ty = Ty, Locn = Locn}
  | Overloaded _ => raise Fail "Preterm.remove_elim_magics on Overloaded"


val overloading_resolution0 = remove_elim_magics o do_overloading_removal

fun overloading_resolution ptm =
    overloading_resolution0 ptm
    handle phase1_exn(l,s,ty) =>
           (Lib.say s ; raise ERRloc "overloading_resolution" l s)

(*---------------------------------------------------------------------------
 * Type inference for HOL terms. Looks ugly because of error messages, but is
 * actually very simple, given side-effecting unification.
 *---------------------------------------------------------------------------*)

fun is_atom (Var _) = true
  | is_atom (Const _) = true
  | is_atom (Constrained{Ptm,...}) = is_atom Ptm
  | is_atom (Overloaded _) = true
  | is_atom (t as Comb{Rator,Rand,...}) =
      Literal.is_numeral (to_term (overloading_resolution t)) orelse
      Literal.is_numeral (to_term (overloading_resolution Rand)) andalso
        (case Rator
          of Overloaded{Name,...} => Name = fromNum_str
           | Const{Name,...} => Name = nat_elim_term
           | _ => false)
  | is_atom t = false


local
  fun ty1 --> ty2 = Pretype.Tyop{Thy = "min", Tyop = "fun", Args = [ty1, ty2]}
  fun ptype_of (Var{Ty, ...}) = Ty
    | ptype_of (Const{Ty, ...}) = Ty
    | ptype_of (Comb{Rator, ...}) = Pretype.chase (ptype_of Rator)
    | ptype_of (Abs{Bvar,Body,...}) = ptype_of Bvar --> ptype_of Body
    | ptype_of (Constrained{Ty,...}) = Ty
    | ptype_of (Antiq{Tm,...}) = Pretype.fromType (Term.type_of Tm)
    | ptype_of (Overloaded {Ty,...}) = Ty
  fun default_typrinter x = "<hol_type>"
  fun default_tmprinter x = "<term>"
in
fun TC printers = let
  val (ptm, pty) =
      case printers
       of SOME (x,y) =>
          let val typrint = Lib.say o y
              fun tmprint tm =
                  if Term.is_const tm
                  then (Lib.say (x tm ^ " " ^ y (Term.type_of tm)))
                  else Lib.say (x tm)
          in
            (tmprint, typrint)
          end
        | NONE => (Lib.say o default_tmprinter, Lib.say o default_typrinter)
  fun check(Comb{Rator, Rand, Locn}) =
      (check Rator;
       check Rand;
       Pretype.unify (ptype_of Rator)
       (ptype_of Rand --> Pretype.new_uvar())
       handle (e as Feedback.HOL_ERR{origin_structure="Pretype",
                                     origin_function="unify",message})
       => let val tmp = !Globals.show_types
              val _   = Globals.show_types := true
              val Rator' = to_term (overloading_resolution0 Rator)
                handle e => (Globals.show_types := tmp; raise e)
              val Rand'  = to_term (overloading_resolution0 Rand)
                handle e => (Globals.show_types := tmp; raise e)
          in
            Lib.say "\nType inference failure: unable to infer a type \
                              \for the application of\n\n";
            ptm Rator';
            Lib.say ("\n\n"^locn.toString (locn Rator)^"\n\n");

            if (is_atom Rator) then ()
            else(Lib.say"which has type\n\n";
                 pty(Term.type_of Rator');
                 Lib.say"\n\n");

            Lib.say "to\n\n"; ptm Rand';
            Lib.say ("\n\n"^locn.toString (locn Rand)^"\n\n");

            if (is_atom Rand) then ()
            else(Lib.say"which has type\n\n";
                 pty(Term.type_of Rand');
                 Lib.say"\n\n");

            Lib.say ("unification failure message: "^message^"\n");
            Globals.show_types := tmp;
            raise ERRloc"typecheck" (locn Rand (* arbitrary *)) "failed"
          end)
    | check (Abs{Bvar, Body, Locn}) = (check Bvar; check Body)
    | check (Constrained{Ptm,Ty,Locn}) =
       (check Ptm; Pretype.unify (ptype_of Ptm) Ty
       handle (e as Feedback.HOL_ERR{origin_structure="Pretype",
                                    origin_function="unify",message})
       => let val tmp = !Globals.show_types
              val _ = Globals.show_types := true
              val real_term = to_term (overloading_resolution0 Ptm)
                handle e => (Globals.show_types := tmp; raise e)
              val real_type = Pretype.toType Ty
                handle e => (Globals.show_types := tmp; raise e)
          in
            Lib.say "\nType inference failure: the term\n\n";
            ptm real_term;
            Lib.say ("\n\n"^locn.toString (locn Ptm)^"\n\n");
            if (is_atom Ptm) then ()
            else(Lib.say"which has type\n\n";
                 pty(Term.type_of real_term);
                 Lib.say"\n\n");
            Lib.say "can not be constrained to be of type\n\n";
            pty real_type;
            Lib.say ("\n\nunification failure message: "^message^"\n");
            Globals.show_types := tmp;
            raise ERRloc"typecheck" Locn "failed"
          end)
    | check _ = ()
in check
end end;

fun typecheck_phase1 pfns ptm =
    TC pfns ptm
    handle phase1_exn(l,s,ty) => let
           in
             case pfns of
               NONE => (Lib.say s; raise ERRloc "typecheck" l s)
             | SOME (_, typ) =>
               (Lib.say s;
                Lib.say "Wanted it to have type:  ";
                Lib.say (typ ty);
                Lib.say "\n";
                raise ERRloc "typecheck" l s)
           end

(* ---------------------------------------------------------------------- *)
(* function to do the equivalent of strip_conj, but where the "conj" is   *)
(* the magic binary operator bool$<GrammarSpecials.case_split_special     *)
(* ---------------------------------------------------------------------- *)

open HolKernel
fun dest_binop n c t = let
  val (f,args) = strip_comb t
  val {Name,Thy,...} = dest_thy_const f
      handle HOL_ERR _ =>
             raise ERR ("dest_case"^n) ("Not a "^n^" term")
  val _ = (Name = c andalso Thy = "bool") orelse
          raise ERR ("dest_case"^n) ("Not a "^n^" term")
  val _ = length args = 2 orelse
          raise ERR ("dest_case_"^n) ("case "^n^" 'op' with bad # of args")
in
  (hd args, hd (tl args))
end

val dest_case_split = dest_binop "split" case_split_special
val dest_case_arrow = dest_binop "arrow" case_arrow_special

fun strip_splits t0 = let
  fun trav acc t = let
    val (l,r) = dest_case_split t
  in
    trav (trav acc r) l
  end handle HOL_ERR _ => t::acc
in
  trav [] t0
end

fun mk_conj(t1, t2) = let
  val c = mk_thy_const{Name = "/\\", Thy = "bool",
                       Ty = Type.bool --> Type.bool --> Type.bool}
in
  mk_comb(mk_comb(c,t1), t2)
end

fun list_mk_conj [] = raise ERR "list_mk_conj" "empty list"
  | list_mk_conj [h] = h
  | list_mk_conj (h::t) = mk_conj(h, list_mk_conj t)
fun mk_eq(t1, t2) = let
  val ty = type_of t1
  val c = mk_thy_const{Name = "=", Thy = "min", Ty = ty --> ty --> Type.bool}
in
  mk_comb(mk_comb(c,t1),t2)
end

datatype rcm_action = Input of term
                    | Ab of term * term
                    | Cmb of int * term
datatype rcm_out = Ch of term | Unch of term
fun is_unch (Unch _) = true | is_unch _ = false
fun dest_out (Ch t) = t | dest_out (Unch t) = t
fun Pprefix P list = let
  fun recurse pfx rest =
      case rest of
        [] => (list, [])
      | h::t => if P h then recurse (h::pfx) t
                else (List.rev pfx, rest)
in
  recurse [] list
end

fun recomb (outf, outargs, orig) = let
  fun lmk(base, args) = List.foldl (fn (out,t) => mk_comb(t,dest_out out))
                                   base args
in
  case outf of
    Ch f => Ch (lmk(f, outargs))
  | Unch f => let
      val (_, badargs) = Pprefix is_unch outargs
    in
      if null badargs then Unch orig
      else Ch (lmk(funpow (length badargs) rator orig, badargs))
    end
end

fun remove_case_magic tm0 =
    if GrammarSpecials.case_initialised() then let
        fun traverse acc actions =
            case actions of
              [] => dest_out (hd acc)
            | act :: rest => let
              in
                case act of
                  Input t => let
                  in
                    if is_abs t then let
                        val (v,body) = dest_abs t
                      in
                        traverse acc (Input body :: Ab (v,t) :: rest)
                      end
                    else if is_comb t then let
                        val (f,args) = strip_comb t
                        val in_args = map Input args
                      in
                        traverse acc (in_args @
                                      [Input f, Cmb(length args, t)] @ rest)
                      end
                    else
                      traverse (Unch t::acc) rest
                  end
                | Ab (v,orig) => let
                  in
                    case acc of
                      Ch bod' :: acc0 => traverse (Ch (mk_abs(v,bod'))::acc0)
                                                  rest
                    | Unch _ :: acc0 => traverse (Unch orig :: acc0) rest
                    | [] => raise Fail "Preterm.rcm: inv failed!"
                  end
                | Cmb(arglen, orig) => let
                    val out_f = hd acc
                    val f = dest_out out_f
                    val acc0 = tl acc
                    val acc_base = List.drop(acc0, arglen)
                    val out_args = List.rev (List.take(acc0, arglen))
                    val args = map dest_out out_args
                    val newt = let
                      val {Name,Thy,Ty} = dest_thy_const f
                    in
                      if Name = case_special andalso Thy = "bool" then let
                          val _ = length args >= 2 orelse
                                  raise ERR "remove_case_magic"
                                            "case constant has wrong # of args"
                          val split_on_t = hd args
                          val cases = strip_splits (hd (tl args))
                          val patbody_pairs = map dest_case_arrow cases
                              handle HOL_ERR _ =>
                              raise ERR "remove_case_magic"
                                        ("Case expression has invalid syntax "^
                                         "where there should be arrows")
                          val split_on_t_ty = type_of split_on_t
                          val result_ty =
                              type_of (list_mk_comb(f, List.take(args,2)))
                          val fakef = genvar (split_on_t_ty --> result_ty)
                          val fake_eqns =
                              list_mk_conj(map (fn (l,r) =>
                                                   mk_eq(mk_comb(fakef, l), r))
                                               patbody_pairs)
                          val functional =
                              GrammarSpecials.compile_pattern_match fake_eqns
                          val case_t =
                              mk_comb(rator (#2 (strip_abs functional)),
                                      split_on_t)
                        in
                          Ch (list_mk_comb(case_t, tl (tl args)))
                        end
                      else
                        recomb(out_f, out_args, orig)
                    end handle HOL_ERR _ => recomb(out_f, out_args, orig)
                  in
                    traverse (newt::acc_base) rest
                  end
              end
      in
        traverse [] [Input tm0]
      end
    else tm0

fun typecheck pfns ptm0 = let
  val () = TC pfns ptm0
  val ptm = overloading_resolution0 ptm0
in
  remove_case_magic (to_term ptm)
end handle phase1_exn(l,s,ty) =>
           case pfns of
             NONE => (Lib.say s; raise ERRloc "typecheck" l s)
           | SOME (_, typ) =>
             (Lib.say s;
              Lib.say "Wanted it to have type:  ";
              Lib.say (typ ty);
              Lib.say "\n";
              raise ERRloc "typecheck" l s)


end; (* Preterm *)

