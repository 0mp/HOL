structure type_pp :> type_pp =
struct

open Type Portable parse_type
open HOLgrammars

datatype mygrav =
  Sfx of int | Lfx of (int * string) | Rfx of (int * string) | Top

datatype single_rule = SR | IR of (associativity * string)

fun Fail s = Feedback.HOL_ERR {origin_function = "pp_type",
                               origin_structure = "type_pp",
                               message = s};

fun pp_type0 (G:grammar) = let
  fun lookup_tyop s = let
    fun recurse [] = NONE
      | recurse (x::xs) = let
        in
          case x of
            (p, SUFFIX slist) =>
              if Lib.mem s slist then SOME (p, SR) else recurse xs
          | (p, INFIX (slist, a)) => let
              val res = List.find (fn r => #opname r = s) slist
            in
              case res of
                NONE => recurse xs
              | SOME r => SOME(p, IR(a,#parse_string r))
            end
        end
  in
    recurse (rules G) : (int * single_rule) option
  end
  fun pr_ty pps ty grav depth = let
    val {add_string, add_break, begin_block, end_block,...} =
      with_ppstream pps
    fun pbegin b = if b then add_string "(" else ()
    fun pend b = if b then add_string ")" else ()
  in
    if depth = 0 then add_string "..."
    else
      if is_vartype ty then add_string (dest_vartype ty)
      else let
        val {Tyop, Args} = dest_type ty
        fun print_args grav0 args = let
          val parens_needed = case Args of [_] => false | _ => true
          val grav = if parens_needed then Top else grav0
        in
          pbegin parens_needed;
          begin_block INCONSISTENT 0;
          pr_list (fn arg => pr_ty pps arg grav (depth - 1))
                  (fn () => add_string ",") (fn () => add_break (1, 0)) args;
          end_block();
          pend parens_needed
        end
      in
        case Args of
          [] => add_string Tyop
        | [arg1, arg2] => let
            val (prec, rule) = valOf (lookup_tyop Tyop)
              handle Option =>
                raise Fail (Tyop^": no such type operator in grammar")
          in
            case rule of
              SR => let
                val addparens =
                  case grav of
                    Rfx(n, _) => (n > prec)
                  | _ => false
              in
                pbegin addparens;
                begin_block INCONSISTENT 0;
                (* knowing that there are two args, we know that they will
                   be printed with parentheses, so the gravity we pass in
                   here makes no difference. *)
                print_args Top Args;
                add_break(1,0);
                add_string Tyop;
                end_block();
                pend addparens
              end
            | IR(assoc, printthis) => let
                val parens_needed =
                  case grav of
                    Sfx n => (n > prec)
                  | Lfx (n, s) => if s = printthis then assoc <> LEFT
                                  else (n >= prec)
                  | Rfx (n, s) => if s = printthis then assoc <> RIGHT
                                  else (n >= prec)
                  | _ => false
              in
                pbegin parens_needed;
                begin_block INCONSISTENT 0;
                pr_ty pps arg1 (Lfx (prec, printthis)) (depth - 1);
                add_break(1,0);
                add_string printthis;
                add_break(1,0);
                pr_ty pps arg2 (Rfx (prec, printthis)) (depth -1);
                end_block();
                pend parens_needed
              end
          end
        | _ => let
            val (prec, _) = valOf (lookup_tyop Tyop)
              handle Option =>
                raise Fail (Tyop^": no such type constructor in grammar")
            val addparens =
              case grav of
                Rfx (n, _) => (n > prec)
              | _ => false
          in
            pbegin addparens;
            begin_block INCONSISTENT 0;
            print_args (Sfx prec) Args;
            add_break(1,0);
            add_string Tyop;
            end_block();
            pend addparens
          end
      end
  end
in
  pr_ty
end

fun pp_type G = let
  val baseprinter = pp_type0 G
in
  (fn pps => fn ty => baseprinter pps ty Top (!Globals.max_print_depth))
end

fun pp_type_with_depth G = let
  val baseprinter = pp_type0 G
in
  (fn pps => fn depth => fn ty => baseprinter pps ty Top depth)
end

end; (* struct *)

(* testing

val G = parse_type.BaseHOLgrammar;
fun p ty =
  Portable.pp_to_string 75
   (fn pp => fn ty => type_pp.pp_type G pp ty type_pp.Top 100) ty;

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
