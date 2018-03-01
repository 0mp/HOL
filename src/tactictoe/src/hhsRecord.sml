(* =========================================================================  *)
(* FILE          : hhsRecord.sml                                              *)
(* DESCRIPTION   : Record tactics, theorems and goal lists                    *)
(* AUTHOR        : (c) Thibault Gauthier, University of Innsbruck             *)
(* DATE          : 2017                                                       *)
(* ========================================================================== *)

structure hhsRecord :> hhsRecord =
struct

open HolKernel boolLib
hhsTools hhsLexer hhsTimeout hhsExec hhsSetup 
hhsNumber hhsExtract hhsUnfold
hhsThmData hhsTacticData hhsGoallistData 
hhsPredict hhsLearn
tacticToe

val ERR = mk_HOL_ERR "hhsRecord"

val goalstep_glob = ref []
val tactictoe_step_counter = ref 0
val tactictoe_thm_counter = ref 0
val replay_timeout = 20.0

fun local_tag x = x
fun add_local_tag s = "( hhsRecord.local_tag " ^ s ^ ")"

(*----------------------------------------------------------------------------
 * Error messages and profiling
 *----------------------------------------------------------------------------*)

fun tactic_msg msg stac g = 
  debug_replay ("replay_tactic " ^ msg ^ ": " ^ stac)

fun proof_msg f_debug prefix msg thmname qtac final_stac =
  (
  f_debug thmname;
  f_debug (prefix ^ " " ^ msg ^ ":");
  f_debug ("  " ^ qtac);
  f_debug ("  " ^ final_stac);
  f_debug ""
  )

fun replay_msg msg thmname qtac final_stac = 
  proof_msg debug_replay "replay_proof" msg thmname qtac final_stac
fun parse_msg thmname qtac final_stac = 
  proof_msg debug_parse "" "parse_proof" thmname qtac final_stac
fun parse_err thmname qtac final_stac = 
  (parse_msg thmname qtac final_stac; raise ERR "" "")
  
val n_parse_glob = ref 0
val n_replay_glob = ref 0
val n_tactic_parse_glob = ref 0
val n_tactic_replay_glob = ref 0

val tactic_time = ref 0.0
val save_time = ref 0.0
val record_time = ref 0.0
val extract_time = ref 0.0
val number_time = ref 0.0
val exec_time = ref 0.0
val mkfinal_time = ref 0.0
val hide_time = ref 0.0
val replay_time = ref 0.0
val original_time = ref 0.0
val fetch_thm_time = ref 0.0

fun reset_profiling () =
  (
  fetch_thm_time := 0.0;
  tactic_time := 0.0;
  feature_time := 0.0;
  save_time := 0.0;
  record_time := 0.0;
  extract_time := 0.0; 
  number_time := 0.0;
  exec_time := 0.0; 
  mkfinal_time := 0.0;
  hide_time := 0.0;
  replay_time := 0.0;
  n_parse_glob := 0; n_replay_glob := 0;
  n_tactic_parse_glob := 0; n_tactic_replay_glob := 0;
  (* not part of profiling but is there for now *)
  tactictoe_step_counter := 0
  )

fun out_record_summary cthy =
  let
    fun f i s = debug_record (int_to_string i ^ " " ^ s) 
    fun g s r = debug_record (s ^ ": " ^ Real.toString r)
  in
    f (!n_parse_glob)  "proofs parsed";
    f (!n_replay_glob) "proofs replayed";
    f (!n_tactic_parse_glob) "tactic parsed";
    f (!n_tactic_replay_glob) "tactic replayed";
    g "  Fetch thm" (!fetch_thm_time);
    g "  Parse" (!hide_time);
    g "    Hide" (!hide_time - !mkfinal_time);
    g "    Number" (!number_time);
    g "    Extract" (!extract_time);
    g "    Tactic_of_sml" (!exec_time);
    g "  Replay" (!replay_time);
    g "    Record" (!record_time);
    g "    Save" (!save_time);
    g "    Tactic" (!tactic_time);
    g "    Feature" (!feature_time);
    f (length (!hhs_tacerr)) "bad tactics during evaluation"
  end

(* --------------------------------------------------------------------------
   Replaying a tactic.
   -------------------------------------------------------------------------- *)

fun tactic_err msg stac g = 
  (tactic_msg msg stac g; raise ERR "record_tactic" "")

fun record_tactic_aux (tac,stac) g =
  let
    val ((gl,v),t) = add_time (timeOut 2.0 tac) g 
      handle TacTimeOut => tactic_err "timed out" stac g
            | x         => raise x
  in
    tactic_time := (!tactic_time) + t;
    n_tactic_replay_glob := (!n_tactic_replay_glob) + 1;
    goalstep_glob := ((stac,t,g,gl),v) :: !goalstep_glob;
    (gl,v)
  end

fun record_tactic (tac,stac) g =
  total_time record_time (record_tactic_aux (tac,stac)) g

(* --------------------------------------------------------------------------
   Replaying a proof: following code is legacy code (very ugly).
   -------------------------------------------------------------------------- *)

fun wrap_tactics_in name qtac goal = 
  let
    val success_flag = ref NONE
    val cthy = current_theory ()
    val final_stac_ref = ref ""
    fun mk_alttac qtac = 
      let
        val _ = final_stac_ref := ""
        val s2 = total_time number_time number_stac qtac
        val ostac = hhs_lex s2
        val l2 = total_time extract_time hhs_extract s2
        val _  = debug_proof ("Org tac number: " ^ int_to_string (length l2))
        val _  = n_tactic_parse_glob := (!n_tactic_parse_glob) + length l2;
        val l3 = map (fn x => (x, drop_numbering x)) l2
        fun mk_reps (x,y) =
          ["( hhsRecord.record_tactic","("] @ y @ 
          [",", mlquote (String.concatWith " " y),")",")"]
        val l5 = map (fn (x,y) => (x, mk_reps (x,y))) l3
        val ostac0 = fold_left replace_at l5 ostac
        val ostac1 = drop_numbering ostac0
        val final_stac = String.concatWith " " ostac1
        val _ = final_stac_ref := final_stac
        val final_tac = total_time exec_time tactic_of_sml final_stac         
      in
        (final_stac, final_tac)
      end
      handle _ => parse_err name qtac (!final_stac_ref)
    val (final_stac, final_tac)  =   
      total_time hide_time (hide_out (total_time mkfinal_time mk_alttac)) qtac
  in
    print (int_to_string (!n_tactic_parse_glob) ^ "\n");
    incr n_parse_glob;
    (
    let
      val (gl,v) = 
      total_time replay_time (hhsTimeout.timeOut replay_timeout final_tac) goal
    in
      if gl = []
        then (
             success_flag := SOME (gl,v);
             debug_proof ("Original proof time: " ^ 
                          Real.toString (!original_time));
             n_replay_glob := (!n_replay_glob + 1)
             )
      else replay_msg "opened goals" name qtac final_stac         
    end
    handle 
        TacTimeOut => replay_msg "timed out or other" name qtac final_stac
      | _          => replay_msg "other error" name qtac final_stac
    );
    case (!success_flag) of 
      SOME x => x
    | NONE   => raise ERR "" ""
  end

(*----------------------------------------------------------------------------
  Globalizing theorems and create a new theorem if the value does not exists.
  ----------------------------------------------------------------------------*)
 
fun save_tactictoe_thm thm =
  let 
    val name = "tactictoe_thm_" ^ int_to_string (!tactictoe_thm_counter)
    val _    = incr tactictoe_thm_counter
    val cthy = current_theory ()
  in
    ignore (save_thm (name,thm)); 
    String.concatWith " " ["(","DB.fetch",mlquote cthy,mlquote name,")"]
  end

fun depid_of_thm thm = 
  (Dep.depid_of o Tag.dep_of o Thm.tag) thm
  handle HOL_ERR _ => raise ERR "depid_of_thm" ""
  
fun sml_of_thm thm =
  if can depid_of_thm thm then
    let 
      val (thy,n) = depid_of_thm thm
      val thml = DB.thms thy
      val thmdict = dnew goal_compare (map (fn (a,b) => (dest_thm b,a)) thml)
      val goal = dest_thm thm
    in
      if dmem goal thmdict 
      then
        let val name = dfind goal thmdict in
          SOME (String.concatWith " " 
            ["(","DB.fetch",mlquote thy,mlquote name,")"])
        end
      else NONE
    end
  else NONE

(* replacement string is not used anymore for theorems *)
fun fetch_thm s reps =
  let val sthmo = hide_out thm_of_sml s in
    case sthmo of
      NONE => 
        (if reps = "" 
        then (debug_record ("fetch_other: " ^ s); add_local_tag s) 
        else reps)
    | SOME (_,thm) =>
    let val nameo = sml_of_thm thm in
      case nameo of
        SOME x => x
      | NONE => (debug_record ("fetch_thm: " ^ s); add_local_tag s)
    end
  end
  
val fetch = total_time fetch_thm_time fetch_thm

(*----------------------------------------------------------------------------
  Tactical proofs hooks
  ----------------------------------------------------------------------------*)

fun start_record lflag pflag name goal =
    (
    if !hhs_eval_flag then init_tactictoe () else ();
    (* recording goal steps *)
    goalstep_glob := [];
    (* evaluation *)
    if not (!hhs_eval_flag) orelse
       not (!test_eval_hook name) orelse
       (lflag andalso not (!hhs_evlet_flag)) orelse 
       (pflag andalso not (!hhs_evprove_flag)) (* orelse
       (not lflag andalso (!hhs_evletonly_flag)) *)
    then ()
    else 
      if one_in_n () 
      then 
        (
        debug_t "update_mdict" update_mdict (current_theory ());
        eval_tactictoe name goal handle _ => 
        debug ("Error: eval_tactictoe: last_stac: " ^ 
               !hhsSearch.last_stac)
        )
      else ()
    )

(* ----------------------------------------------------------------------
   Save the proof steps in the database. Includes orthogonalization.
   ---------------------------------------------------------------------- *)

fun end_record name g = 
  let
    val lbls = map fst (rev (!goalstep_glob))
  in
    (* because we want internal theorems on orthogonalization *)
    debug_t "update_mdict" update_mdict (current_theory ());
    debug_t ("Saving " ^ int_to_string (length lbls) ^ " labels")
      (app save_lbl) lbls
  end

fun org_tac tac g =
  let val (gl,v) = tac g in
    if null gl 
    then (gl,v)
    else (
         debug "Record error: org_tac: not null";
         ignore (hhsExec.exec_sml "cache" "numSimps.clear_arith_caches ()"); 
         tac g
         )
  end
  handle _ => 
     (
     debug "Record error: org_tac";
     ignore (hhsExec.exec_sml "cache" "numSimps.clear_arith_caches ()"); 
     tac g
     )

val thm_counter = ref 0

fun init_record_proof name =
  let val outname = "\nName: " ^ int_to_string (!thm_counter) ^ " " ^ name in
    debug_proof outname;
    debug_search outname;
    debug outname;
    incr thm_counter
  end

fun try_record_proof name lflag tac1 tac2 g =
  let
    val _ = init_record_proof name
    (* Conditions on recording and evaluation *)
    val pflag = String.isPrefix "tactictoe_prove_" name
    val b1 = not (!hhs_record_flag)
    val b2 = (not (!hhs_recprove_flag) andalso pflag)
    val b3 = (not (!hhs_reclet_flag) andalso lflag)       
    val result =
      if b1 orelse b2 orelse b3
      then 
        let val (r,t) = add_time (org_tac tac2) g in
          debug_proof ("Original proof time: " ^ Real.toString t);
          r
        end
      else
        let        
          val _ = start_record lflag pflag name g
          val (r,t) = add_time tac1 g
          val _ = debug_proof ("Recording proof time: " ^ Real.toString t)
          val _ = end_record name g
        in 
          if null (fst r) 
          then r
          else (debug "Record error: try_record_proof: not null"; org_tac tac2 g)
        end
        handle _ => (debug "Record error: try_record_proof"; org_tac tac2 g)
  in    
    result
  end

(*----------------------------------------------------------------------------
  Theory hooks
  ----------------------------------------------------------------------------*)

fun clean_subdirl cthy dir subdirl =
  let 
    fun clean_sub x = 
      (mkDir_err (dir ^ "/" ^ x); erase_file (dir ^ "/" ^ x ^ "/" ^ cthy))
  in
    mkDir_err dir;
    app clean_sub subdirl 
  end 

fun clean_dir cthy dir = (mkDir_err dir; erase_file (dir ^ "/" ^ cthy))

fun start_thy cthy =
  (
  mkDir_err hhs_code_dir;
  (* necessary for export if no proofs are found *)
  hhsSetup.set_record cthy;
  (* exporting theorems from boolTheory in ConseqConv *)
  if cthy = "ConseqConv" 
  then (clean_tttdata (); 
        clean_subdirl "bool" hhs_search_dir ["debug","search","proof"];
        mkDir_err hhs_thmfea_dir;
        debug_t "export_thmfea" export_thmfea "bool") 
  else ();
  clean_tttdata ();
  reset_profiling ();
  (* Proof search *)
  clean_subdirl cthy hhs_search_dir ["debug","search","proof"];
  mkDir_err hhs_tacfea_dir;
  mkDir_err hhs_thmfea_dir;
  mkDir_err hhs_glfea_dir;
  (* Tactic scripts recording *)
  clean_subdirl cthy hhs_record_dir ["parse","replay","record"] 
  )

fun end_thy cthy =
  (
  (* tactic *)
  debug_t "export_tacfea" export_tacfea cthy;
  (* theorem *)
  debug_t "export_thmfea" export_thmfea cthy;
  (* goal list *)
  if !hhs_mcrecord_flag then debug_t "export_glfea" export_glfea cthy else ();
  out_record_summary cthy
  )

end (* struct *)
