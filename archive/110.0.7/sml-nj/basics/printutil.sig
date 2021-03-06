(* Copyright 1996 by AT&T Bell Laboratories *)
(* printutil.sig *)

signature PRINTUTIL =
sig
  structure Symbol : SYMBOL
  val newline : unit -> unit
  val tab : int -> unit
  val printSequence : string -> ('a -> unit) -> 'a list -> unit
  val printClosedSequence : (string*string*string) -> ('a -> unit) ->
					 'a list -> unit
  val printSym : Symbol.symbol -> unit
  val formatQid : Symbol.symbol list -> string
  val mlstr : string -> string
  val pr_mlstr : string -> string
  val nlindent : int -> unit
  val printvseq : int -> string -> ('a -> unit) -> 'a list -> unit
  val prIntPath : int list -> unit
  val prSymPath : Symbol.symbol list -> unit

end (* signature PRINTUTIL *)


(*
 * $Log: printutil.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:36  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:11  george
 *   Version 109.24
 *
 *)
