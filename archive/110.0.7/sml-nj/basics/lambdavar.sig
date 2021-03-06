(* Copyright 1996 by AT&T Bell Laboratories *)
(* lambdavar.sig *)

signature LAMBDA_VAR = 
sig

  type lvar  

  val saveLvarNames : bool ref
  val lvarIsNamed : lvar -> bool
  val prLvar: lvar-> string
  val sameName : lvar * lvar -> unit

  val clear : unit -> unit
  val mkLvar : unit -> lvar
  val dupLvar : lvar -> lvar
  val namedLvar : Symbol.symbol -> lvar
  val lvarSym : lvar -> Symbol.symbol option
  val lvarName : lvar -> string

end (* signature LAMBDA_VAR *)

(*
 * $Log: lambdavar.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:36  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:10  george
 *   Version 109.24
 *
 *)
