(* constant.sml --- constants used to specialize MLRISC and the code generators.
 * 
 * COPYRIGHT (c) 1996 AT&T Bell Laboratories.
 *
 *)

signature CONSTANT = sig
  type const

  val toString : const -> string
  val valueOf : const -> int
end

(*
 * $Log: constant.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:35  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/04/19 18:14:20  george
 *   Version 109.27
 *
 *)
