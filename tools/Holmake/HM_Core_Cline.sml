structure HM_Core_Cline :> HM_Core_Cline =
struct

local
  open FunctionalRecordUpdate
  fun makeUpdateT z = makeUpdate22 z
in
fun updateT z = let
  fun from debug do_logging dontmakes fast help hmakefile holdir includes
           interactive jobs keep_going no_action no_hmakefile no_lastmaker_check
           no_overlay
           no_prereqs opentheory quiet
           quit_on_failure rebuild_deps recursive verbose =
    {
      debug = debug, do_logging = do_logging, dontmakes = dontmakes,
      fast = fast, help = help, hmakefile = hmakefile, holdir = holdir,
      includes = includes, interactive = interactive, jobs = jobs,
      keep_going = keep_going,
      no_action = no_action, no_hmakefile = no_hmakefile,
      no_lastmaker_check = no_lastmaker_check, no_overlay = no_overlay,
      no_prereqs = no_prereqs, opentheory = opentheory,
      quiet = quiet, quit_on_failure = quit_on_failure,
      rebuild_deps = rebuild_deps, recursive = recursive, verbose = verbose
    }
  fun from' verbose recursive rebuild_deps quit_on_failure quiet opentheory
            no_prereqs
            no_overlay no_lastmaker_check no_hmakefile no_action keep_going
            jobs interactive
            includes holdir
            hmakefile help fast dontmakes do_logging debug =
    {
      debug = debug, do_logging = do_logging, dontmakes = dontmakes,
      fast = fast, help = help, hmakefile = hmakefile, holdir = holdir,
      includes = includes, interactive = interactive, jobs = jobs,
      keep_going = keep_going,
      no_action = no_action, no_hmakefile = no_hmakefile,
      no_lastmaker_check = no_lastmaker_check, no_overlay = no_overlay,
      no_prereqs = no_prereqs, opentheory = opentheory,
      quiet = quiet, quit_on_failure = quit_on_failure,
      rebuild_deps = rebuild_deps, recursive = recursive, verbose = verbose
    }
  fun to f {debug, do_logging, dontmakes, fast, help, hmakefile, holdir,
            includes, interactive, jobs, keep_going, no_action, no_hmakefile,
            no_lastmaker_check,
            no_overlay, no_prereqs, opentheory,
            quiet, quit_on_failure, rebuild_deps, recursive, verbose} =
    f debug do_logging dontmakes fast help hmakefile holdir includes
      interactive jobs keep_going no_action no_hmakefile no_lastmaker_check
      no_overlay
      no_prereqs opentheory quiet
      quit_on_failure rebuild_deps recursive verbose
in
  makeUpdateT (from, from', to)
end z
val U = U
val $$ = $$
end (* local *)

type t = {
  debug : bool,
  do_logging : bool,
  dontmakes : string list,
  fast : bool,
  help : bool,
  hmakefile : string option,
  holdir : string option,
  includes : string list,
  interactive : bool,
  jobs : int,
  keep_going : bool,
  no_action : bool,
  no_hmakefile : bool,
  no_lastmaker_check : bool,
  no_overlay : bool,
  no_prereqs : bool,
  opentheory : string option,
  quiet : bool,
  quit_on_failure : bool,
  rebuild_deps : bool,
  recursive : bool,
  verbose : bool
}

val default_core_options : t =
{
  debug = false,
  do_logging = false,
  dontmakes = [],
  fast = false,
  help = false,
  hmakefile = NONE,
  holdir = NONE,
  includes = [],
  interactive = false,
  jobs = 4,
  keep_going = false,
  no_action = false,
  no_hmakefile = false,
  no_lastmaker_check = false,
  no_overlay = false,
  no_prereqs = false,
  opentheory = NONE,
  quiet = false,
  quit_on_failure = false,
  rebuild_deps = false,
  recursive = false,
  verbose = false
}

open GetOpt
fun mkBoolT sel = NoArg (fn () => fn (wn,t) => updateT t (U sel true) $$)
fun cons_dontmakes x (wn,t) = updateT t (U #dontmakes (x :: #dontmakes t)) $$
fun cons_includes x (wn,t) = updateT t (U #includes (x :: #includes t)) $$
fun change_jobs nstr (wn,t) =
  case Int.fromString nstr of
      NONE => (wn ("Couldn't parse "^nstr^" as a number; ignoring it"); t)
    | SOME n => if n < 1 then (wn "Ignoring non-positive job count"; t)
                else updateT t (U #jobs n) $$

fun set_hmakefile s (wn,t) =
  (if isSome (#hmakefile t) then
     wn "Multiple Holmakefile specs; ignoring earlier spec"
   else ();
   updateT t (U #hmakefile (SOME s)) $$)
fun set_holdir s (wn, t) =
  (if isSome (#holdir t) then
     wn "Multiple holdir specs; ignoring earlier spec"
   else ();
   updateT t (U #holdir (SOME s)) $$)
fun set_openthy s (wn, t) =
  (if isSome (#opentheory t) then
     wn "Multiple opentheory specs; ignoring earlier spec"
   else ();
   updateT t (U #opentheory (SOME s)) $$)
val core_option_descriptions = [
  { help = "turn on diagnostic messages", long = ["dbg", "d"], short = "",
    desc = mkBoolT #debug},
  { help = "don't make this target", long = [], short = "d",
    desc = ReqArg (cons_dontmakes, "target") },
  { help = "fast build (ignore tactic failure)", long = ["fast"], short = "",
    desc = mkBoolT #fast },
  { help = "show this message", long = ["help"], short = "h",
    desc = mkBoolT #help },
  { help = "use different HOLDIR", long = ["holdir"], short = "",
    desc = ReqArg (set_holdir, "directory") },
  { help = "use different holmakefile", long = ["holmakefile"], short = "",
    desc = ReqArg (set_hmakefile, "file") },
  { help = "make session 'interactive'", long = ["interactive"], short = "i",
    desc = mkBoolT #interactive },
  { help = "include directory", long = [], short = "I",
    desc = ReqArg (cons_includes, "directory") },
  { help = "max number of parallel jobs", long = ["jobs"], short = "j",
    desc = ReqArg (change_jobs, "n") },
  { help = "try to build all targets", long = ["keep-going"], short = "k",
    desc = mkBoolT #keep_going },
  { help = "enable time logging", long = ["logging"], short = "",
    desc = mkBoolT #do_logging },
  { help = "print what would be executed", long = ["no_action"], short = "n",
    desc = mkBoolT #no_action },
  { help = "don't use a Holmakefile", long = ["no_hmakefile"], short = "",
    desc = mkBoolT #no_hmakefile },
  { help = "don't check which Holmake was last used", long = ["nolmbc"],
    short = "", desc = mkBoolT #no_lastmaker_check },
  { help = "don't use Overlay.sml file", long = ["no_overlay"],
    short = "", desc = mkBoolT #no_overlay },
  { help = "don't build recursively in INCLUDES",
    long = ["no_prereqs"], short = "", desc = mkBoolT #no_prereqs },
  { help = "use file as opentheory logging .uo",
    long = ["ot"], short = "", desc = ReqArg (set_openthy, "file")},
  { help = "be quieter with output", short = "q", long = ["quiet"],
    desc = NoArg (fn () => fn (wn,t) =>
                     (if #verbose t then
                        wn "Quiet and verbose incompatible; taking verbose"
                      else () ;
                      updateT t (U #quiet true) $$)) },
  { help = "quit on failure", short = "", long = ["qof"],
    desc = mkBoolT #quit_on_failure },
  { help = "rebuild cached dependency files", short = "",
    long = ["rebuild_deps"], desc = mkBoolT #rebuild_deps },
  { help = "clean recursively", short = "r", long = [],
    desc = mkBoolT #recursive },
  { help = "verbose output", short = "v", long = ["verbose"],
    desc = NoArg (fn () => fn (wn,t) =>
                     (if #quiet t then
                        wn "Quiet and verbose incompatible; taking verbose"
                      else ();
                      updateT t (U #verbose true) $$)) }
]

fun descr_key (d:'a GetOpt.opt_descr) =
  str (String.sub(#short d, 0))
  handle Subscript => hd (#long d) handle Empty => ""

fun descr_compare (d1, d2) = String.compare(descr_key d1, descr_key d2)

fun sort_descriptions dl = Listsort.sort descr_compare dl


end
