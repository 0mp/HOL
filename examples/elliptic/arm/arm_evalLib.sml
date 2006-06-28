(* ========================================================================= *)
(* FILE          : arm_evalLib.sml                                           *)
(* DESCRIPTION   : Code for evaluating the I/O free ARM specification        *)
(*                                                                           *)
(* AUTHOR        : (c) Anthony Fox, University of Cambridge                  *)
(* DATE          : 2006                                                      *)
(* ========================================================================= *)

structure arm_evalLib :> arm_evalLib =
struct

(* interactive use:
  app load ["wordsLib", "computeLib", "pred_setSimps", "arm_evalTheory",
            "assemblerML", "instructionTheory", "instructionSyntax"];
*)

open HolKernel boolLib bossLib;
open Q Parse computeLib pairTheory wordsTheory wordsSyntax
     optionTheory rich_listTheory armTheory arm_evalTheory
     bsubstTheory instructionTheory instructionSyntax assemblerML;

(* ------------------------------------------------------------------------- *)
(* Some conversions *)

val SUC2NUM = CONV_RULE numLib.SUC_TO_NUMERAL_DEFN_CONV;

fun add_rws f rws =
let val cmp_set = f()
    val _ = add_thms rws cmp_set
in cmp_set end;

val SUC_RULE = CONV_RULE numLib.SUC_TO_NUMERAL_DEFN_CONV;

fun NUM_ONLY_RULE n x =
  let val y = SPEC_ALL x
  in CONJ
      ((GEN_ALL o INST [n |-> `0`]) y)
      ((GEN_ALL o INST [n |-> `NUMERAL n`]) y)
  end;

fun WORD_ONLY_RULE n x =
  let val y = SPEC_ALL x
  in CONJ
      ((GEN_ALL o CONV_RULE (RHS_CONV EVAL_CONV) o INST [n |-> `0w`]) y)
      ((GEN_ALL o INST [n |-> `n2w (NUMERAL n)`]) y)
  end;

val EXTRACT_RULE1 = SIMP_RULE std_ss [w2w_def,word_extract_def];
val EXTRACT_RULE2 = CONV_RULE (CBV_CONV (wordsLib.words_compset()));

fun arm_compset () = add_rws wordsLib.words_compset
  [FST,SND,SUC_RULE EL,HD,TL,MAP,FILTER,LENGTH,ZIP,FOLDL,
   SUC_RULE rich_listTheory.GENLIST,rich_listTheory.SNOC,
   SUC_RULE rich_listTheory.FIRSTN,combinTheory.K_THM,
   register_EQ_register,num2register_thm,register2num_thm,
   mode_EQ_mode,mode2num_thm,mode_case_def,
   psrs_EQ_psrs,psrs2num_thm,
   iclass_EQ_iclass,iclass2num_thm,
   exceptions_EQ_exceptions,exceptions2num_thm,exceptions_case_def,
   num2exceptions_thm,exceptions2mode_def,
   num2condition_thm,condition2num_thm,condition_case_def,
   interrupts_case_def,
   SUBST_EVAL,

   SET_NZC_def,NZCV_def,USER_def,mode_num_def,
   EXTRACT_RULE1 DECODE_IFMODE_SET_NZCV,DECODE_NZCV_SET_NZCV,
   EXTRACT_RULE1 DECODE_IFMODE_SET_IFMODE,DECODE_NZCV_SET_IFMODE,
   SET_NZCV_IDEM,SET_IFMODE_IDEM,SET_IFMODE_NZCV_SWP,
   DECODE_PSR_def,DECODE_MODE_def,DECODE_PSR_THM,
   CPSR_READ_def,CPSR_WRITE_def,SPSR_READ_def,SPSR_WRITE_def,
   CPSR_WRITE_n2w,SPSR_WRITE_n2w,mode_reg2num_def,mode2psr_def,
   REG_READ_def,REG_WRITE_def,INC_PC_def,FETCH_PC_def,REG_READ6_def,
   word_modify_PSR,word_modify_PSR2,
   ALU_arith_def,ALU_arith_neg_def,ALU_logic_def,SUB_def,ADD_def,
   AND_def,EOR_def,ORR_def,ALU_def,
   LSL_def,LSR_def,ASR_def,ROR_def,
   WORD_ONLY_RULE `ireg` CONDITION_PASSED_def,CONDITION_PASSED2_def,
   DECODE_INST_THM,

   ZIP,FOLDL,
   state_inp_accessors, state_inp_updates_eq_literal,
   state_inp_accfupds, state_inp_fupdfupds, state_inp_literal_11,
   state_inp_fupdfupds_comp, state_inp_fupdcanon,
   state_inp_fupdcanon_comp,
   state_out_accessors, state_out_updates_eq_literal,
   state_out_accfupds, state_out_fupdfupds, state_out_literal_11,
   state_out_fupdfupds_comp, state_out_fupdcanon,
   state_out_fupdcanon_comp,
   transfer_options_accessors, transfer_options_updates_eq_literal,
   transfer_options_accfupds, transfer_options_fupdfupds,
   transfer_options_literal_11, transfer_options_fupdfupds_comp,
   transfer_options_fupdcanon, transfer_options_fupdcanon_comp,
   state_arm_case_def,shift_case_def,

   DECODE_BRANCH_THM,DECODE_DATAP_THM,DECODE_MRS_THM,
   DECODE_MSR_THM,DECODE_LDR_STR_THM,DECODE_SWP_THM,
   DECODE_LDM_STM_THM,DECODE_MLA_MUL_THM,DECODE_LDC_STC_THM,
   DECODE_PSRD_def, CONDITION_PASSED3_def,
   IS_REG_SHIFT_def, IS_DP_IMMEDIATE_def,
   IS_DT_SHIFT_IMMEDIATE_def, IS_MSR_IMMEDIATE_def,

   cond_pass_enc_br, cond_pass_enc_coproc, cond_pass_enc_swp,
   cond_pass_enc_data_proc, cond_pass_enc_data_proc2, cond_pass_enc_data_proc3,
   cond_pass_enc_ldm_stm, cond_pass_enc_ldr_str, cond_pass_enc_mla_mul,
   cond_pass_enc_mrs, cond_pass_enc_msr, cond_pass_enc_swi,

   decode_enc_br, decode_enc_coproc, decode_enc_swp,
   decode_enc_data_proc, decode_enc_data_proc2, decode_enc_data_proc3,
   decode_enc_ldm_stm, decode_enc_ldr_str, decode_enc_mla_mul,
   decode_enc_mrs, decode_enc_msr, decode_enc_swi,

   decode_br_enc, decode_ldc_stc_enc, decode_mrc_enc,
   decode_data_proc_enc, decode_data_proc_enc2, decode_data_proc_enc3,
   decode_ldm_stm_enc, decode_ldr_str_enc, decode_mla_mul_enc,
   decode_mrs_enc, decode_msr_enc, decode_swp_enc,

   EXTRACT_RULE2 immediate_enc, EXTRACT_RULE2 immediate_enc2,
   EXTRACT_RULE2 shift_immediate_enc, EXTRACT_RULE2 shift_immediate_enc2,
   EXTRACT_RULE2 shift_immediate_shift_register,
   EXTRACT_RULE2 shift_register_enc, EXTRACT_RULE2 shift_register_enc2,

   CARRY_def,BW_READ_def,
   SHIFT_IMMEDIATE2_def,SHIFT_REGISTER2_def,
   NUM_ONLY_RULE `opnd2` SHIFT_IMMEDIATE_THM,
   NUM_ONLY_RULE `opnd2` SHIFT_REGISTER_THM,
   WORD_ONLY_RULE `opnd2` IMMEDIATE_def,
   ALU_multiply_def,ARITHMETIC_def,TEST_OR_COMP_def,UP_DOWN_def,
   ADDR_MODE1_def,ADDR_MODE2_def,ADDR_MODE4_def,ADDR_MODE5_def,
   REGISTER_LIST_THM,ADDRESS_LIST_def,FIRST_ADDRESS_def,WB_ADDRESS_def,
   LDM_LIST_def,STM_LIST_def,

   EXCEPTION_def,BRANCH_def,DATA_PROCESSING_def,MRS_def,LDR_STR_def,
   MLA_MUL_def,SWP_def,MRC_def,MCR_OUT_def,MSR_def,LDM_STM_def,LDC_STC_def,

   SIMP_RULE (std_ss++pred_setSimps.PRED_SET_ss) []
      interrupt2exceptions_def,
   IS_Dabort_def,IS_Reset_def,PROJ_Dabort_def,PROJ_Reset_def,
   THE_DEF,IS_SOME_DEF,IS_NONE_EQ_NONE,NOT_IS_SOME_EQ_NONE,
   option_case_ID,option_case_SOME_ID,
   option_case_def,SOME_11,NOT_SOME_NONE,PROJ_IF_FLAGS_def,
   EXEC_INST_def,NEXT_ARM_def,OUT_ARM_def];

fun arm_eval_compset () =
  add_rws arm_compset
    [state_arme_accessors, state_arme_updates_eq_literal,memop_case_def,
     state_arme_accfupds, state_arme_fupdfupds, state_arme_literal_11,
     state_arme_fupdfupds_comp, state_arme_fupdcanon,state_arme_fupdcanon_comp,
     ADDR30_def,SET_BYTE_def,BSUBST_EVAL,
     MEM_WRITE_BYTE_def,MEM_WRITE_WORD_def,MEM_WRITE_def,TRANSFERS_def,
     SIMP_RULE (bool_ss++pred_setSimps.PRED_SET_ss) [] NEXT_ARMe_def];

val ARM_CONV = CBV_CONV (arm_eval_compset());
val ARM_RULE = CONV_RULE ARM_CONV;

val EVAL_SUBST_CONV =
let val compset = add_rws reduceLib.num_compset
          [register_EQ_register,register2num_thm,SUBST_EVAL]
in
  computeLib.CBV_CONV compset
end;

val SORT_SUBST_CONV = let open arm_evalTheory
  val compset = add_rws reduceLib.num_compset
        [register_EQ_register,register2num_thm,psrs_EQ_psrs,psrs2num_thm,
         SYM Sa_def,Sab_EQ,Sa_RULE4,Sb_RULE4,Sa_RULE_PSR,Sb_RULE_PSR,
         combinTheory.o_THM]
in
  computeLib.CBV_CONV compset THENC PURE_REWRITE_CONV [Sa_def,Sb_def]
    THENC SIMP_CONV (srw_ss()) [SUBST_EQ2,SUBST_EVAL]
end;

val SORT_BSUBST_CONV = let open arm_evalTheory
  val compset = add_rws wordsLib.words_compset
        [LENGTH,SUC2NUM JOIN,SUC2NUM BUTFIRSTN,
         APPEND,SUBST_BSUBST,BSa_RULE,BSb_RULE,
         GSYM BSa_def,combinTheory.o_THM]
in
  computeLib.CBV_CONV compset THENC PURE_REWRITE_CONV [BSa_def,BSb_def]
end;

val FOLD_SUBST_CONV =
let val compset = add_rws wordsLib.words_compset
      [SET_IFMODE_def,SET_NZCV_def,FOLDL,arm_evalTheory.SUBST_EVAL,
       mode_num_def,mode_case_def,register_EQ_register,register2num_thm,
       psrs_EQ_psrs,psrs2num_thm]
in
  computeLib.CBV_CONV compset THENC SORT_SUBST_CONV
end;

val ARM_ASSEMBLE_CONV = let open instructionTheory
  val compset = add_rws wordsLib.words_compset
       [transfer_options_accessors,transfer_options_updates_eq_literal,
        transfer_options_accfupds,transfer_options_fupdfupds,
        transfer_options_literal_11,transfer_options_fupdfupds_comp,
        transfer_options_fupdcanon,transfer_options_fupdcanon_comp,
        condition2num_thm,arm_instruction_case_def,addr_mode1_case_def,
        addr_mode2_case_def,msr_mode_case_def,condition_encode_def,
        shift_encode_def,addr_mode1_encode_def,addr_mode2_encode_def,
        msr_mode_encode_def,msr_psr_encode_def,options_encode_def,
        instruction_encode_def,combinTheory.K_THM,
        SET_NZCV_def,SET_IFMODE_def,mode_num_def,mode_case_def]
in
  computeLib.CBV_CONV compset
end;

val rhsc = rhs o concl;
val lhsc = lhs o concl;
val fdest_comb = fst o dest_comb;
val sdest_comb = snd o dest_comb;

fun printn s = print (s ^ "\n");

fun findi p l =
  let fun findin _ [] _ = NONE
        | findin p (h::t) n =
            if p h then SOME n else findin p t (n + 1)
  in
    findin p l 0
  end;

fun mapi f l =
  let fun m f [] i = []
        | m f (h::t) i = (f(i, h))::m f t (i + 1)
  in
    m f l 0
  end;

local
  fun take_dropn(l,n) a =
        if n = 0 then (rev a,l)
        else
          case l of
            [] => raise Subscript
          | (h::t) => take_dropn(t,n - 1) (h::a)
in
  fun take_drop(l,n) = take_dropn(l,n) []
end;

(* ------------------------------------------------------------------------- *)
(* Syntax *)

fun mk_word30 n = mk_n2w(numSyntax.mk_numeral n,``:i30``);
fun mk_word32 n = mk_n2w(numSyntax.mk_numeral n,``:i32``);

fun eval_word t = (numSyntax.dest_numeral o rhsc o FOLD_SUBST_CONV o mk_w2n) t;

val subst_tm  = prim_mk_const{Name = ":-",  Thy = "arm"};
val bsubst_tm = prim_mk_const{Name = "::-", Thy = "arm"};

fun mk_subst (a,b,m) =
   list_mk_comb(inst[alpha |-> type_of a,beta |-> type_of b] subst_tm,[a,b,m])
   handle HOL_ERR _ => raise ERR "mk_subst" "";

fun mk_bsubst (a,b,m) =
   list_mk_comb(inst[alpha |-> dim_of a,beta |-> listSyntax.eltype b]
     bsubst_tm,[a,b,m])
   handle HOL_ERR _ => raise ERR "mk_subst" "";

val dest_subst  = dest_triop subst_tm  (ERR "dest_word_slice" "");
val dest_bsubst = dest_triop bsubst_tm (ERR "dest_word_slice" "");

local
  fun do_dest_subst_reg t a =
        let val (i,d,m) = dest_subst t in
          do_dest_subst_reg m
              (if isSome (List.find (fn a => term_eq (fst a) i) a) then a
               else ((i,d)::a))
        end handle HOL_ERR _ => (``ARB:register``,t)::a;

  fun do_dest_subst_mem t a =
       let val (i,d,m) = dest_bsubst t in
          do_dest_subst_mem m ((i,fst (listSyntax.dest_list d))::a)
       end handle HOL_ERR _ =>
         let val (i,d,m) = dest_subst t in
            do_dest_subst_mem m ((i,[d])::a)
         end handle HOL_ERR _ => (``ARB:register``,[t])::(rev a);
in
  fun dest_subst_reg t = do_dest_subst_reg t []
  fun dest_subst_mem t = do_dest_subst_mem t []
end;

fun get_reg l rest r =
      case List.find (fn a => term_eq (fst a) r) l of
        SOME (x,y) => y
      | _ => (rhsc o EVAL_SUBST_CONV o mk_comb) (rest,r);

fun get_pc t =
 let val regs = dest_subst_reg t
     val l = tl regs
     val rest = snd (hd regs)
 in
   get_reg l rest ``r15``
 end;

datatype mode = USR | FIQ | IRQ | SVC | ABT | UND;

local
  val split_enum = (snd o strip_comb o sdest_comb o concl);
  val und_regs = split_enum armTheory.datatype_register;
  val (usr_regs,und_regs) = take_drop(und_regs,16)
  val (fiq_regs,und_regs) = take_drop(und_regs,7)
  val (irq_regs,und_regs) = take_drop(und_regs,2)
  val (svc_regs,und_regs) = take_drop(und_regs,2)
  val (abt_regs,und_regs) = take_drop(und_regs,2)

  fun mode2int m =
    case m of
      USR => 0
    | FIQ => 1
    | IRQ => 2
    | SVC => 3
    | ABT => 4
    | UND => 5;

  fun mode_compare(a,b) = Int.compare(mode2int a, mode2int b);

  fun rm_duplicates (h1::h2::l) =
        if h1 = h2 then rm_duplicates (h2::l)
        else h1::(rm_duplicates (h2::l))
    | rm_duplicates l = l;

  fun print_reg l rest r =
        (print_term r; print "="; print_term (get_reg l rest r); print "; ");

  fun print_usr_reg l rest n =
        if n <= 15 then
          print_reg l rest (List.nth(usr_regs,n))
        else ();

  fun print_fiq_reg l rest n =
        if 8 <= n andalso n <= 14 then
          (print_reg l rest (List.nth(fiq_regs,n - 8)))
        else ();

  fun print_irq_reg l rest n =
        if 12 < n andalso n < 15 then
          (print_reg l rest (List.nth(irq_regs,n - 13)))
        else ();

  fun print_svc_reg l rest n =
        if 12 < n andalso n < 15 then
          (print_reg l rest (List.nth(svc_regs,n - 13)))
        else ();

  fun print_abt_reg l rest n =
        if 12 < n andalso n < 15 then
          (print_reg l rest (List.nth(abt_regs,n - 13)))
        else ();

  fun print_und_reg l rest n =
        if 12 < n andalso n < 15 then
          (print_reg l rest (List.nth(und_regs,n - 13)))
        else ();
  
  fun mode2printer m =
    case m of
      USR => print_usr_reg
    | FIQ => print_fiq_reg
    | IRQ => print_irq_reg
    | SVC => print_svc_reg
    | ABT => print_abt_reg
    | UND => print_und_reg;

  val all_modes = [USR,FIQ,IRQ,SVC,ABT,UND];

  fun pprint_regs p t =
        let val regs = dest_subst_reg t
            val l = tl regs
            val rest = snd (hd regs)
        in
          for_se 0 15 (fn i =>
            let val newline =
               foldl (fn (m,e) => if p (i,m) then
                                    ((mode2printer m) l rest i; true)
                                  else e) false all_modes
            in
              if newline then print "\n" else ()
            end)
        end
in
  val print_all_regs = pprint_regs (K true);
  val print_usr_regs = pprint_regs (fn (i,m) => m = USR);
  val print_std_regs = pprint_regs (fn (i,m) => (m = USR) orelse (m = UND));
  fun print_regs l = pprint_regs (fn x => mem x l);
end;

local
  fun compute_bound (t, tl) =
  let open Arbnum
      val n4 = fromInt 4
      val l = eval_word t
  in
    (l, l + fromInt (Int.-(length tl, 1)))
  end;

  fun get_blocki bounds n =
    findi (fn (x,y) => Arbnum.<=(x, n) andalso Arbnum.<=(n, y)) bounds;

  fun get_mem_val blocks rest bounds n =
         case get_blocki bounds n of
           SOME i => List.nth(List.nth(blocks, i),
                       Arbnum.toInt (Arbnum.-(n, fst (List.nth(bounds, i)))))
         | NONE   => (rhsc o EVAL_SUBST_CONV o mk_comb) (rest,mk_word30 n)
in
  fun read_mem_range m start n =
  let val dm = dest_subst_mem m
      val rest = hd (snd (hd (dm)))
      val bounds = map compute_bound (tl dm)
      val blocks = map snd (tl dm)
      val sa = Arbnum.div(start,Arbnum.fromInt 4)
      val f = get_mem_val blocks rest bounds
      val n4 = Arbnum.fromInt 4
  in
    List.tabulate(n, fn i => let val x = Arbnum.+(sa, Arbnum.fromInt i) in
                                 (Arbnum.*(x, n4), f x) end)
  end
end;

fun read_mem_block m n =
  let open Arbnum
      val dm = List.nth(dest_subst_mem m, n)
      val sa = eval_word (fst dm)
      val bl = snd dm
      val n4 = fromInt 4
      val addrs = List.tabulate(length bl, fn i => (sa + fromInt i) * n4)
  in
     zip addrs bl
  end;

fun mem_val_to_string(n, t) =
  "0x" ^ Arbnum.toHexString n ^ ": " ^
  (let val (l, r) = dest_comb t in
    if term_eq l ``enc`` then
      dest_instruction (SOME n) r
    else
      term_to_string t
   end handle HOL_ERR _ => term_to_string t);

fun print_mem_range m (start, n) =
  app printn (map mem_val_to_string (read_mem_range m start n));

fun print_mem_block m n =
  app printn (map mem_val_to_string (read_mem_block m n))
  handle HOL_ERR _ => ();

type arm_state = {mem : term, psrs : term, reg : term, undef : term};

fun dest_arm_eval t =
  case snd (TypeBase.dest_record t) of
     [("registers", reg), ("psrs", psrs),
      ("memory", mem), ("undefined", undef)] =>
         {mem = mem, reg = reg, psrs = psrs, undef = undef}
  | _ => raise ERR "dest_arm_eval" "";

(* ------------------------------------------------------------------------- *)

fun hol_assemble m a l = let
  val code = map (rhsc o ARM_ASSEMBLE_CONV o
                  (curry mk_comb ``instruction_encode``) o Term) l
  val block = listSyntax.mk_list(code,``:word32``)
in
  rhsc (SORT_BSUBST_CONV (mk_bsubst(mk_word30 a,block,m)))
end;

fun hol_assemble1 m a t = hol_assemble m a [t];

local
  fun add1 a = Data.add32 a Arbnum.one;
  fun div4 a = Arbnum.div(a,Arbnum.fromInt 4);
  fun mul4 a = Arbnum.*(a,Arbnum.fromInt 4);
  val start = Arbnum.zero;

  fun label_table() =
    Polyhash.mkPolyTable
      (100,HOL_ERR {message = "Cannot find ARM label\n",
                    origin_function = "", origin_structure = "arm_evalLib"});

  fun mk_links [] ht n = ()
    | mk_links (h::r) ht n =
        case h of
          Data.Code c => mk_links r ht (add1 n)
        | Data.BranchS b => mk_links r ht (add1 n)
        | Data.BranchN b => mk_links r ht (add1 n)
        | Data.Label s =>
            (Polyhash.insert ht (s, "0x" ^ Arbnum.toHexString (mul4 n));
             mk_links r ht n)
        | Data.Mark m => mk_links r ht (div4 m);

  fun mk_link_table code = let val ht = label_table() in
    mk_links code ht start; ht
  end;

  fun br_to_term (cond,link,label) ht n =
    let val s = assembler_to_string NONE (Data.BranchS(cond,link,"")) NONE
        val address = Polyhash.find ht label
    in
      mk_instruction ("0x" ^ Arbnum.toHexString (mul4 n) ^ ": " ^ s ^ address)
    end;

  fun mk_enc t = if type_of t = ``:word32`` then t else mk_comb(``enc``, t);

  fun is_label (Data.Label s) = true | is_label _ = false;

  fun lcons h [] = [[h]]
    | lcons h (x::l) = (h::x)::l;

  fun do_link m l [] ht n = zip m l
    | do_link m l (h::r) ht n =
        case h of
           Data.Code c =>
             do_link m (lcons (mk_enc (arm_to_term (validate_instruction c))) l)
               r ht (add1 n)
         | Data.BranchS b =>
             do_link m (lcons (mk_enc (br_to_term b ht n)) l) r ht (add1 n)
         | Data.BranchN b =>
             let val t = mk_enc (arm_to_term (branch_to_arm b (mul4 n))) in
               do_link m (lcons t l) r ht (add1 n)
             end
         | Data.Label s => do_link m l r ht n
         | Data.Mark mk => let val k = div4 mk in
               if k = n then
                 do_link m l r ht n
               else if null (hd l) then
                 do_link (k::(tl m)) l r ht k
               else
                 do_link (k::m) ([]::l) r ht k
             end;

  fun do_links code =
        let val l = do_link [start] [[]] code (mk_link_table code) start in
          rev (map (fn (a,b) => (a,rev b)) l)
        end;

  fun assemble_assambler m a = let
    val l = do_links a
    val b = map (fn (m,c) => (mk_word30 m,listSyntax.mk_list(c,``:word32``))) l
    val t = foldr (fn ((a,c),t) => mk_bsubst(a,c,t)) m b
  in
    rhsc (SORT_BSUBST_CONV t)
  end
in
  fun assemble m file = assemble_assambler m (parse_arm file);
  fun list_assemble m l =
    let val nll = String.concat (map (fn s => s ^ "\n") l)
        val c = substring(nll,0,size nll - 1)
    in
      assemble_assambler m
        (parse_arm_buf "" BasicIO.std_in (Lexing.createLexerString c))
    end;
  fun assemble1 m t = list_assemble m [t];
end;

(* ------------------------------------------------------------------------- *)
(* Funtions for memory loading and saving *)

local
  fun bytes2num (b0,b1,b2,b3) =
    let open Arbnum
        val byte2num = fromInt o Char.ord o Byte.byteToChar
    in
      (byte2num b0) * (fromInt 16777216) + (byte2num b1) * (fromInt 65536) +
      (byte2num b2) * (fromInt 256) + byte2num b3
    end

  fun read_word (v,i) =
    let val l = Word8Vector.length v
        fun f i = if i < l then Word8Vector.sub(v,i) else 0wx0
    in
      mk_word32 (bytes2num (f i, f (i + 1), f (i + 2), f (i + 3)))
      (* could change order to do little-endian *)
    end
in
  fun load_mem fname skip top_addr m =
    let open BinIO
        val istr = openIn fname
        val data = inputAll istr
        val _ = closeIn istr
        val lines = (Word8Vector.length data - skip) div 4
        val l = List.tabulate(lines, fn i => read_word (data,4 * i + skip))
        val lterm = listSyntax.mk_list(l,``:word32``)
    in
      rhsc (SORT_BSUBST_CONV (mk_bsubst(mk_word30 top_addr,lterm,m)))
    end
end;

fun mem_read m a = (eval_word o rhsc o ARM_CONV) (mk_comb(m,mk_word30 a));

fun save_mem fname start finish le m = let open BinIO Arbnum
    fun bits  h l n = (n mod pow(two,plus1 h)) div (pow(two,l))
    val ostr = openOut fname
    val num2byte = Word8.fromInt o Arbnum.toInt;
    fun num2bytes w =
          map (fn (i,j) => num2byte (bits (fromInt i) (fromInt j) w))
              ((if le then rev else I) [(31,24),(23,16),(15,8),(7,0)])
    fun save_word i = map (fn b => output1(ostr,b)) (num2bytes (mem_read m i))
    fun recurse i =
          if Arbnum.<=(i,finish) then recurse (save_word i; Arbnum.plus1 i)
          else closeOut ostr
in
  recurse start
end;

(* ------------------------------------------------------------------------- *)
(* Set the general purpose and program status registers *)

val foldl_tm =
  ``FOLDL (\m (r:'a,v:'b). if v = m r then m else (r :- v) m) x y``;

fun set_registers reg rvs  =
 (rhsc o FOLD_SUBST_CONV o
  subst [``x:reg`` |-> reg, ``y:(register # word32) list`` |-> rvs] o
  inst [alpha |-> ``:register``, beta |-> ``:word32``]) foldl_tm;

fun set_status_registers psr rvs  = (rhsc o
  (FOLD_SUBST_CONV
     THENC PURE_ONCE_REWRITE_CONV [SPEC `n2w n` arm_evalTheory.PSR_CONS]
     THENC ARM_CONV) o
  subst [``x:psr`` |-> psr, ``y:(psrs # word32) list`` |-> rvs] o
  inst [alpha |-> ``:psrs``, beta |-> ``:word32``]) foldl_tm;

(* ------------------------------------------------------------------------- *)
(* Running the model *)

fun init m r s =
   (PURE_ONCE_REWRITE_CONV [CONJUNCT1 STATE_ARMe_def] o
    subst [``mem:mem`` |-> m, ``reg:reg`` |-> r, ``psr:psr`` |-> s])
   ``STATE_ARMe 0 <| registers := reg; psrs :=  psr;
                     memory := mem; undefined := F |>``;

fun next t =
let val t1 = rhsc t
    val t2 = ((ARM_CONV THENC
                 ONCE_DEPTH_CONV (RAND_CONV (RAND_CONV SORT_BSUBST_CONV)) THENC
                 ONCE_DEPTH_CONV (RATOR_CONV SORT_SUBST_CONV) THENC
                 ONCE_DEPTH_CONV (RAND_CONV (RATOR_CONV SORT_SUBST_CONV)) THENC
                 RATOR_CONV ARM_ASSEMBLE_CONV) o
                 subst [``s:state_arme`` |-> t1]) ``NEXT_ARMe s``
  in
     numLib.REDUCE_RULE (MATCH_MP STATE_ARMe_NEXT (CONJ t t2))
  end;

fun done t = term_eq T (#undef (dest_arm_eval (rhsc t)));

fun state _ _ [] = []
  | state (tmr,prtr) n (l as (t::ts)) =
      if n = 0 then l
      else
        let val _ = prtr (dest_arm_eval (rhsc t))
            val nl = (tmr next t) :: l
        in
          if done t then nl else state (tmr,prtr) (n - 1) nl
        end;

fun fstate (tmr,prtr) n s =
  if n = 0 then s
   else
     let val _ = prtr (dest_arm_eval (rhsc s))
         val ns = tmr next s
     in
       if done s then ns else fstate (tmr,prtr) (n - 1) ns
     end;

fun pc_ptr (x : arm_state) =
  let val pc = eval_word (get_pc (#reg x))
  in
    print_mem_range (#mem x) (pc, 1)
  end;

fun eval n m r s = state (time,pc_ptr) n [init m r s];
fun evaluate n m r s = fstate (A,pc_ptr)  n (init m r s);

(* ------------------------------------------------------------------------- *)

fun myprint sys (pg,lg,rg) d pps t = let
      open Portable term_pp_types
      val (l,typ) = listSyntax.dest_list t
      val _ = typ = ``:word32`` andalso not (null l) orelse raise UserPP_Failed
      fun delim act = case pg of
                        Prec(_, "CONS") => ()
                      | _ => act()
    in
      delim (fn () => (begin_block pps CONSISTENT 0;
                       add_string pps "[";
                       add_break pps (1,2);
                       begin_block pps CONSISTENT 0));
      app (fn x => (sys (Prec(0, "CONS"), Top, Top) (d - 1) x;
                    add_string pps ";"; add_newline pps))
          (List.take (l,length l - 1));
      sys (Prec(0, "CONS"), Top, Top) (d - 1) (last l);
      delim (fn () => (end_block pps;
                       add_break pps (1,0);
                       add_string pps "]";
                       end_block pps))
    end handle HOL_ERR _ => raise term_pp_types.UserPP_Failed;

val _ = temp_add_user_printer ({Tyop = "list", Thy = "list"}, myprint);

(* ------------------------------------------------------------------------- *)

end
