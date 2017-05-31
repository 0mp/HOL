structure buildcline :> buildcline =
struct

open buildcline_dtype GetOpt

type 'a cline_result = { update : (string -> unit) * 'a -> 'a }

local
  open FunctionalRecordUpdate
  fun makeUpdateT z = makeUpdate7 z
in
fun updateT z = let
  fun from build_theory_graph help jobcount kernelspec relocbuild selftest
           seqname =
    {build_theory_graph = build_theory_graph,
     help = help,
     jobcount = jobcount,
     kernelspec = kernelspec,
     relocbuild = relocbuild,
     selftest = selftest,
     seqname = seqname}
  fun from' seqname selftest relocbuild kernelspec jobcount help
            build_theory_graph =
    {build_theory_graph = build_theory_graph,
     help = help,
     jobcount = jobcount,
     kernelspec = kernelspec,
     relocbuild = relocbuild,
     selftest = selftest,
     seqname = seqname}
  fun to f {build_theory_graph, help, jobcount, kernelspec, relocbuild,
            selftest, seqname} =
    f build_theory_graph help jobcount kernelspec relocbuild selftest seqname
in
  makeUpdateT (from, from', to)
end z
val U = U
val $$ = $$
end (* local *)

fun mkBool sel (b:bool) =
  NoArg (fn () => { update = fn (wn,t) => updateT t (U sel b) $$ })
fun mkBoolOpt sel (b:bool) =
  NoArg (fn () => { update = fn (wn,t) => updateT t (U sel (SOME b)) $$ })

fun mkInt nm sel =
  ReqArg ((fn s => { update = fn (wn,t) =>
             case Int.fromString s of
                 NONE => (wn ("Couldn't read integer from "^s); t)
               | SOME i => if i < 0 then
                             (wn ("Ignoring negative number for "^nm); t)
                           else
                             updateT t (U sel i) $$ }),
          "int")
fun mkIntOpt nm sel =
  ReqArg ((fn s => { update = fn (wn,t) =>
             case Int.fromString s of
                 NONE => (wn ("Couldn't read integer from "^s); t)
               | SOME i => if i < 0 then
                             (wn ("Ignoring negative number for "^nm); t)
                           else updateT t (U sel (SOME i)) $$ }),
          "int")

val optSelftestInt = let
  fun doit i_s (wn,t) =
    case Int.fromString i_s of
        NONE => (wn ("Couldn't read integer from "^i_s); t)
      | SOME i => if i < 0 then
                    (wn "Ignoring negative number for selftest level"; t)
                  else
                    updateT t (U #selftest i) $$
in
  OptArg ((fn sopt =>
              case sopt of
                  NONE => {update = doit "1"}
                | SOME i_s => {update = doit i_s}), "int")
end

val setSeqNameOnce =
  ReqArg ((fn s => { update = fn (wn,t) =>
             (case #seqname t of
                 NONE => ()
               | SOME _ =>
                 wn "Multiple sequence specs; ignoring earlier spec(s)";
              updateT t (U #seqname (SOME s)) $$) }),
          "fname")

fun setKname k =
  NoArg (fn () =>
            { update =
              fn (wn,t) =>
                 (case #kernelspec t of
                      NONE => ()
                    | SOME _ => wn "Multiple kernel specs; \
                                   \ignoring earlier spec(s)";
                  updateT t (U #kernelspec (SOME k)) $$) })

val cline_opt_descrs = [
  {help = "build with experimental kernel", long = ["expk"], short = "",
   desc = setKname "--expk"},
  {help = "build a theory dependency graph", long = ["graph"], short = "",
   desc = mkBoolOpt #build_theory_graph true},
  {help = "build with full sequence", long = ["fullbuild"], short = "F",
   desc = NoArg (fn () => {
     update = fn (wn,t) =>
       (case #seqname t of
           NONE => ()
         | SOME _ => wn "Multiple sequence specs; ignoring earlier spec(s)";
        updateT t (U #seqname (SOME "")) $$) })},

  {help = "display help", long = ["help", "h"], short = "h?",
   desc = mkBool #help true},
  {help = "specify concurrency limit", long = [], short = "j",
   desc = mkIntOpt "-j" #jobcount},
  {help = "don't build a thy dep. graph", long = ["nograph"], short = "",
   desc = mkBoolOpt #build_theory_graph false},
  {help = "build with logging kernel", long = ["otknl"], short = "",
   desc = setKname "--otknl"},
  {help = "do relocation build (e.g., after a cleanForReloc)",
   long = ["relocbuild"], short = "",
   desc = mkBool #relocbuild true},
  {help = "specify selftest level (default = 1)", long = ["selftest"],
   short = "t",
   desc = optSelftestInt},
  {help = "build this directory sequence", long = ["seq"], short = "",
   desc = setSeqNameOnce},
  {help = "build with standard kernel", long = ["stdknl"], short = "",
   desc = setKname "--stdknl"}
]

end (* struct *)
