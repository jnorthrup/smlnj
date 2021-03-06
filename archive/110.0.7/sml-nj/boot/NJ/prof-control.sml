(* prof-control.sml
 *
 * COPYRIGHT (c) 1996 AT&T Research.
 *
 * This structure implements the interface to the run-time system's profiling
 * support library.  It is not meant for general use.
 *
 *)

structure ProfControl : PROF_CONTROL =
  struct

    structure CI = Unsafe.CInterface

    val setTimer : bool -> unit
	  = CI.c_function "SMLNJ-Prof" "setTimer"
    val getQuantum : unit -> int
	  = CI.c_function "SMLNJ-Prof" "getQuantum"
    val setTimeArray' : int array option -> unit
	  = CI.c_function "SMLNJ-Prof" "setTimeArray"

    val profMode = ref false	(* controls profile instrumentation *)
    val timingMode = ref false	(* controls profile timer *)

    val times = ref (Array.array(0, 0))

    fun getTimingMode () = !timingMode

  (* set the timer count array *)
    fun setTimeArray arr = (
	  if !timingMode then setTimeArray'(SOME arr) else ();
	  times := arr)

    fun getTimeArray () = !times

    fun resetTimeArray () = let
	  fun zero a = Array.modify (fn _ => 0) a
	  in
	    zero (!times)
	  end
    
    fun profileOn () = if !timingMode
	  then ()
	  else (timingMode := true; setTimeArray'(SOME(!times)); setTimer true)

    fun profileOff () = if !timingMode
	  then (setTimer false; setTimeArray' NONE; timingMode := false)
	  else ()

    datatype compunit = UNIT of {
	base: int,
	size: int,
	counts: int Array.array,
	names: string
      }
			   
    val runTimeIndex = 0
    val minorGCIndex = 1
    val majorGCIndex = 2
    val otherIndex = 3
    val compileIndex = 4
    val numPredefIndices = 5

    val current : int ref = Core.Assembly.profCurrent
    val _ = (
	  setTimeArray(Array.array(numPredefIndices, 0));
	  current := otherIndex)

    fun increase n = let
	  val old = getTimeArray()
	  in
	    if n <= Array.length old
	      then ()
	      else let val new = Array.array(n+n, 0)
		in
		  Array.copy{di=0, dst=new, len=NONE, si=0, src = old};
		  setTimeArray new
		end
	  end

    val units = ref [UNIT{
	    base = 0,
	    size = numPredefIndices,
	    counts = Array.array(numPredefIndices, 0),
	    names = "\
		\Run-time System\n\
		\Minor GC\n\
		\Major GC\n\
		\Other\n\
		\Compilation\n"
	  }];

  (* count the number of newlines in a string *)
    fun newlines s = let
	  fun notNL #"\n" = false | notNL _ = true
	  fun f (ss, count) = let
		val ss = Substring.dropl notNL ss
		in
		  if Substring.isEmpty ss
		    then count
		    else f (Substring.triml 1 ss, count+1)
		end
	  in
	    f (Substring.all s, 0)
	  end

    fun register names = let
	  val ref (list as UNIT{base,size,...}::_) = units
	  val count = newlines names
	  val a = Array.array(count,0)
	  val b = base+size
	  in
	    increase(b+count);
	    units := UNIT{base=b,size=count,counts=a,names=names}::list;
	    (b,a,current)
	  end

    val _ =  Core.profile_register := register;

    fun reset() = let
	  fun zero a = Array.modify (fn _ => 0) a
	  in
	    resetTimeArray();
	    List.app (fn UNIT{counts,...}=> zero counts) (!units)
	  end
 
  (* space profiling hooks *)
    val spaceProfiling = ref false
    val spaceProfRegister :
	  (Unsafe.Object.object * string -> Unsafe.Object.object) ref =
	    Unsafe.cast Core.profile_sregister

  end


(*
 * $Log: prof-control.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:40  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.4  1997/09/22 19:51:05  jhr
 *   Changed Profiling API to use separate compiler and timer modes.
 *
 * Revision 1.3  1997/06/30  19:36:29  jhr
 *   Removed System structure; added Unsafe structure.
 *
 * Revision 1.2  1997/01/28  23:14:30  jhr
 * Fixed bug in profile on/off control.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:20  george
 *   Version 109.24
 *
 *)
