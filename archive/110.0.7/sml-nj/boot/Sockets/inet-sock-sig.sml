(* inet-sock-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature INET_SOCK =
  sig

    type inet

    type 'a sock = (inet, 'a) Socket.sock
    type 'a stream_sock = 'a Socket.stream sock
    type dgram_sock = Socket.dgram sock

    type sock_addr = inet Socket.sock_addr

    val inetAF : Socket.AF.addr_family   (* DARPA internet protocols *)

    val toAddr   : (NetHostDB.in_addr * int) -> sock_addr
    val fromAddr : sock_addr -> (NetHostDB.in_addr * int)
    val any  : int -> sock_addr

    structure UDP : sig
	val socket  : unit -> dgram_sock
	val socket' : int -> dgram_sock
      end

    structure TCP : sig
	val socket  : unit -> 'a stream_sock
	val socket' : int -> 'a stream_sock
      (* tcp control options *)
	val getNODELAY : 'a stream_sock -> bool
	val setNODELAY : ('a stream_sock * bool) -> unit
      end
  end


(*
 * $Log: inet-sock-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:24  george
 *   Version 109.24
 *
 *)
