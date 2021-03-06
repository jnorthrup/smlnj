(* sml90-sig.sml
 *
 * COPYRIGHT (c) 1997 Bell Labs, Lucent Technologies.
 *)

signature SML90 =
  sig

    type instream
    type outstream

    exception Sqrt
    exception Ln
    exception Ord
    exception Io of string
    exception Abs
    exception Quot
    exception Prod
    exception Neg
    exception Sum
    exception Diff
    exception Floor
    exception Exp
    exception Interrupt
    exception Mod

    val sqrt : real -> real
    val exp : real -> real
    val ln : real -> real
    val sin : real -> real
    val cos : real -> real
    val arctan : real -> real
    val ord : string -> int
    val chr : int -> string
    val explode : string -> string list
    val implode : string list -> string
    val std_in : instream
    val open_in : string -> instream
    val input : (instream * int) -> string
    val lookahead : instream -> string
    val close_in : instream -> unit
    val end_of_stream : instream -> bool
    val std_out : outstream
    val open_out : string -> outstream
    val output : (outstream * string) -> unit
    val close_out : outstream -> unit

  end;

(*
 * $Log: sml90-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:38  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1  1997/05/29 15:22:08  jhr
 *   SML'97 Basis Library changes (phase 1)
 *
 *)

