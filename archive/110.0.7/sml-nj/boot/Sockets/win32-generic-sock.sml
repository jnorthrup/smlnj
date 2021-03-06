(* generic-sock.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 * COPYRIGHT (c) 1998 Bell Labs, Lucent Technologies.
 *
 *)

structure GenericSock : GENERIC_SOCK =
  struct
    structure PS = PreSock

    fun sockFn x = CInterface.c_function "SMLNJ-Sockets" x

  (* returns a list of the supported address families; this should include
   * at least:  Socket.AF.inet.
   *)
    fun addressFamilies () = raise Fail "GenericSock.addressFamilies"

  (* returns a list of the supported socket types; this should include at
   * least:  Socket.SOCK.stream and Socket.SOCK.dgram.
   *)
    fun socketTypes () = raise Fail "GenericSock.socketTypes"

    val c_socket	: (int * int * int) -> PS.socket
	  = sockFn "socket"
(*    val c_socketPair	: (int * int * int) -> (PS.socket * PS.socket)
	  = sockFn "socketPair"*)
    fun c_socketPair _ = raise Fail "socketPair not implemented by WinSock"

  (* create sockets using default protocol *)
    fun socket (PS.AF(af, _), PS.SOCKTY(ty, _)) =
	  PS.SOCK(c_socket (af, ty, 0))
    fun socketPair (PS.AF(af, _), PS.SOCKTY(ty, _)) = let
	  val (s1, s2) = c_socketPair (af, ty, 0)
	  in
	    (PS.SOCK s1, PS.SOCK s2)
	  end

  (* create sockets using the specified protocol *)
    fun socket' (PS.AF(af, _), PS.SOCKTY(ty, _), prot) =
	  PS.SOCK(c_socket (af, ty, prot))
    fun socketPair' (PS.AF(af, _), PS.SOCKTY(ty, _), prot) = let
	  val (s1, s2) = c_socketPair (af, ty, prot)
	  in
	    (PS.SOCK s1, PS.SOCK s2)
	  end

  end

(*
 * $Log: win32-generic-sock.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.2.1  1999/06/29 18:25:47  riccardo
 * Winsock support
 *
 * Revision 1.1.1.1  1998/04/08 18:39:57  george
 * Version 110.5
 *
 *)
