(* time-comp.sml
 *
 * COPYRIGHT (c) 1996 AT&T Research.
 *
 * Time a compile of the SML/NJ system.
 *
 *)

local
structure T = Time
structure Tm = Timer
fun cvt {usr, gc, sys} = {
	usr = T.toString usr,
	gc = T.toString gc,
	sys = T.toString sys,
	tot = T.toString(T.+(usr, T.+(sys, gc)))
      }
in
fun make () = let
      val t0 = Tm.startCPUTimer()
      in
	CMB.make();
	cvt (Tm.checkCPUTimer t0)
      end
end;


(*
 * $Log: time-comp.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:34  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:07  george
 *   Version 109.24
 *
 *)
