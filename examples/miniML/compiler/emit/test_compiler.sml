open test_compilerLib
val e1 = ``Lit (IntLit 42)``
val [Number i] = run_exp e1
val SOME 42 = intML.toInt i;
(*val true = [OLit (IntLit (intML.fromInt 42))] = (pd [NTnum] e1 [])*)
val e2 = ``If (Lit (Bool T)) (Lit (IntLit 1)) (Lit (IntLit 2))``
val [Number i] = run_exp e2
val SOME 1 = intML.toInt i;
val e3 = ``If (Lit (Bool F)) (Lit (IntLit 1)) (Lit (IntLit 2))``
val [Number i] = run_exp e3
val SOME 2 = intML.toInt i;
val e4 = ``App Equality (Lit (IntLit 1)) (Lit (IntLit 2))``
val [Number i] = run_exp e4
val SOME 0 = intML.toInt i;
val e5 = ``Fun "x" (Var "x")``
val [f] = run_exp e5
(*val true = [OFn] = pd [NTfn] e5 []*)
val e6 = ``Let "x" (Lit (IntLit 1)) (App (Opn Plus) (Var "x") (Var "x"))``
val [Number i] = run_exp e6
val SOME 2 = intML.toInt i;
val e7 = ``Let "x" (Lit (IntLit 1))
             (Let "y" (Lit (IntLit 2))
                (Let "x" (Lit (IntLit 3))
                   (App (Opn Plus) (Var "x") (Var "y"))))``
val [Number i] = run_exp e7
val SOME 5 = intML.toInt i;
val e8 = ``
Let "0?" (Fun "x" (App Equality (Var "x") (Lit (IntLit 0))))
  (Let "x" (Lit (IntLit 1))
    (Let "x" (App (Opn Minus) (Var "x") (Var "x"))
      (App Opapp (Var "0?") (Var "x"))))``
val [Number i] = run_exp e8
val SOME 1 = intML.toInt i;
val e9 = ``
Let "1?" (Fun "x" (App Equality (Var "x") (Lit (IntLit 1))))
  (Let "x" (Lit (IntLit 1))
    (Let "x" (App (Opn Minus) (Var "x") (Var "x"))
      (App Opapp (Var "1?") (Var "x"))))``
val [Number i] = run_exp e9
val SOME 0 = intML.toInt i;
val e10 = ``
Let "x" (Lit (IntLit 3))
(If (App (Opb Gt) (Var "x") (App (Opn Plus) (Var "x") (Var "x")))
  (Var "x") (Lit (IntLit 4)))``
val [Number i] = run_exp e10
val SOME 4 = intML.toInt i;
val e11 = ``
Let "x" (Lit (IntLit 3))
(If (App (Opb Geq) (Var "x") (Var "x"))
  (Var "x") (Lit (IntLit 4)))``
val [Number i] = run_exp e11
val SOME 3 = intML.toInt i;
val e12 = ``
Let "lt2" (Fun "x" (App (Opb Lt) (Var "x") (Lit (IntLit 2))))
  (App Opapp (Var "lt2") (Lit (IntLit 3)))``
val [Number i] = run_exp e12
val SOME 0 = intML.toInt i;
val e13 = ``
Let "lq2" (Fun "x" (App (Opb Leq) (Var "x") (Lit (IntLit 2))))
  (App Opapp (Var "lq2") (Lit (IntLit 0)))``
val [Number i] = run_exp e13
val SOME 1 = intML.toInt i;
val e14 = ``
Let "x" (Lit (IntLit 0))
  (Let "y" (App (Opn Plus) (Var "x") (Lit (IntLit 2)))
    (If (App (Opb Geq) (Var "y") (Var "x"))
      (Var "x") (Lit (IntLit 4))))``
val [Number i] = run_exp e14
val SOME 0 = intML.toInt i;
val e15 = ``
Let "x" (Lit (Bool T))
(App Equality
  (Mat (Var "x")
    [(Plit (Bool F), (Lit (IntLit 1)));
     (Pvar "y", (Var "y"))])
  (Var "x"))``
val [Number i] = run_exp e15
val SOME 1 = intML.toInt i;
val e16 = ``App Equality (Let "x" (Lit (Bool T)) (Var "x")) (Lit (Bool F))``
val [Number i] = run_exp e16
val SOME 0 = intML.toInt i;
val e17 = ``App Equality
  (Let "f" (Fun "_" (Lit (Bool T))) (App Opapp (Var "f") (Lit (Bool T))))
  (Lit (Bool F))``
val [Number i] = run_exp e17
val SOME 0 = intML.toInt i;
val e18 = ``
Let "x" (Lit (Bool T))
  (App Equality
    (Let "f" (Fun "_" (Var "x")) (App Opapp (Var "f") (Var "x")))
    (Var "x"))``
val [Number i] = run_exp e18
val SOME 1 = intML.toInt i;
val e19 = ``
Let "x" (Lit (Bool T))
  (App Opapp (Fun "_" (Var "x")) (Lit (Bool F)))``
val [Number i] = run_exp e19
val SOME 1 = intML.toInt i;
val e20 = ``
Let "f" (Fun "_" (Lit (Bool T)))
(App Equality
  (App Opapp (Var "f") (Lit (Bool T)))
  (Lit (Bool F)))``
val [Number i] = run_exp e20
val SOME 0 = intML.toInt i;
val e21 = ``Let "x" (Lit (Bool T))
(App Equality
  (Let "f" (Fun "_" (Var "x"))
    (App Opapp (Var "f") (Var "x")))
  (Var "x"))``
val [Number i] = run_exp e21
val SOME 1 = intML.toInt i;
val listd = ``
Dtype
  [(["'a"],"list",
    [("Cons",[Tvar "'a"; Tapp [Tvar "'a"] "list"]); ("Nil",[])])]
``
val e22 = ``Con "Cons" [Lit (Bool T); Con "Nil" []]``
val [Block (t1,[Number i,Block (t2,[])])] = run_decs_exp ([listd],e22)
val SOME 0 = numML.toInt t1
val SOME 1 = intML.toInt i
val SOME 1 = numML.toInt t2;
val e23 = ``Mat (Con "Cons" [Lit (IntLit 2);
                 Con "Cons" [Lit (IntLit 3);
                 Con "Nil" []]])
            [(Pcon "Cons" [Pvar "x"; Pvar "xs"],
              Var "x");
             (Pcon "Nil" [],
              Lit (IntLit 1))]``
val [Number i] = run_decs_exp ([listd],e23)
val SOME 2 = intML.toInt i;
val e24 = ``Mat (Con "Nil" [])
            [(Pcon "Nil" [], Lit (Bool F))]``
val [Number i] = run_decs_exp([listd],e24)
val SOME 0 = intML.toInt i;
val e25 = ``Mat (Con "Cons" [Lit (IntLit 2);
                 Con "Nil" []])
            [(Pcon "Cons" [Pvar "x"; Pvar "xs"],
              Var "x")]``
val [Number i] = run_decs_exp([listd],e25)
val SOME 2 = intML.toInt i;
val e26 = ``Mat (Con "Cons" [Lit (IntLit 2);
                 Con "Nil" []])
            [(Pcon "Cons" [Plit (IntLit 2);
              Pcon "Nil" []],
              Lit (IntLit 5))]``
val [Number i] = run_decs_exp([listd],e26)
val SOME 5 = intML.toInt i;
(*val e27 = ``
CLetfun F [1] [([],CRaise Bind_error)]
(CLprim CIf [CPrim2 CEq (CLit (IntLit 0)) (CLit (IntLit 0)); CLit (IntLit 1); CCall (CVar 1) []])``
val c27 = term_to_bc_list(rhs(concl(computeLib.CBV_CONV compset ``REVERSE (compile ^s ^e27).code``)))
val [Number i] = g c27
val SOME 1 = intML.toInt i;*)
val e28 = ``
Letrec [("fac",("n",
  If (App Equality (Var "n") (Lit (IntLit 0)))
     (Lit (IntLit 1))
     (App (Opn Times)
       (Var "n")
       (App Opapp (Var "fac") (App (Opn Minus)
                                   (Var "n")
                                   (Lit (IntLit 1)))))))]
  (App Opapp (Var "fac") (Lit (IntLit 5)))``
val [Number i] = run_exp e28
val SOME 120 = intML.toInt i;
val d = ``Dlet (Pvar "Foo") (Lit (IntLit 42))``
val e41 = ``Var "Foo"``
val [Number i,Number j] = run_decs_exp([d],e41)
val SOME 42 = intML.toInt i;
val true = i = j;
val d = ``Dletrec [("I","x",(Var "x"))]``
val e42 = ``App Opapp (Var "I") (Lit (IntLit 42))``
val [Number i,cl] = run_decs_exp([d],e42)
val SOME 42 = intML.toInt i;
val d0 = ``
Dletrec
  [("N","v1",
    If (App (Opb Gt) (Var "v1") (Lit (IntLit 100)))
      (App (Opn Minus) (Var "v1") (Lit (IntLit 10)))
      (App Opapp (Var "N")
         (App Opapp (Var "N")
            (App (Opn Plus) (Var "v1") (Lit (IntLit 11))))))]
``
val e29 = ``App Opapp (Var "N") (Lit (IntLit 42))``
val [Number i,cl] = run_decs_exp([d0],e29)
val SOME 91 = intML.toInt i;
val e35 = ``Let "f" (Fun "x" (Fun "y" (App (Opn Plus) (Var "x") (Var "y")))) (App Opapp (App Opapp (Var "f") (Lit (IntLit 2))) (Lit (IntLit 3)))``
val [Number i] = run_exp e35
val SOME 5 = intML.toInt i;
val e36 = ``Letrec [("f", ("x", (Fun "y" (App (Opn Plus) (Var "x") (Var "y")))))] (App Opapp (App Opapp (Var "f") (Lit (IntLit 2))) (Lit (IntLit 3)))``
val [Number i] = run_exp e36
val SOME 5 = intML.toInt i;
val e37 = ``Letrec [("z", ("x", (Mat (Var "x") [(Plit (IntLit 0), (Var "x"));(Pvar "y", App Opapp (Var "z") (App (Opn Minus) (Var "x") (Var "y")))])))] (App Opapp (Var "z") (Lit (IntLit 5)))``
val [Number i] = run_exp e37
val SOME 0 = intML.toInt i;
val e38 = ``Let "z" (Fun "x" (Mat (Var "x") [(Plit (IntLit 0), (Var "x"));(Pvar "y", (App (Opn Minus) (Var "x") (Var "y")))])) (App Opapp (Var "z") (Lit (IntLit 5)))``
val [Number i] = run_exp e38
val SOME 0 = intML.toInt i;
val e39 = ``Letrec [("z", ("x", (Mat (Var "x") [(Plit (IntLit 0), (Var "x"));(Pvar "y", (App (Opn Minus) (Var "x") (Var "y")))])))] (App Opapp (Var "z") (Lit (IntLit 5)))``
val [Number i] = run_exp e39
val SOME 0 = intML.toInt i;
val paird = ``
Dtype [(["'a"; "'b"],"prod",[("Pair_type",[Tvar "'a"; Tvar "'b"])])]
``
(*
val _ = ml_translatorLib.translate listTheory.APPEND
val d0 = listd
val append_defs = ``
  [("APPEND","v3",
    Fun "v4"
      (Mat (Var "v3")
         [(Pcon "Nil" [],Var "v4");
          (Pcon "Cons" [Pvar "v2"; Pvar "v1"],
           Con "Cons"
             [Var "v2";
              App Opapp (App Opapp (Var "APPEND") (Var "v1"))
                (Var "v4")])]))] ``
val d1 = ``Dletrec ^append_defs``
val e33 = ``App Opapp (Var "APPEND") (Con "Nil" [])``
val (m,st) = pd1 e33 [d0,d1]
val tm = pv m (hd st) NTfn
val true = tm = OFn;
val e34 = ``App Opapp (App Opapp (Var "APPEND") (Con "Nil" []))
                      (Con "Nil" [])``
val (m,st) = pd1 e34 [d0,d1]
val [r,cl] = st
val tm = pv m r (NTapp ([NTnum],"list"))
val true = tm = OConv ("Nil",[])
val tm = pv m cl NTfn
val true = tm = OFn;
fun h t = hd(tl(snd(strip_comb(concl t))))
val t = ml_translatorLib.hol2deep ``[1;2;3]++[4;5;6:num]``
val e30 = h t
val (m,st) = pd1 e30 [d0,d1]
val [res,cl] = st
val tm = pv m res (NTapp ([NTnum],"list"))
val true = tm = term_to_ov (ml_translatorLib.hol2val ``[1;2;3;4;5;6:num]``);
val t = ml_translatorLib.hol2deep ``[]++[4:num]``
val e32 = h t
val (m,st) = pd1 e32 [d0,d1]
val [res,cl] = st
val tm = pv m res (NTapp ([NTnum],"list"))
val true = tm = OConv ("Cons",[OLit (IntLit (intML.fromInt 4)), OConv ("Nil",[])]);
val d2 = paird
val d3 = ``
Dletrec
  [("PART","v3",
    Fun "v4"
      (Fun "v5"
         (Fun "v6"
            (Mat (Var "v4")
               [(Pcon "Nil" [],Con "Pair_type" [Var "v5"; Var "v6"]);
                (Pcon "Cons" [Pvar "v2"; Pvar "v1"],
                 If (App Opapp (Var "v3") (Var "v2"))
                   (App Opapp
                      (App Opapp
                         (App Opapp (App Opapp (Var "PART") (Var "v3"))
                            (Var "v1"))
                         (Con "Cons" [Var "v2"; Var "v5"])) (Var "v6"))
                   (App Opapp
                      (App Opapp
                         (App Opapp (App Opapp (Var "PART") (Var "v3"))
                            (Var "v1")) (Var "v5"))
                      (Con "Cons" [Var "v2"; Var "v6"])))]))))]
`` val d4 = ``
Dlet (Pvar "PARTITION")
  (Fun "v1"
     (Fun "v2"
        (App Opapp
           (App Opapp
              (App Opapp (App Opapp (Var "PART") (Var "v1")) (Var "v2"))
              (Con "Nil" [])) (Con "Nil" []))))
`` val d5 = ``
Dletrec
  [("QSORT","v7",
    Fun "v8"
      (Mat (Var "v8")
         [(Pcon "Nil" [],Con "Nil" []);
          (Pcon "Cons" [Pvar "v6"; Pvar "v5"],
           Let "v3"
             (App Opapp
                (App Opapp (Var "PARTITION")
                   (Fun "v4"
                      (App Opapp (App Opapp (Var "v7") (Var "v4"))
                         (Var "v6")))) (Var "v5"))
             (Mat (Var "v3")
                [(Pcon "Pair_type" [Pvar "v2"; Pvar "v1"],
                  App Opapp
                    (App Opapp (Var "APPEND")
                       (App Opapp
                          (App Opapp (Var "APPEND")
                             (App Opapp
                                (App Opapp (Var "QSORT") (Var "v7"))
                                (Var "v2")))
                          (Con "Cons" [Var "v6"; Con "Nil" []])))
                    (App Opapp (App Opapp (Var "QSORT") (Var "v7"))
                       (Var "v1")))]))]))]
``
val _ = ml_translatorLib.translate sortingTheory.PART_DEF
val _ = ml_translatorLib.translate sortingTheory.PARTITION_DEF
val _ = ml_translatorLib.translate sortingTheory.QSORT_DEF
val t = ml_translatorLib.hol2deep ``QSORT (λx y. x ≤ y) [9;8;7;6;2;3;4;5:num]``
val e31 = h t;
val (m,st) = pd1 e31 [d0,d1,d2,d3,d4,d5]
val [res,clQSORT,clPARTITION,clPART,clAPPEND] = st
val tm = pv m res (NTapp([NTnum],"list"))
val true = tm = term_to_ov(ml_translatorLib.hol2val ``[2;3;4;5;6;7;8;9:num]``);
val d = ``
Dlet (Pvar "add1")
  (Fun "x" (App (Opn Plus) (Var "x") (Lit (IntLit 1))))``
val e40 = ``App Opapp (Var "add1") (Lit (IntLit 1))``
val (m,st) = pd1 e40 [d]
val [res,add1] = st
val true = pv m res NTnum = term_to_ov(ml_translatorLib.hol2val ``2:int``);
*)
val e43 = ``Letrec [("o","n",
  If (App Equality (Var "n") (Lit (IntLit 0)))
     (Var "n")
     (App Opapp
       (Var "o")
       (App (Opn Minus) (Var "n") (Lit (IntLit 1)))))]
  (App Opapp (Var "o") (Lit (IntLit 1000)))``
val (bs43,_) = prep_exp inits e43
val SOME s43 = bc_eval_limit 12 bs43
val [Number i] = bc_state_stack s43
val SOME 0 = intML.toInt i;
val d = ``Dletrec
[("o","n",
  If (App Equality (Var "n") (Lit (IntLit 0)))
     (Var "n")
     (App Opapp
       (Var "o")
       (App (Opn Minus) (Var "n") (Lit (IntLit 1)))))]``
val e44 = ``App Opapp (Var "o") (Lit (IntLit 1000))``
val [Number i, cl] = run_decs_exp ([d],e44)
val SOME 0 = intML.toInt i;
val d0 = paird
val d1 = ``Dlet (Pcon "Pair_type" [Pvar "x";Pvar "y"]) (Con "Pair_type" [Lit (IntLit 1);Lit (IntLit 2)])``
val d2 = ``Dlet (Pvar "x") (Lit (IntLit 3))``
val e45 = ``Con "Pair_type" [Var "x";Var "y"]``
val [Block (_,[Number xb,Number yb]),Number y,Number x] = run_decs_exp ([d0,d1,d2],e45)
val SOME 3 = intML.toInt x
val SOME 2 = intML.toInt y
val true = xb = x
val true = yb = y;
val d1 = ``Dlet (Pcon "Pair_type" [Pvar "y";Pvar "x"]) (Con "Pair_type" [Lit (IntLit 1);Lit (IntLit 2)])``
val d2 = ``Dlet (Pvar "x") (Lit (IntLit 3))``
val e46 = ``Con "Pair_type" [Var "x";Var "y"]``
val [Block (_,[Number xb,Number yb]),Number x,Number y] = run_decs_exp ([d0,d1,d2],e46)
val SOME 3 = intML.toInt xb
val SOME 1 = intML.toInt yb
val true = x = xb
val true = y = yb;
val d0 = paird
val d1 = ``Dlet (Pcon "Pair_type" [Pvar "x";Pvar "y"]) (Con "Pair_type" [Lit (IntLit 1);Lit (IntLit 2)])``
val d2 = ``Dlet (Pvar "x") (Lit (IntLit 3))``
val d3 = ``Dlet (Pvar "y") (Lit (IntLit 4))``
val e47 = ``Con "Pair_type" [
              Con "Pair_type" [Var "x"; Var "y"];
              Let "x" (Fun "x" (App (Opn Plus) (Var "x") (Var "y")))
                (App Opapp (Var "x") (Var "y"))]``
val [Block (_,[Block (_,[Number x3,Number y4]),Number yy]),Number y,Number x] = run_decs_exp([d0,d1,d2,d3],e47)
val SOME 4 = intML.toInt y
val SOME 3 = intML.toInt x
val SOME 3 = intML.toInt x3
val SOME 4 = intML.toInt y4
val SOME 8 = intML.toInt yy;
val d0 = ``Dlet (Pvar "x") (Let "x" (Lit (IntLit 1)) (App (Opn Minus) (Var "x") (Var "x")))``
val e48 = ``Var "x"``
val [Number xv,Number xd] = run_decs_exp([d0],e48)
val SOME 0 = intML.toInt xv
val SOME 0 = intML.toInt xd;
val d0 = ``Dlet (Pvar "x") (Let "x" (Lit (IntLit 1)) (App (Opn Minus) (Var "x") (Var "x")))``
val d1 = ``Dlet (Pvar "x") (App (Opn Minus) (Var "x") (Let "x" (Lit (IntLit 1)) (Var "x")))``
val e49 = ``App (Opn Times) (Var "x") (Let "x" (Lit (IntLit (-1))) (Var "x"))``
val [Number r,Number x] = run_decs_exp([d0,d1],e49)
val SOME ~1 = intML.toInt x
val SOME 1 = intML.toInt r;
val d0 = paird
val d1 = ``Dlet (Pcon "Pair_type" [Pvar "y";Pvar "x"]) (Con "Pair_type" [Lit (IntLit 1);Lit (IntLit 2)])``
val e50 = ``Var "y"``
val [Number r, Number x, Number y] = run_decs_exp([d0,d1],e50)
val SOME 2 = intML.toInt x
val SOME 1 = intML.toInt y
val true = r = y;
val d0 = ``Dlet (Pvar "x") (Lit (IntLit 1))``
val d1 = ``Dtype [([],"unit",[("()",[])])]``
val d2 = ``Dlet (Pvar "f") (Fun " " (Mat (Var " ") [(Pcon "()" [],App (Opn Plus) (Var "x") (Lit (IntLit 1)))]))``
val d3 = ``Dlet (Pvar "x") (Lit (IntLit 100))``
val e51 = ``App Opapp (Var "f") (Con "()" [])``
val [Number r, _, Number x] = run_decs_exp([d0,d1,d2,d3],e51)
val SOME 2 = intML.toInt r
val SOME 100 = intML.toInt x;
val d0 = paird
val e52 = ``Let "x" (Con "Pair_type" [Lit (IntLit 1);Lit (IntLit 2)])
  (Mat (Var "x")
      [(Pcon "Pair_type" [Pvar "x";Plit (IntLit 2)], Lit (IntLit 1))])``
val [Number r] = run_decs_exp([d0],e52)
val SOME 1 = intML.toInt r;
val d0 = paird
val e53 = ``Let "x" (Con "Pair_type" [Lit (IntLit 1);Con "Pair_type" [Lit (IntLit 2); Lit (IntLit 3)]])
  (Mat (Var "x")
      [(Pcon "Pair_type" [Pvar "x";Pcon "Pair_type" [Pvar "y";Pvar "z"]], Var "y")])``
val [Number r] = run_decs_exp([d0],e53)
val SOME 2 = intML.toInt r;
