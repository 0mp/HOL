structure armLib :> armLib =
struct

(* interactive use:
 app load ["fcpLib", "armTheory", "coreTheory"];
*)

open HolKernel boolLib bossLib;
open Q pairTheory;
open onestepTheory armTheory coreTheory;

(* ------------------------------------------------------------------------- *)

local
  val ICLASS_CONV = (REWRITE_CONV [iclass_EQ_iclass,iclass2num_thm]
                       THENC numLib.REDUCE_CONV);
  fun conv_rec t = {name = "ICLASS_CONV",trace = 3,conv = K (K ICLASS_CONV),
                    key = SOME([t],mk_eq(t,``x:iclass``))};
in
  val ICLASS_ss = simpLib.SSFRAG
    {convs = map conv_rec [``swp``,``mrs_msr``,``data_proc``,``reg_shift``,
             ``mla_mul``, ``ldr``,``str``,``ldm``,``stm``,``br``,``swi_ex``,
             ``cdp_und``, ``mcr``,``mrc``,``ldc``,``stc``,``unexec``],
   rewrs = [], congs = [], filter = NONE, ac = [], dprocs = []};
end;

local open fcpTheory in
  val fcp_ss = std_ss ++ fcpLib.FCP_ss;
end;

val std_ss = std_ss ++ boolSimps.LET_ss;

local open io_onestepTheory in
  val stdi_ss = std_ss ++ ICLASS_ss ++ rewrites [iseq_distinct] ++
        (rewrites [state_out_accessors, state_out_updates_eq_literal,
           state_out_accfupds, state_out_fupdfupds, state_out_literal_11,
           state_out_fupdfupds_comp, state_out_fupdcanon,
           state_out_fupdcanon_comp]) ;
  val STATE_INP_ss =
         rewrites [state_inp_accessors, state_inp_updates_eq_literal,
           state_inp_accfupds, state_inp_fupdfupds, state_inp_literal_11,
           state_inp_fupdfupds_comp, state_inp_fupdcanon,
           state_inp_fupdcanon_comp];
end;

local
  fun rstrip_comb l =
     if is_comb l then
       List.concat (map rstrip_comb (snd (boolSyntax.strip_comb l)))
     else
       [l];
in
  fun combCases M =
   let val vlist = rstrip_comb M
       val X = variant vlist (mk_var("x",type_of M))
       val tm = list_mk_exists(vlist, mk_eq(X,M))
   in
     GEN_ALL (METIS_PROVE (map (fn (a,(b,c)) => b) (find "nchotomy")) tm)
   end
end;

fun tupleCases M =
 let val vlist = pairSyntax.strip_pair M
     val X = variant vlist (mk_var("x",type_of M))
     val tm = list_mk_exists(vlist, mk_eq(X,M))
 in
   GEN_ALL (METIS_PROVE [pairTheory.ABS_PAIR_THM] tm)
 end;

val PBETA_ss = simpLib.SSFRAG
 {convs = [{name="PBETA",trace = 3,conv=K (K PairRules.PBETA_CONV),
  key = SOME([],``(\(x:'a,y:'b). s1) s2:'c``)}], rewrs = [], congs = [],
  filter = NONE, ac = [], dprocs = []};

fun RES_MP1_TAC s t =
 let val a = (fst o dest_imp o concl o INST s o SPEC_ALL) t
 in
   Tactical.SUBGOAL_THEN a (fn th => STRIP_ASSUME_TAC (MATCH_MP t th))
 end;

fun RES_MP_TAC s t = RES_MP1_TAC s t THEN1 METIS_TAC [];

end
