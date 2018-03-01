(* ========================================================================== *)
(* FILE          : hhsSearch.sml                                              *)
(* DESCRIPTION   : Search algorithm for TacticToe.                            *)
(* AUTHOR        : (c) Thibault Gauthier, University of Innsbruck             *)
(* DATE          : 2017                                                       *)
(* ========================================================================== *)

structure hhsSearch :> hhsSearch =
struct

open HolKernel boolLib Abbrev hhsTools hhsTimeout hhsFeature hhsPredict
hhsExec hhsLexer hhsMinimize hhsThmData hhsTacticData hhsLearn hhsSetup

val ERR = mk_HOL_ERR "hhsSearch"
val last_stac = ref ""
fun debug_err s = (debug ("Error: " ^ s); raise ERR "standard" "error")

(* --------------------------------------------------------------------------
   Exceptions
   -------------------------------------------------------------------------- *)

exception SearchTimeOut
exception NoNextTac

(* --------------------------------------------------------------------------
   Handling asynchronous calls data
   -------------------------------------------------------------------------- *) 

(* Result *)
datatype async_result_t = 
  HSuccess of (string * goal) | 
  HFailure |
  HRunning of Thread.Thread.thread | 
  HVoid  

(* 100000 is the maximum number of nodes *)
val hammer_ref = ref 0
val async_result = Array.array (100000, HVoid)
val install_async = ref (dempty Int.compare)
val running_async = ref (dempty Int.compare)

(* Start and end of search *)
fun init_async () = 
  if !hhs_hhhammer_flag 
  then 
    (
    hammer_ref := 0;
    install_async := dempty Int.compare;
    running_async := dempty Int.compare;
    Array.modify (fn _ => HVoid) async_result
    )
  else ()
  
fun terminate_thread pid thread =
  while (Thread.Thread.isActive thread)
  do (debug_search ("terminate thread " ^ int_to_string pid);
      Thread.Thread.interrupt thread)

fun terminate_async_pid pid =
  if !hhs_hhhammer_flag then 
    (
    Array.update (async_result,pid,HVoid);
    install_async := drem pid (!install_async);
    running_async := drem pid (!running_async);
    if dmem pid (!running_async)
    then terminate_thread pid (dfind pid (!running_async))
    else ()
    )
  else ()
  
fun terminate_async () =
  if !hhs_hhhammer_flag 
  then app terminate_async_pid (dkeys (!running_async))
  else ()

fun queue_async pid g = 
  if !hhs_hhhammer_flag then 
    (
    terminate_async_pid pid;
    debug_search ("install thread " ^ int_to_string pid);
    install_async := dadd pid g (!install_async)
    ) 
  else ()

(* -------------------------------------------------------------------------
   Search references
   -------------------------------------------------------------------------- *)

val notactivedict = ref (dempty Int.compare)
fun is_notactive x = dmem x (!notactivedict)
fun is_active x = not (is_notactive x)

fun deactivate x = 
  (
  debug_search ("deactivate " ^ int_to_string x);
  terminate_async_pid x;
  notactivedict := dadd x () (!notactivedict)
  )
  
val proofdict = ref (dempty Int.compare)
val finproofdict = ref (dempty Int.compare)

val thmpredictor_glob = ref (fn _ => (fn _ => []))
val stacpredictor_glob = ref (fn _ => [])
val mcpredictor_glob = ref (fn _ => 0.0)
val hammer_glob = ref (fn _ => (fn _ => NONE))

val tacdict_glob = ref (dempty String.compare)
val glob_timer = ref NONE
(* for reconstruction of delayed tactic *)
val hammerdict = ref (dempty String.compare) 

(* --------------------------------------------------------------------------
   Caching tactic applications on goals
   -------------------------------------------------------------------------- *)

fun stacgoal_compare ((stac1,goal1),(stac2,goal2)) =
  case String.compare (stac1,stac2) of
    EQUAL => goal_compare (goal1,goal2)
  | x     => x

val stacgoal_cache = ref (dempty stacgoal_compare)

(* --------------------------------------------------------------------------
   Debugging
   -------------------------------------------------------------------------- *)

val stac_counter = ref 0

fun string_of_pred pred =
  "[" ^ String.concatWith "," pred ^ "]"

val inst_time = ref 0.0
val predict_time = ref 0.0
val thmpredict_time = ref 0.0
val terminst_time = ref 0.0
val infstep_time = ref 0.0
val node_create_time = ref 0.0
val node_find_time = ref 0.0
val mc_time = ref 0.0
val tot_time = ref 0.0

val inst_timer = total_time inst_time
val predict_timer = total_time predict_time
val thmpredict_timer = total_time thmpredict_time
val infstep_timer = total_time infstep_time
fun node_create_timer f x = total_time node_create_time f x
val node_find_timer = total_time node_find_time
val mc_timer = total_time mc_time
fun total_timer f x = total_time tot_time f x

fun reset_timers () =
  (
  inst_time := 0.0;
  predict_time := 0.0;
  thmpredict_time := 0.0;
  infstep_time := 0.0;
  node_create_time := 0.0;
  node_find_time := 0.0;
  mc_time := 0.0;
  tot_time := 0.0
  )

(* --------------------------------------------------------------------------
   Special tactics
   -------------------------------------------------------------------------- *)  

fun add_hammer pred =     
  if !hhs_hhhammer_flag then "tactictoe_hammer" :: pred else pred

fun add_metis pred =     
  if !hhs_metishammer_flag then "tactictoe_metis" :: pred else pred

(* --------------------------------------------------------------------------
   Monte Carlo Tree Search
   -------------------------------------------------------------------------- *)

fun array_to_list a =
  let fun f (a,l) = a :: l in
    rev (Array.foldl f [] a)
  end
  
(* wasteful as it re-evaluates the same list of goals multiple times *)
fun init_eval pripol pid =
  let
    val _ = debug_search "mcts evaluation"
    val prec = dfind pid (!proofdict)
    val {visit,pending,goalarr,prioreval,cureval,priorpolicy,...} = prec
    val eval =
      if !hhs_mcnoeval_flag then 0.0
      else if !hhs_mctriveval_flag then 1.0
      else (!mcpredictor_glob) (array_to_list (#goalarr prec))
  in
    priorpolicy := pripol;
    visit := 1.0;
    prioreval := eval;
    cureval := [eval] 
  end

fun backup_loop beval eval cid =
  let
    val crec = dfind cid (!proofdict)
    val {parid,visit,cureval,...} = crec
  in 
    if beval
    then cureval := eval :: !cureval
    else ()
    ;
    visit := !visit + 1.0;
    if parid = NONE then () else backup_loop beval eval (valOf parid)
  end

fun backup cid =
  let 
    val _ = debug_search "mcts backpropagation"
    val crec = dfind cid (!proofdict)
    val {parid,prioreval,...} = crec
  in 
    if parid = NONE 
    then () 
    else backup_loop true (!prioreval) (valOf parid)
  end

fun backup_fail cid =
  let
    val _ = debug_search "backup fail"
    val crec = dfind cid (!proofdict)
    val {parid,...} = crec
  in 
    if parid = NONE 
    then () 
    else backup_loop (!hhs_evalfail_flag) 0.0 (valOf parid)
  end

fun backup_success cid =
  let
    val _ = debug_search "backup success"
    val crec = dfind cid (!proofdict)
    val {parid,...} = crec
  in 
    if parid = NONE 
    then () 
    else backup_loop true 1.0 (valOf parid)
  end


(* --------------------------------------------------------------------------
   Node creation and deletion
   -------------------------------------------------------------------------- *)

val max_depth_mem = ref 0
val pid_counter = ref 0

fun next_pid () =
  let
    val r = !pid_counter
    val _ = pid_counter := !pid_counter + 1
  in
    r
  end

fun root_create goal pred =
  let
    fun init_empty _ = ref []
    val selfid = next_pid ()
    val selfrec =
      {
      selfid   = selfid,
      parid    = NONE,
      parstac  = NONE,
      pargn    = NONE,
      parg     = NONE,
      goalarr  = Array.fromList [goal],
      predarr  = Array.fromList [pred],
      depth = 0,
      (* proof saved for reconstruction + children *)
      pending  = ref [0],
      children = ref [],
      (* proof saved for reconstruction + children *)  
      proofl   = ref [],
      childrena = Array.fromList (map init_empty [goal]),
      (* preventing loop and parallel steps *)
      pardict  = dempty goal_compare,
      trydict  = ref (dempty (list_compare goal_compare)),
      (* monte carlo *)
      priorpolicy = ref 0.0,
      visit = ref 0.0,
      prioreval = ref 0.0, 
      cureval = ref [] 
      }
  in
    debug_search "Root";
    debug_search ("  goal: " ^
          String.concatWith "," (map string_of_goal [goal]));
    debug_search ("  pred: \n  " ^
       String.concatWith ",\n  " (map (string_of_pred o (first_n 2)) [pred]));
    proofdict := dadd selfid selfrec (!proofdict);
    init_eval 0.0 selfid
  end

fun root_create_wrap g =
  root_create g ((add_hammer o add_metis o !stacpredictor_glob) g)

fun node_create pripol tactime parid parstac pargn parg goallist 
    predlist pending pardict =
  let
    val selfid = next_pid ()
    fun init_empty _ = ref []
    val selfrec =
    {
      selfid   = selfid,
      parid    = SOME parid,
      parstac  = SOME parstac,
      pargn    = SOME pargn,
      parg     = SOME parg,
      goalarr  = Array.fromList goallist,
      predarr  = Array.fromList predlist,
      depth    = #depth (dfind parid (!proofdict)) + 1,
      (* goal considered *)
      pending  = ref pending,
      children = ref [],
      (* proof saved for reconstruction + children *)
      proofl = ref [],
      childrena = Array.fromList (map init_empty goallist),
      (* preventing loop and parallel steps *)
      pardict  = pardict,
      trydict  = ref (dempty (list_compare goal_compare)),
      (* monte carlo: dummy values changed by init_eval *)
      priorpolicy = ref 0.0,
      visit = ref 0.0,
      prioreval = ref 0.0,
      cureval = ref []   
    }
    val cdepth = #depth selfrec
  in
    if cdepth > !max_depth_mem then max_depth_mem := cdepth else ();
    debug_search 
       ("Node " ^ int_to_string selfid ^ " " ^ int_to_string parid ^ " " ^
        Real.toString (! (#priorpolicy selfrec)));
    debug_search 
       ("  goals: " ^ String.concatWith "," (map string_of_goal goallist));
    debug_search ("  predictions: " ^
       String.concatWith ",\n  " (map (string_of_pred o (first_n 2)) predlist));
    proofdict := dadd selfid selfrec (!proofdict);
    init_eval pripol selfid;
    selfid
  end

fun node_delete pid =
  (debug_search ("node_delete " ^ int_to_string pid); deactivate pid)

fun node_save pid =
  (
  debug_search ("node_save " ^ int_to_string pid);
  let val prec = dfind pid (!proofdict) in
    finproofdict := dadd pid prec (!finproofdict)
  end
  )

fun update_curstac newstac pid =
  let
    val prec = dfind pid (!proofdict)
    val gn = hd (!(#pending prec))
    val pred = Array.sub (#predarr prec, gn)
    val newpred = newstac :: tl pred
  in
    Array.update (#predarr prec, gn, newpred) 
  end 
  handle _ => debug_err ("update_curstac :" ^ newstac)

(* --------------------------------------------------------------------------
   Trying multiple terms.
   -------------------------------------------------------------------------- *)

fun try_nqtm pid n (stac,tac) (otm,qtac) g = 
  let 
    val glo = SOME (fst (tac g)) handle _ => NONE
    fun locprod x = case x of SOME gl => not (mem g gl) | NONE => false
  in
    if locprod glo then glo else
      let fun loop qtac tml = 
        case tml of [] => NONE | tm :: m =>      
        let val glo' = SOME (fst (qtac [ANTIQUOTE tm] g)) handle _ => NONE in
          if locprod glo' 
          then 
            let val newstac = inst_timer (inst_termarg stac) tm in
              update_curstac newstac pid; glo'
            end
          else loop qtac m
        end
      in
        loop qtac (termknn n g otm)  
      end
  end

(* --------------------------------------------------------------------------
   Application of a tactic.
   -------------------------------------------------------------------------- *)

val thml_dict = ref (dempty (cpl_compare goal_compare Int.compare))
val inst_dict = ref (dempty (cpl_compare String.compare goal_compare))

fun pred_sthml n g =
  dfind (g,n) (!thml_dict) handle _ =>
    let val sl = !thmpredictor_glob n g in
      thml_dict := dadd (g,n) sl (!thml_dict);
      sl
    end

fun inst_read stac g =
  if !hhs_thmlarg_flag andalso is_absarg_stac stac then
    (
    dfind (stac,g) (!inst_dict) handle NotFound =>
    let
      val _ = debug_search ("instantiating: " ^ stac)
      val sl = 
        if !hhs_thmlarg_flag 
        then pred_sthml (!hhs_thmlarg_number) g 
        else []
      val thmls = String.concatWith " , " (map dbfetch_of_string sl)
      val newstac = inst_stac thmls g stac
      val newtac = timed_tactic_of_sml newstac 
        handle _ => 
        (debug ("Warning: inst_read: " ^ newstac); raise ERR "inst_read" "") 
    in
      inst_dict := dadd (stac,g) (newstac,newtac,!hhs_tactic_time) (!inst_dict);
      debug_search ("to: " ^ newstac);
      (newstac,newtac,!hhs_tactic_time)
    end
    )
  else if stac = "tactictoe_metis" then
    (
    dfind (stac,g) (!inst_dict) handle NotFound =>
    let 
      val sl = pred_sthml (!hhs_metis_npred) g
      val newstac = mk_metis_call sl
      val newtac = timed_tactic_of_sml newstac        
    in
      inst_dict := dadd (stac,g) (newstac,newtac,!hhs_metis_time) (!inst_dict);
      debug_search ("to: " ^ newstac);
      (newstac,newtac,!hhs_metis_time)
    end
    )
  else (stac, dfind stac (!tacdict_glob), !hhs_tactic_time)  
     

fun glob_productive pardict trydict g glo = 
  case glo of
    NONE => NONE
  | SOME gl => 
    (
    if mem g gl orelse exists (fn x => dmem x pardict) gl orelse dmem gl trydict 
    then NONE 
    else SOME gl  
    )
    
fun apply_stac pid pardict trydict stac g =
  let
    val _ = last_stac := stac
    val _ = stac_counter := !stac_counter + 1
    (* instantiation of theorems and reading *)
    val (newstac,newtac,tim) = inst_read stac g 
      handle _ => (debug ("Warning: apply_stac: " ^ stac); 
                   ("Tactical.NO_TAC", NO_TAC, !hhs_tactic_time))
    val _ = update_curstac newstac pid
    (* execution *)
    val glo = dfind (newstac,g) (!stacgoal_cache) handle NotFound =>
      let val cpo = if !hhs_termarg_flag then abs_termarg newstac else NONE in
        case cpo of 
          NONE => app_tac tim newtac g
        | SOME (otm,qtac) =>  
        (* instantiations of terms *)
          let 
            val etac = 
              try_nqtm pid (!hhs_termarg_number) (newstac,newtac) (otm,qtac)
            val glo =  app_qtac tim etac g
          in
            glo
          end
      end
    (* testing for loops *)
    val newglo = glob_productive pardict trydict g glo
  in
    stacgoal_cache := dadd (newstac,g) glo (!stacgoal_cache);
    newglo 
  end
   
fun apply_next_stac pid =
  let
    val _ = debug_search "apply_next_stac"
    val prec = dfind pid (!proofdict)
    val gn = hd (! (#pending prec))
      handle _ => debug_err "apply_next_stac: empty pending"
    val g = Array.sub (#goalarr prec, gn)
    val pred = Array.sub (#predarr prec, gn)
    val trydict = !(#trydict prec)
    val pardict = (#pardict prec)
    val stac = hd pred 
      handle _ => debug_err "apply_next_stac: empty pred"
  in
    if stac = "tactictoe_hammer"
      then (queue_async pid g; NONE)
      else infstep_timer (apply_stac pid pardict trydict stac) g
  end

(* ----------------------------------------------------------------------
   Searching for a node (goal list) to explore.      
   ---------------------------------------------------------------------- *)

fun has_empty_pred pid =
  let
    val prec = dfind pid (!proofdict)
    val gn = hd (!(#pending prec))
    val pred = Array.sub (#predarr prec, gn)
      handle _ => debug_err ("find_next_tac: " ^ int_to_string pid)
  in
    if null pred then (deactivate pid; true) else false
  end

fun mc_node_find pid =
  let
    val prec = dfind pid (!proofdict) 
    val {children,visit,...} = prec
    val pvisit = !(#visit prec)
    val pdenom = Math.sqrt pvisit
    (* try new tactic on the node itself *)
    val n = length (!children)
    val self_pripol = 
      Math.pow (1.0 - !hhs_policy_coeff, Real.fromInt n) * !hhs_policy_coeff
    val self_curpol = 1.0 / pdenom
    val self_selsc = (pid, (!hhs_mc_coeff) * (self_pripol / self_curpol))
    (* or explore deeper existing paritial proofs *)
    fun f cid = 
      let 
        val crec = dfind cid (!proofdict)
        val pripol = !(#priorpolicy crec)
        val meaneval = average_real (!(#cureval crec))
        val visit = !(#visit crec)
        val curpol = (visit + 1.0) / pdenom
      in
        (cid, meaneval + (!hhs_mc_coeff) * (pripol / curpol))
      end
    (* sort and select node with best selection score *) 
    val l0 = self_selsc :: List.map f (!children)
    val l1 = dict_sort compare_rmax l0
    val (selid,_) = hd l1
  in
    if pid = selid 
      then (pid,self_pripol) 
      else mc_node_find selid
  end

fun try_mc_find () =
  if Timer.checkRealTimer (valOf (!glob_timer)) > (!hhs_search_time) 
  then (debug "Warning: try_mc_find"; raise SearchTimeOut)
  else
    let 
      val _ = debug_search "mc_node_find"
      val (pid,pripol) = mc_node_find 0 
    in
      if is_notactive pid
      then (backup_fail pid; try_mc_find ())
      else (debug_search ("Find " ^ int_to_string pid); (pid,pripol))
    end

(* ---------------------------------------------------------------------------
   Closing proofs
   -------------------------------------------------------------------------- *)

fun children_of pid =
  let val prec = dfind pid (!proofdict) in !(#children prec) end

fun descendant_of pid =
  let val cidl = children_of pid in
    cidl @ List.concat (map descendant_of cidl)
  end

fun close_descendant pid = app node_delete (descendant_of pid)

exception ProofFound

fun close_proof cid pid =
  let
    val crec = dfind cid (!proofdict)
    val prec = dfind pid (!proofdict)
    val {pargn = gn, parstac = stac,...} = crec
    val {proofl,pending,parid,children,visit,trydict,priorpolicy,...} = prec
  in
    (* checking some assertions *)
    if !pending <> [] then () else debug_err "close_proof: pending";
    if valOf gn = hd (!pending) then () else debug_err "close_proof";
    (* remember which child gave the proof of which goal *)
    proofl := (valOf gn, valOf stac, cid) :: !proofl;
    (* saves the child that gave the proof *)
    node_save cid; 
    (* close all current  children *)
    close_descendant pid; 
    (* switching to next pending goal, erasing previous statistics *)
    children := [];
    trydict := dempty (list_compare goal_compare);
    pending := tl (!pending);
    (* optional reinitialization of the evaluation function *)
    if !hhs_evalinit_flag then init_eval (!priorpolicy) pid else ();
    (* check if the goal was solved and recursively close *)
    if null (!pending)
    then
      if parid = NONE (* special case when it's root *)
      then (debug_search "proof"; 
            node_save pid; node_delete pid; raise ProofFound)
      else close_proof pid (valOf parid)
    else ()
  end

(* --------------------------------------------------------------------------
   Creating new nodes
   -------------------------------------------------------------------------- *)

fun node_create_gl pripol tactime gl pid =
  let
    val prec = dfind pid (!proofdict)
    val gn = hd (! (#pending prec))
    val goal = Array.sub (#goalarr prec, gn)
    val prev_predl = Array.sub (#predarr prec, gn)
    val stac = hd prev_predl
    val parchildren = #children prec
    val parchildrensave = Array.sub (#childrena prec,gn)
    val depth = #depth prec + 1
    val predlist = map (add_hammer o add_metis o !stacpredictor_glob) gl  
    val pending = rev (map fst (number_list 0 predlist))
    (* Updating list of parents *)
    val new_pardict = dadd goal () (#pardict prec)
    (* New node *)
    val selfid = 
      node_create pripol 
        tactime pid stac gn goal gl predlist pending new_pardict
  in
    parchildren := selfid :: (!parchildren);
    parchildrensave := selfid :: (!parchildrensave);
    selfid
  end

(* fake a node when a proof is found but no search is performed on this node *)
fun node_create_empty staco tactime pid =
  let
    val prec = dfind pid (!proofdict)
    val gn   = hd (! (#pending prec))
    val goal = Array.sub (#goalarr prec, gn)
    val pred = Array.sub (#predarr prec, gn)
    val stac = 
      case staco of 
        NONE => hd pred
      | SOME s => s         
    val parchildren = #children prec
    val parchildrensave = Array.sub (#childrena prec,gn)
    val selfid = node_create 0.0 tactime pid stac gn goal [] [] [] 
                   (dempty goal_compare)
  in
    parchildren := selfid :: (!parchildren);
    parchildrensave := selfid :: (!parchildrensave);
    selfid
  end

(* pid should be active and the goal should match *)
fun close_proof_wrap staco tactime pid =
  let val cid = node_create_timer (node_create_empty staco tactime) pid in
    backup cid;
    close_proof cid pid
  end


(* --------------------------------------------------------------------------
   Handling asynchronously calls
   -------------------------------------------------------------------------- *) 

fun current_goal pid = 
  let 
    val prec = dfind pid (!proofdict)
    val gn   = hd (!(#pending prec))
  in
    Array.sub (#goalarr prec, gn)
  end

(* Opening a thread *)
fun hammer_call pid g = 
  (
  case !hammer_glob (!hammer_ref) g of 
    NONE      => Array.update (async_result,pid,HFailure)
  | SOME stac => Array.update (async_result,pid,HSuccess (stac,g))
  )
  handle _ => Array.update (async_result,pid,HFailure)
(* add a debug message here *)

fun fork_hammer () = 
  if null (dkeys (!install_async)) then () else
  let
    val pid = hd (dkeys (!install_async)) 
    val _ = install_async := drem pid (!install_async)
    val _ = incr hammer_ref
    val _ = debug_search ("new thread " ^ int_to_string pid)
    val file = hhs_code_dir ^ "/hammer" ^ int_to_string (!hammer_ref)
    val thread = 
      Thread.Thread.fork (fn () => hammer_call pid (current_goal pid), [])
  in
    running_async := dadd pid thread (!running_async);
    Array.update (async_result,pid,HRunning thread)
  end

fun open_async () =
  if dlength (!running_async) < !hhs_async_limit 
  then 
    let 
      val n = dlength (!running_async) 
      val m = length (filter (Thread.Thread.isActive o snd) 
        (dlist (!running_async)))
    in
      debug_search (int_to_string n ^ " running thread"); 
      debug_search (int_to_string m ^ " active thread"); 
      fork_hammer ()
    end
  else ()

(* Closing all successfull threads in increasing order of pid *)

fun close_async () = 
  let 
    val pidl = dkeys (!running_async) 
    fun f pid = case Array.sub (async_result,pid) of
      HSuccess(stac,g) => 
      (
      debug_search ("success thread " ^ int_to_string pid);
      running_async := drem pid (!running_async);
      Array.update (async_result,pid,HVoid);
      if is_active pid andalso current_goal pid = g
        then close_proof_wrap (SOME stac) 0.0 pid
        else ()
      )
    | HFailure => 
      (
      debug_search ("failure thread " ^ int_to_string pid);
      Array.update (async_result,pid,HVoid);
      running_async := drem pid (!running_async)
      )
    | _ => ()
  in
    app f pidl
  end

(* ---------------------------------------------------------------------------
   Search function. Modifies the proof state.
   -------------------------------------------------------------------------- *)

fun init_search thmpredictor stacpredictor mcpredictor hammer tacdict g =
  (
  (* async *)
  init_async ();
  (* global time-out *)
  glob_timer := SOME (Timer.startRealTimer ());
  (* caching *)
  stacgoal_cache := dempty stacgoal_compare;
  thml_dict := dempty (cpl_compare goal_compare Int.compare);
  inst_dict := dempty (cpl_compare String.compare goal_compare);
  (* proof states *)
  pid_counter := 0;
  notactivedict := dempty Int.compare;
  proofdict    := dempty Int.compare;
  finproofdict := dempty Int.compare; (* should be removed *)
  (* easier access to values *)
  stacpredictor_glob := predict_timer stacpredictor;
  thmpredictor_glob := thmpredict_timer thmpredictor;
  mcpredictor_glob := mc_timer mcpredictor;
  hammer_glob := hammer;
  tacdict_glob := tacdict;
  (* statistics *)
  reset_timers ();
  stac_counter := 0;
  max_depth_mem := 0
  )

fun get_next_pred pid =
  let
    val _ = debug_search "get_next_pred"
    val prec = dfind pid (!proofdict)
  in
    if null (!(#pending prec)) then () else
      let
        val gn   = hd (!(#pending prec))
        val pred = Array.sub (#predarr prec, gn)
      in
        if null pred orelse null (tl pred)  
          then deactivate pid
          else Array.update (#predarr prec, gn, tl pred)
      end
  end

fun node_find () = 
  let
    val _ = debug_search "node_find"
    val l0 = filter (fn x => is_active (fst x)) (dlist (!proofdict))
    (* also deactivate node with empty predictions *)
    val l1 = filter (fn x => not (has_empty_pred (fst x))) l0
    val _ = if !hhs_hhhammer_flag then (close_async (); open_async ()) else ()
    val l2 = if !hhs_hhhammer_flag 
             then filter (fn x => is_active (fst x)) l1
             else l1
    val _ = if null l2 then (debug_search "nonexttac"; raise NoNextTac) else ()
  in
    try_mc_find ()
  end


fun search_step () =
  let
    val (pid,pripol) = node_find_timer node_find ()
    val prec = dfind pid (!proofdict)
    val trydict = #trydict prec
    val (glo,tactime) = add_time apply_next_stac pid
    fun f0 () = (backup_fail pid; get_next_pred pid)
    fun f1 gl =
      if gl = []
      then 
        (backup_success pid; 
         close_proof_wrap NONE tactime pid)
      else
        (
        trydict := dadd gl () (!trydict);
        let val cid = 
          node_create_timer (node_create_gl pripol tactime gl) pid
        in
          backup cid; get_next_pred pid
        end
        )
  in
    case glo of
      NONE    => f0 ()
    | SOME gl => f1 gl
  end

datatype proof_status_t = 
  ProofError | ProofSaturated | ProofTimeOut | Proof of string

fun search_loop () =
  (
  if Timer.checkRealTimer (valOf (!glob_timer)) > (!hhs_search_time)
    then ProofTimeOut
  else if dmem 0 (!finproofdict) then Proof ""
  else (search_step (); debug_search "search step"; search_loop ())
  )
  handle NoNextTac => (debug_search "saturated"; ProofSaturated)
       | SearchTimeOut => (debug_search "timeout"; ProofTimeOut)
       | ProofFound => (debug_search "prooffound"; Proof "")
       | e => raise e

fun proofl_of pid =
  let
    val prec = dfind pid (!finproofdict) handle _ => debug_err "proofl_of"
    fun compare_gn ((gn1,_,_),(gn2,_,_)) = Int.compare (gn1,gn2)
    val proofl = !(#proofl prec)
    val new_proofl = dict_sort compare_gn proofl
    fun f (gn,stac,cid) = 
      let 
        val g = Array.sub (#goalarr prec, gn)
        val contl = proofl_of cid
        val tac = Tactic (stac,g)
      in
        if null contl then tac
        else if List.length contl = 1 then Then (tac, hd contl)
        else Thenl (tac, contl)
      end
  in
    map f new_proofl
  end

fun end_search () =
  (
  debug_proof ("Statistics");
  debug_proof ("  infstep : " ^ int_to_string (!stac_counter));
  debug_proof ("  nodes   : " ^ int_to_string (!pid_counter));
  debug_proof ("  maxdepth: " ^ int_to_string (!max_depth_mem));
  debug_proof ("Time: " ^ Real.toString (!tot_time));
  debug_proof ("  inferstep time: " ^ Real.toString (!infstep_time));
  debug_proof ("  node_find time: " ^ Real.toString (!node_find_time));
  debug_proof ("  node_crea time: " ^ Real.toString (!node_create_time));
  debug_proof ("    pred time: " ^ Real.toString (!predict_time));
  debug_proof ("    thmpred time: " ^ Real.toString (!thmpredict_time));
  debug_proof ("    mc time: " ^ Real.toString (!mc_time));   
  debug_proof ("    inst time: " ^ Real.toString (!inst_time));
  proofdict    := dempty Int.compare;
  finproofdict := dempty Int.compare;
  tacdict_glob := dempty String.compare;
  stacgoal_cache := dempty stacgoal_compare
  )

(* ---------------------------------------------------------------------------
   Self learning
   -------------------------------------------------------------------------- *)

fun selflearn_aux proof = case proof of 
    Tactic (stac,g) =>
      (
      let
        val ((gl,_),t) = add_time (tactic_of_sml stac) g
        val lbl = (stac,t,g,gl) 
      in
        update_tacdata lbl
      end
      handle _ => debug_search ("Error: selflearn: " ^ stac)
      )
  | Then (p1,p2) => (selflearn_aux p1; selflearn_aux p2)
  | Thenl (p,pl) => (selflearn_aux p; app selflearn_aux pl)

fun selflearn proof =
  if !hhs_selflearn_flag 
  then debug_t "selflearn" selflearn_aux proof
  else ()

(* ---------------------------------------------------------------------------
   Main
   -------------------------------------------------------------------------- *)

fun imperative_search 
  thmpredictor stacpredictor mcpredictor hammer tacdict goal =
  (
  init_search thmpredictor stacpredictor mcpredictor hammer tacdict goal;
  total_timer (node_create_timer root_create_wrap) goal;
  let
    val r = total_timer search_loop ()
    val _ = debug_search "End search loop"
    val _ = terminate_async ()
    val _ = debug_search "After termination"
    val sproof_status = case r of
      Proof _  =>
      (
      if dmem 0 (!finproofdict) then
        let 
          val proofl = proofl_of 0 handle _ => debug_err "SNH0"
          val proof = 
            if length proofl <> 1 
            then debug_err "SNH1"
            else (selflearn (hd proofl); minimize_proof (hd proofl))
          val sproof = debug_t "reconstruct" reconstruct goal proof
        in
          Proof sproof
        end
      else debug_err "SNH2"
      )
    | _ => r
  in
    end_search (); (* reset references *)
    sproof_status
  end
  )

end (* struct *)
