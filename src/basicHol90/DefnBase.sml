structure DefnBase :> DefnBase = 
struct

open HolKernel

fun ERR func mesg = HOL_ERR{origin_structure = "DefnBase", 
                            origin_function = func, message = mesg};

(*---------------------------------------------------------------------------
    The type of definitions. This is an attempt to gather all the 
    information about a definition in one place.
 ---------------------------------------------------------------------------*)

datatype defn
   = ABBREV  of {eqn:thm, bind:string}
   | PRIMREC of {eqs:thm, ind:thm, bind:string}
   | NONREC  of {eqs:thm, ind:thm, stem:string}
   | STDREC  of {eqs:thm, ind:thm, R:term,SV:term list,stem:string}
   | NESTREC of {eqs:thm, ind:thm, R:term,SV:term list,stem:string,aux:defn}
   | MUTREC  of {eqs:thm, ind:thm, R:term,SV:term list,stem:string,union:defn};


local open Portable
      fun kind (ABBREV _) = "abbreviation"
        | kind (NONREC  _) = "non-recursive"
        | kind (STDREC  _) = "recursive"
        | kind (PRIMREC _) = "primitive recursion"
        | kind (NESTREC _) = "nested recursion"
        | kind (MUTREC  _) = "mutual recursion"
in
fun pp_defn ppstrm = 
 let val {add_string,add_break,
          begin_block,end_block,add_newline,...} = with_ppstream ppstrm
     val pp_term = Parse.pp_term ppstrm
     val pp_thm  = Parse.pp_thm ppstrm
     fun pp_rec (eqs,ind,tcs) =
        (begin_block CONSISTENT 0;
         add_string "Equation(s) :"; 
         add_break(1,0);
         pp_thm eqs; 
         add_newline (); add_newline ();
         add_string "Induction :"; 
         add_break(1,0);
         pp_thm ind; 
         if null tcs then ()
         else (add_newline (); add_newline ();
               add_string "Termination conditions :"; 
               add_break(1,2);
               begin_block CONSISTENT 0;
                 pr_list (fn (n,tm) =>
                           (begin_block CONSISTENT 3;
                            add_string (Lib.int_to_string n^". ");
                            pp_term tm; end_block()))
                         (fn () => ())
                         (fn () => add_break(1,0)) 
                      (Lib.enumerate 0 tcs);
               end_block());
         end_block())
   fun pp (ABBREV {eqn, ...}) = 
          (begin_block CONSISTENT 0;
           add_string "Equation :"; 
           add_break(1,0);
           pp_thm eqn; 
           end_block())
     | pp (PRIMREC{eqs, ind, bind}) = 
          (begin_block CONSISTENT 0;
           add_string "Equation(s) :"; 
           add_break(1,0);
           pp_thm eqs; end_block())
     | pp (NONREC {eqs, ind, stem}) = 
          (begin_block CONSISTENT 0;
           add_string "Equation(s) :"; 
           add_break(1,0);
           pp_thm eqs; 
           add_newline (); add_newline(); 
           add_string "Case analysis:"; 
           add_break(1,0); pp_thm ind;
           end_block())
     | pp (STDREC {eqs, ind, R, SV, stem}) = pp_rec(eqs,ind, hyp ind)
     | pp (NESTREC{eqs, ind, R, SV, aux, stem}) = pp_rec(eqs,ind, hyp ind)
     | pp (MUTREC {eqs, ind, R, SV, union, stem}) = pp_rec(eqs,ind, hyp ind)
 in
   fn d =>
       (begin_block CONSISTENT 0;
        add_string "HOL function definition "; 
        add_string (String.concat ["(",kind d,")"]);
        add_newline (); add_newline ();
        pp d;
        end_block())
 end
end;


(*---------------------------------------------------------------------------
    Congruence rules for termination condition extraction. Before 
    t.c. extraction is performed, the theorems in "non_datatype_context" 
    are added to the congruence rules arising from datatype definitions.
 ---------------------------------------------------------------------------*)

local open boolTheory
      val non_datatype_congs = ref [LET_CONG, COND_CONG]
in
  fun read_congs() = !non_datatype_congs
  fun write_congs L = (non_datatype_congs := L)
end;

end;
