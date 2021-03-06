(* unix-sock.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

structure UnixSock : UNIX_SOCK =
  struct
    structure SOCK = Socket.SOCK

    fun sockFn x = CInterface.c_function "SMLNJ-Sockets" x

    datatype unix = UNIX

    type 'a sock = (unix, 'a) Socket.sock
    type 'a stream_sock = 'a Socket.stream sock
    type dgram_sock = Socket.dgram sock

    type sock_addr = unix Socket.sock_addr

    val unixAF = Option.valOf(Socket.AF.fromString "UNIX")

(** We should probably do some error checking on the length of the string *)
    local
      val toUnixAddr : string -> PreSock.addr = sockFn "toUnixAddr"
      val fromUnixAddr : PreSock.addr -> string = sockFn "fromUnixAddr"
    in
    fun toAddr s = PreSock.ADDR(toUnixAddr s)
    fun fromAddr (PreSock.ADDR addr) = fromUnixAddr addr
    end

    structure Strm =
      struct
	fun socket () = GenericSock.socket (unixAF, SOCK.stream)
	fun socket' proto = GenericSock.socket' (unixAF, SOCK.stream, proto)
	fun socketPair () = GenericSock.socketPair (unixAF, SOCK.stream)
	fun socketPair' proto = GenericSock.socketPair' (unixAF, SOCK.stream, proto)
      end
    structure DGrm =
      struct
	fun socket () = GenericSock.socket (unixAF, SOCK.dgram)
	fun socket' proto = GenericSock.socket' (unixAF, SOCK.dgram, proto)
	fun socketPair () = GenericSock.socketPair (unixAF, SOCK.dgram)
	fun socketPair' proto = GenericSock.socketPair' (unixAF, SOCK.dgram, proto)
      end
  end;


(*
 * $Log: unix-sock.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/02/26 21:00:30  george
 *    Defined a new top level Option structure. All 'a option related
 *    functions have been moved out of General.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:24  george
 *   Version 109.24
 *
 *)
