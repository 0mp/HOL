(*---------------------------------------------------------------------------------*)
(*      Simple Examples                                                            *) 
(*      No precedure call is presented in these examples                           *)
(*---------------------------------------------------------------------------------*)
val hol_dir = "/home/tt291/hol98/";
loadPath := (concat hol_dir "examples/dev/sw") :: 
            !loadPath;

use (concat hol_dir "examples/dev/sw/compiler");

(*---------------------------------------------------------------------------------*)
(*      Single Blocks                                                              *)
(*      The ShiftXor procedure appearing in TEA                                    *)
(*---------------------------------------------------------------------------------*)

val ShiftXor_def =
 Define
   `ShiftXor (x:word32,s,k0,k1) = ((x << 4) + k0) ?? (x + s) ?? ((x >> 5) + k1)`;

(*
- val spec = pp_compile ShiftXor_def;
|- !st.
          get_st
            (run_arm
               [((LSL,NONE,F),SOME (REG 4),[REG 0; WCONST 4w],NONE);
                ((ADD,NONE,F),SOME (REG 2),[REG 4; REG 2],NONE);
                ((ADD,NONE,F),SOME (REG 1),[REG 0; REG 1],NONE);
                ((EOR,NONE,F),SOME (REG 1),[REG 2; REG 1],NONE);
                ((ASR,NONE,F),SOME (REG 0),[REG 0; WCONST 5w],NONE);
                ((ADD,NONE,F),SOME (REG 0),[REG 0; REG 3],NONE);
                ((EOR,NONE,F),SOME (REG 0),[REG 1; REG 0],NONE)]
               ((0,0w,st),{}))<MR R0> =
          ShiftXor (st<MR R0>,st<MR R1>,st<MR R2>,st<MR R3>))

- extract_arm spec;
  Name              : ShiftXor
  Arguments         : (r0,(r1,(r2,r3)))
  Returns           : r0
  Body: 
    0:          lsl     r4, r0, #4iw
    1:          add     r2, r4, r2
    2:          add     r1, r0, r1
    3:          eor     r1, r2, r1
    4:          asr     r0, r0, #5iw
    5:          add     r0, r0, r3
    6:          eor     r0, r1, r0

*)

(*---------------------------------------------------------------------------------*)
(*      Single Conditional Jump                                                    *)
(*      "let" statements are supported                                             *)
(*---------------------------------------------------------------------------------*)

val cj_f_1_def = Define `
    cj_f_1 (a,b:word32) = 
       if a = 1w then 
            let e = a + b + 3w
            in e 
       else let c = a + b in 
            let d = c * c - a in
            d`;

(*
- val spec = pp_compile cj_f_1_def;
...
|- !st.
          get_st
            (run_arm
               [((CMP,NONE,F),NONE,[REG 0; WCONST 1w],NONE);
                ((B,SOME EQ,F),NONE,[],SOME (POS 5));
                ((ADD,NONE,F),SOME (REG 1),[REG 0; REG 1],NONE);
                ((MUL,NONE,F),SOME (REG 1),[REG 1; REG 1],NONE);
                ((SUB,NONE,F),SOME (REG 0),[REG 1; REG 0],NONE);
                ((B,SOME AL,F),NONE,[],SOME (POS 3));
                ((ADD,NONE,F),SOME (REG 0),[REG 0; REG 1],NONE);
                ((ADD,NONE,F),SOME (REG 0),[REG 0; WCONST 3w],NONE)]
               ((0,0w,st),{}))<MR R0> =
          cj_f_1 (st<MR R0>,st<MR R1>))

- extract_ir spec;
  Name              : cj_f_1
  Arguments         : (r0,r1)
  Returns           : r0
  Body: 
  CJ(r0 = #1w,
    [madd r0 r0 r1; madd r0 r0 #3w],
    [madd r1 r0 r1; mmul r1 r1 r1; msub r0 r1 r0])

- extract_arm spec;

  Name              : cj_f_1
  Arguments         : (r0,r1)
  Returns           : r0
  Body: 
    0:          cmp     r0, #1iw
    1:          beq     + (5)
    2:          add     r1, r0, r1
    3:          mul     r1, r1, r1
    4:          sub     r0, r1, r0
    5:          bal     + (3)
    6:          add     r0, r0, r1
    7:          add     r0, r0, #3iw
*)

(*---------------------------------------------------------------------------------*)
(*      Tail Recusive Functions                                                    *)
(*      Factorial Function. Form: SC (TR, BLK)                                     *) 
(*      This is the example 1 in the paper                                         *)
(*---------------------------------------------------------------------------------*)
val WORD_LO___MEASURE = store_thm ("WORD_LO___MEASURE",
  ``word_lo = measure w2n``,
  SIMP_TAC std_ss [FUN_EQ_THM, prim_recTheory.measure_def,
    relationTheory.inv_image_def, WORD_LO] );

val fact_def = Hol_defn "fact" 
   `fact (x:word32,a:word32) = if x=0w then a else fact(x-1w, x*a)`;

val (fact_def, fact_ind) =
Defn.tprove (fact_def,
  TotalDefn.WF_REL_TAC `inv_image $<+ (\(v1:word32,v2:word32). v1)` THENL [
    SIMP_TAC std_ss [WORD_LO___MEASURE, prim_recTheory.WF_measure],
    SIMP_TAC std_ss [WORD_LO, WORD_PRED_THM]
  ])

val fact_thm = Q.store_thm (
   "fact_thm",
   `fact = (\(x,a).a) o (WHILE ($~ o (\(x,a).x = 0w)) (\(x,a).(x-1w,x*a)))`,
   SIMP_TAC std_ss [FUN_EQ_THM, FORALL_PROD] THEN
   HO_MATCH_MP_TAC fact_ind THEN
   REPEAT STRIP_TAC THEN
   ONCE_REWRITE_TAC [fact_def, WHILE] THEN
   RW_TAC std_ss []
  );


(*
-   extra_defs := [fact_thm];
-   pp_compile fact_def;

   |- !st.
         get_st
           (run_arm
              [((CMP,NONE,F),NONE,[REG 0; WCONST 0w],NONE);
               ((B,SOME EQ,F),NONE,[],SOME (POS 6));
               ((SUB,NONE,F),SOME (REG 3),[REG 0; WCONST 1w],NONE);
               ((MUL,NONE,F),SOME (REG 2),[REG 0; REG 1],NONE);
               ((MOV,NONE,F),SOME (REG 0),[REG 3],NONE);
               ((MOV,NONE,F),SOME (REG 1),[REG 2],NONE);
               ((B,SOME AL,F),NONE,[],SOME (NEG 6));
               ((MOV,NONE,F),SOME (REG 2),[REG 1],NONE)]
              ((0,0w,st),{}))<MR R2> =
         fact (st<MR R0>,st<MR R1>) 


*)

(*---------------------------------------------------------------------------------*)
(*      Constants are replaced by simpler ones that can be represented             *)
(*---------------------------------------------------------------------------------*)

val const_1_def = Define `
    const_1 (x:word32) = (x + 0xFF0012Fw) - 0x1003w`;

pp_compile const_1_def;


(*---------------------------------------------------------------------------------*)
(*      before that a evaluation takes place                                       *)
(*---------------------------------------------------------------------------------*)

val const_2_def = Define `
    const_2 (x:word32) = (x + (0xFF0012Fw - 0x1003w))`;

pp_compile const_2_def;


(*---------------------------------------------------------------------------------*)
(*      commutativity is exploited                                                 *)
(*---------------------------------------------------------------------------------*)

val const_3_def = Define `
    const_3 (x:word32) = (1w + x)`;

pp_compile const_3_def;


(*---------------------------------------------------------------------------------*)
(*      multiplication examples                                                    *)
(*         no constants                                                            *)
(*         modified register allocation                                            *)
(*---------------------------------------------------------------------------------*)

val mul_1_def = Define `
    mul_1 (x:word32) = (x * 2w)`;

pp_compile mul_1_def;

val mul_2_def = Define `
    mul_2 (x:word32) = (x * x)`;

pp_compile mul_2_def;

(*---------------------------------------------------------------------------------*)
(*      Composition of various structures                                          *)
(*      "Let" statement is allowed                                                 *)
(*      This example has the form SC (BLK, CJ)                                     *)
(*      This is the example 2 in the paper                                         *)
(*---------------------------------------------------------------------------------*)

val cj_f_2_def = Define `
    cj_f_2 (a:word32,b:word32) = let c = a + 1w in
               if a = 1w then c else c + b`;

(*
pp_compile cj_f_2_def;

 |- !st.
          get_st
            (run_arm
               [((ADD,NONE,F),SOME (REG 2),[REG 0; WCONST 1w],NONE);
                ((CMP,NONE,F),NONE,[REG 0; WCONST 1w],NONE);
                ((B,SOME EQ,F),NONE,[],SOME (POS 3));
                ((ADD,NONE,F),SOME (REG 2),[REG 2; REG 1],NONE);
                ((B,SOME AL,F),NONE,[],SOME (POS 1))]
               ((0,0w,st),{}))<MR R2> =
          cj_f_2 (st<MR R0>,st<MR R1>))

  Name              : cj_f_2
  Arguments         : (r0,r1)
  Returns           : r2
  Body: 
    0:          add     r2, r0, #1iw
    1:          cmp     r0, #1iw
    2:          beq     + (3)
    3:          add     r2, r2, r1
    4:          bal     + (1)
*)


(*---------------------------------------------------------------------------------*)
(*      This example encounters a bug in the front end (CPS conversion)            *)
(*---------------------------------------------------------------------------------*)

(* A more complicated SC example.  Form: SC (BLK, SC (CJ, BLK))         *)
(* The ANF conversion seems wrong ???                                   *)

val f3_def = Define `
    f3 (a:word32,b:word32) = let c = a + 1w in
               let d = if a = 1w then b else a + b in
               let e = c - d in
               e 
`;

pp_compile ((SIMP_RULE std_ss [LET_THM]) f3_def)
toANF [] f3_def
(*
*)


(*---------------------------------------------------------------------------------*)
(*      See the "fc_examples.sml" for examples involving function calls            *)
(*---------------------------------------------------------------------------------*)

