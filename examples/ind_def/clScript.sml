open HolKernel Parse boolLib

open bossLib simpLib

infix THEN THENL THENC &&
infix 8 by

val _ = new_theory "cl";

val _ = Hol_datatype `cl = S | K | # of cl => cl`;

val _ = set_fixity "#"  (Infixl 1100);
val _ = set_MLname "#"  "HASH";

val _ = set_fixity "-->" (Infix(NONASSOC, 510));

val (redn_rules, redn_ind, redn_cases) =
  IndDefLib.Hol_reln `
    (!x y f. x --> y   ==>    f # x --> f # y) /\
    (!f g x. f --> g   ==>    f # x --> g # x) /\
    (!x y.   K # x # y --> x) /\
    (!f g x. S # f # g # x --> (f # x) # (g # x))`;

val redn_ind = CONV_RULE (RENAME_VARS_CONV ["P"]) redn_ind

val _ = app (uncurry set_MLname) [
          ("-->",       "redn"),
          ("-->_rules", "redn_rules"),
          ("-->_ind",   "redn_ind"),
          ("-->_cases", "redn_cases")
        ];

val _ = hide "RTC";

val (RTC_rules, RTC_ind, RTC_cases) =
  IndDefLib.Hol_reln `
    (!x.     RTC R x x) /\
    (!x y z. R x y /\ RTC R y z ==> RTC R x z)`;

val normform_def = Define `normform R x = !y. ~R x y`;

val confluent_def = Define`
  confluent R =
     !x y z. RTC R x y /\ RTC R x z ==>
             ?u. RTC R y u /\ RTC R z u`;

val confluent_normforms_unique = store_thm(
  "confluent_normforms_unique",
  ``!R. confluent R ==>
        !x y z. RTC R x y /\ normform R y /\ RTC R x z /\ normform R z
                  ==>
                (y = z)``,
  RW_TAC std_ss [confluent_def] THEN
  `?u. RTC R y u /\ RTC R z u` by PROVE_TAC [] THEN
  PROVE_TAC [normform_def, RTC_cases]);

val diamond_def = Define
    `diamond R = !x y z. R x y /\ R x z ==> ?u. R y u /\ R z u`;

val confluent_diamond_RTC = store_thm(
  "confluent_diamond_RTC",
  ``!R. confluent R = diamond (RTC R)``,
  RW_TAC std_ss [confluent_def, diamond_def]);

val R_RTC_diamond = store_thm(
  "R_RTC_diamond",
  ``!R. diamond R ==>
         !x p. RTC R x p ==>
               !z. R x z ==>
                   ?u. RTC R p u /\ RTC R z u``,
  GEN_TAC THEN STRIP_TAC THEN HO_MATCH_MP_TAC RTC_ind THEN
  REPEAT STRIP_TAC THENL [
    PROVE_TAC [RTC_rules],
    `?v. R y v /\ R z' v` by PROVE_TAC [diamond_def] THEN
    PROVE_TAC [RTC_rules]
  ]);

val RTC_RTC = store_thm(
  "RTC_RTC",
  ``!R x y z. RTC R x y /\ RTC R y z ==> RTC R x z``,
  SIMP_TAC std_ss [GSYM AND_IMP_INTRO, RIGHT_FORALL_IMP_THM] THEN
  GEN_TAC THEN HO_MATCH_MP_TAC RTC_ind THEN REPEAT STRIP_TAC THEN
  PROVE_TAC [RTC_rules]);

val diamond_RTC_lemma = prove(
  ``!R.
       diamond R ==>
       !x y. RTC R x y ==> !z. RTC R x z ==>
                               ?u. RTC R y u /\ RTC R z u``,
  GEN_TAC THEN STRIP_TAC THEN HO_MATCH_MP_TAC RTC_ind THEN
  REPEAT STRIP_TAC THENL [
    PROVE_TAC [RTC_rules],
    `?v. RTC R y v /\ RTC R z' v` by PROVE_TAC [R_RTC_diamond] THEN
    PROVE_TAC [RTC_RTC, RTC_rules]
  ]);
val diamond_RTC = store_thm(
  "diamond_RTC",
  ``!R. diamond R ==> diamond (RTC R)``,
  PROVE_TAC [diamond_def,diamond_RTC_lemma]);

val strong' =
  SIMP_RULE std_ss []
  (GEN_ALL (BETA_RULE (Q.SPECL [`R`, `\x y. RTC R x y /\ P x y`] RTC_ind)));

val strong = prove(
  ``!R P. (!x. P x x) /\
          (!x y z. R x y /\ RTC R y z /\ P y z ==> P x z) ==>
          (!x y. RTC R x y ==> P x y)``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  HO_MATCH_MP_TAC strong' THEN REPEAT STRIP_TAC THEN
  PROVE_TAC [RTC_rules]);



val _ = set_fixity "-||->" (Infix(NONASSOC, 510));

val (predn_rules, predn_ind, predn_cases) =
    IndDefLib.Hol_reln
      `(!x. x -||-> x) /\
       (!x y u v. x -||-> y /\ u -||-> v ==> x # u -||-> y # v) /\
       (!x y. K # x # y -||-> x) /\
       (!f g x. S # f # g # x -||-> (f # x) # (g # x))`;

val predn_ind = CONV_RULE (RENAME_VARS_CONV ["P"]) predn_ind;

val _ = app (uncurry set_MLname) [
          ("-||->_rules", "predn_rules"),
          ("-||->_ind",   "predn_ind"),
          ("-||->_cases", "predn_cases")
  ];

val RTC_monotone = store_thm(
  "RTC_monotone",
  ``!R1 R2. (!x y. R1 x y ==> R2 x y) ==>
            (!x y. RTC R1 x y ==> RTC R2 x y)``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN HO_MATCH_MP_TAC RTC_ind THEN
  REPEAT STRIP_TAC THEN PROVE_TAC [RTC_rules]);

val _ = set_fixity "-->*" (Infix(NONASSOC, 510));

val RTCredn_def = xDefine "RTCredn" `$-->* = RTC $-->`;

val _ = set_fixity "-||->*" (Infix(NONASSOC, 510));

val RTCpredn_def = xDefine "RTCpredn" `$-||->* = RTC $-||->`;

val RTCredn_rules  = REWRITE_RULE[SYM RTCredn_def] (Q.ISPEC `$-->` RTC_rules)
val RTCredn_ind    = REWRITE_RULE[SYM RTCredn_def] (Q.ISPEC `$-->` RTC_ind)
val RTCpredn_rules = REWRITE_RULE[SYM RTCpredn_def](Q.ISPEC `$-||->` RTC_rules)
val RTCpredn_ind   = REWRITE_RULE[SYM RTCpredn_def](Q.ISPEC `$-||->` RTC_ind)
;

val RTCredn_RTCpredn = store_thm(
  "RTCredn_RTCpredn",
  ``!x y. x -->* y   ==>   x -||->* y``,
  SIMP_TAC std_ss [RTCredn_def, RTCpredn_def] THEN
  HO_MATCH_MP_TAC RTC_monotone THEN
  HO_MATCH_MP_TAC redn_ind THEN
  PROVE_TAC [predn_rules]);

val RTCredn_ap_monotonic = store_thm(
  "RTCredn_ap_monotonic",
  ``!x y. x -->* y ==> !z. x # z -->* y # z /\ z # x -->* z # y``,
  HO_MATCH_MP_TAC RTCredn_ind THEN PROVE_TAC [RTCredn_rules, redn_rules]);

val RTCredn_RTCredn = save_thm(
  "RTCredn_RTCredn",
  SIMP_RULE std_ss [SYM RTCredn_def] (Q.ISPEC `$-->` RTC_RTC));

val predn_RTCredn = store_thm(
  "predn_RTCredn",
  ``!x y. x -||-> y  ==>  x -->* y``,
  HO_MATCH_MP_TAC predn_ind THEN
  PROVE_TAC [RTCredn_rules,redn_rules,RTCredn_RTCredn,RTCredn_ap_monotonic]);


val RTCpredn_RTCredn = store_thm(
  "RTCpredn_RTCredn",
  ``!x y. x -||->* y   ==>  x -->* y``,
  HO_MATCH_MP_TAC RTCpredn_ind THEN
  PROVE_TAC [predn_RTCredn, RTCredn_RTCredn, RTCredn_rules]);

val RTCpredn_EQ_RTCredn = store_thm(
  "RTCpredn_EQ_RTCredn",
  ``$-||->* = $-->*``,
  CONV_TAC FUN_EQ_CONV THEN GEN_TAC THEN
  CONV_TAC FUN_EQ_CONV THEN GEN_TAC THEN
  PROVE_TAC [RTCpredn_RTCredn, RTCredn_RTCpredn]);

val cl_11 = TypeBase.one_one_of "cl";
val cl_distinct0 = TypeBase.distinct_of "cl";
val cl_distinct =
 CONJ cl_distinct0 (ONCE_REWRITE_RULE [EQ_SYM_EQ] cl_distinct0);

fun characterise t = SIMP_RULE std_ss [cl_11,cl_distinct] (SPEC t predn_cases);

val K_predn = characterise ``K``;
val S_predn = characterise ``S``;
val Sx_predn0 = characterise ``S # x``;

val Sx_predn = prove(
  ``!x y. S # x -||-> y = ?z. (y = S # z) /\ (x -||-> z)``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  RW_TAC std_ss [Sx_predn0, predn_rules, S_predn]);

val Kx_predn = prove(
  ``!x y. K # x -||-> y = ?z. (y = K # z) /\ (x -||-> z)``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  RW_TAC std_ss [characterise ``K # x``, predn_rules, K_predn]);

val Kxy_predn = prove(
  ``!x y z. K # x # y -||-> z =
            (?u v. (z = K # u # v) /\ (x -||-> u) /\ (y -||-> v)) \/
            (z = x)``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  RW_TAC std_ss [characterise ``K # x # y``, predn_rules,
                 Kx_predn]);


val Sxy_predn = prove(
  ``!x y z. S # x # y -||-> z =
            ?u v. (z = S # u # v) /\ (x -||-> u) /\ (y -||-> v)``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  RW_TAC std_ss [characterise ``S # x # y``, predn_rules,
                 S_predn, Sx_predn]);

val Sxyz_predn = prove(
  ``!w x y z. S # w # x # y -||-> z =
              (?p q r. (z = S # p # q # r) /\
                       w -||-> p /\ x -||-> q /\ y -||-> r) \/
              (z = (w # y) # (x # y))``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  RW_TAC std_ss [characterise ``S # w # x # y``, predn_rules, Sxy_predn]);

val x_ap_y_predn = characterise ``x # y``;

val predn_strong_ind =
  IndDefRules.derive_strong_induction (CONJUNCTS predn_rules, predn_ind)

val predn_diamond_lemma = prove(
  ``!x y. x -||-> y ==>
          !z. x -||-> z ==> ?u. y -||-> u /\ z -||-> u``,
  HO_MATCH_MP_TAC predn_strong_ind THEN REPEAT CONJ_TAC THENL [
    PROVE_TAC [predn_rules],
    REPEAT STRIP_TAC THEN
    Q.PAT_ASSUM `x # y -||-> z`
      (STRIP_ASSUME_TAC o SIMP_RULE std_ss [x_ap_y_predn]) THEN
    RW_TAC std_ss [] THEN
    TRY (PROVE_TAC [predn_rules]) THENL [
      `?w. (y = K # w) /\ (z -||-> w)` by PROVE_TAC [Kx_predn] THEN
      RW_TAC std_ss [] THEN PROVE_TAC [predn_rules],
      `?p q. (y = S # p # q) /\ (f -||-> p) /\ (g -||-> q)` by
         PROVE_TAC [Sxy_predn] THEN
      RW_TAC std_ss [] THEN PROVE_TAC [predn_rules]
    ],
    RW_TAC std_ss [Kxy_predn] THEN PROVE_TAC [predn_rules],
    RW_TAC std_ss [Sxyz_predn] THEN PROVE_TAC [predn_rules]
  ]);

val predn_diamond = store_thm(
  "predn_diamond",
  ``diamond $-||->``,
  PROVE_TAC [diamond_def, predn_diamond_lemma]);

val confluent_redn = store_thm(
  "confluent_redn",
  ``confluent $-->``,
  PROVE_TAC [predn_diamond, RTCpredn_def,
             RTCredn_def, confluent_diamond_RTC,
             RTCpredn_EQ_RTCredn, diamond_RTC]);


val _ = export_theory();
