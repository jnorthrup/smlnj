(* unix-sock-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature UNIX_SOCK =
  sig
    type unix

    type 'a sock = (unix, 'a) Socket.sock
    type 'a stream_sock = 'a Socket.stream sock
    type dgram_sock = Socket.dgram sock

    type sock_addr = unix Socket.sock_addr

    val unixAF : Socket.AF.addr_family   (* 4.3BSD internal protocols *)

    val toAddr   : string -> sock_addr
    val fromAddr : sock_addr -> string

    structure Strm : sig
	val socket     : unit -> 'a stream_sock
	val socketPair : unit -> ('a stream_sock * 'a stream_sock)
      end
    structure DGrm : sig
	val socket     : unit -> dgram_sock
	val socketPair : unit -> (dgram_sock * dgram_sock)
      end
  end;

(*
 * $Log: unix-sock-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:24  george
 *   Version 109.24
 *
 *)
