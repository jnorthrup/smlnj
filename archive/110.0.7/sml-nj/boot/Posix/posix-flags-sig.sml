(* posix-flags.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * Signature for bit flags.
 *
 *)

signature POSIX_FLAGS =
  sig
    eqtype flags

    val toWord   : flags -> SysWord.word
    val fromWord : SysWord.word -> flags

      (* Create a flags value corresponding to the union of all flags
       * set in the list.
       *)
    val flags  : flags list -> flags

      (* allSet(s,t) returns true if all flags in s are also in t. *)
    val allSet : flags * flags -> bool

      (* anySet(s,t) returns true if any flag in s is also in t. *)
    val anySet : flags * flags -> bool
  end


(*
 * $Log: posix-flags-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/12/16 16:17:51  jhr
 *   Name change: wordTo ==> fromWord in POSIX_FLAGS signature.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:22  george
 *   Version 109.24
 *
 *)
