quietdec := true;
app load ["Mosml", "Process", "Path", "FileSys", "Timer", "Real", "Int",
          "Bool"] ;
open Mosml;

(* utility functions *)
fun readdir s = let
  val ds = FileSys.openDir s
  fun recurse acc =
      case FileSys.readDir ds of
        NONE => acc
      | SOME s => recurse (s::acc)
in
  recurse [] before FileSys.closeDir ds
end;

fun mem x [] = false
  | mem x (h::t) = x = h orelse mem x t

fun frontlast [] = raise Fail "frontlast: failure"
  | frontlast [h] = ([], h)
  | frontlast (h::t) = let val (f,l) = frontlast t in (h::f, l) end;

(* returns a function of type unit -> int, which returns time elapsed in
   seconds since the call to start_timer() *)
fun start_timer() = let
  val timer = Timer.startRealTimer()
in
  fn () => let
       val time_now = Timer.checkRealTimer timer
     in
       Real.floor (Time.toReal time_now)
     end handle Time.Time => 0
end

(* busy loop sleeping *)
fun delay limit action = let
  val timer = start_timer()
  fun loop last = let
    val elapsed = timer()
  in
    if elapsed = last then loop last
    else (action elapsed; if elapsed >= limit then () else loop elapsed)
  end
in
  action 0; loop 0
end;

fun determining s =
    (print (s^" "); delay 1 (fn _ => ()));

(* action starts here *)
print "\nHOL smart configuration.\n\n";

print "Determining configuration parameters: ";
determining "OS";

val currentdir = FileSys.getDir()

val OS = let
  val {vol,...} = Path.fromString currentdir
in
  if vol = "" then (* i.e. Unix *)
    case Mosml.run "uname" ["-a"] "" of
      Success s => if String.isPrefix "Linux" s then
                     "linux"
                   else if String.isPrefix "SunOS" s then
                     "solaris"
                   else if String.isPrefix "Darwin" s then
                     "macosx"
                   else
                     "unix"
    | Failure s => (print "\nRunning uname failed with message: ";
                    print s;
                    Process.exit Process.failure)
  else "winNT"
end;

determining "mosmldir";

val mosmldir = let
  val libdir = hd (!Meta.loadPath)
  val {arcs, isAbs, vol} = Path.fromString libdir
  val _ = isAbs orelse
          (print "\n\n*** ML library directory not specified with absolute";
           print "filename --- aborting\n";
           Process.exit Process.failure)
  val (arcs', lib) = frontlast arcs
  val _ =
      if lib <> "lib" then
        print "\nMosml library directory (from loadPath) not .../lib -- weird!\n"
      else ()
  val candidate =
      Path.toString {arcs = arcs' @ ["bin"], isAbs = true, vol = vol}
  val mosml' = if OS = "winNT" then "mosmlc.exe" else "mosmlc"
  val _ =
      if FileSys.access (Path.concat(candidate, mosml'), [FileSys.A_EXEC]) then
        ()
      else (print ("\nCouldn't find executable mosmlc in "^candidate^"\n");
            print ("Giving up - please use config-override file to fix\n");
            Process.exit Process.failure)
in
  candidate
end;


determining "holdir";

val holdir = let
  val cdir_files = readdir currentdir
in
  if mem "sigobj" cdir_files andalso mem "std.prelude" cdir_files then
    currentdir
  else if mem "smart-configure.sml" cdir_files andalso
          mem "configure.sml" cdir_files
  then let
      val {arcs, isAbs, vol} = Path.fromString currentdir
      val (arcs', _) = frontlast arcs
    in
      Path.toString {arcs = arcs', isAbs = isAbs, vol = vol}
    end
  else (print "\n\n*** Couldn't determine holdir; ";
        print "please run me from the root HOL directory\n";
        Process.exit Process.failure)
end;

determining "dynlib_available";

val dynlib_available = (load "Dynlib"; true) handle _ => false;

print "\n";

val _ = let
  val override = Path.concat(holdir, "config-override")
in
  if FileSys.access (override, [FileSys.A_READ]) then
    (print "\n[Using override file!]\n\n";
     use override)
  else ()
end;


fun verdict (prompt, value) =
    (print (StringCvt.padRight #" " 20 (prompt^":"));
     print value;
     print "\n");

verdict ("OS", OS);
verdict ("mosmldir", mosmldir);
verdict ("holdir", holdir);
verdict ("dynlib_available", Bool.toString dynlib_available);

print "\nConfiguration will begin with above values.  If they are wrong\n";
print "press Control-C.\n\n";

delay 3
      (fn n => print ("\rWill continue in "^Int.toString (3 - n)^" seconds."))
      handle Interrupt => (print "\n"; Process.exit Process.failure);

print "\n";

val configfile = Path.concat (Path.concat (holdir, "tools"), "configure.sml");


use configfile;
