(* serv-db.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

structure NetServDB : NET_SERV_DB =
  struct

    fun netdbFun x = CInterface.c_function "SMLNJ-Sockets" x

    datatype entry = SERVENT of {
	  name : string,
	  aliases : string list,
	  port : int,
	  protocol : string
	}

    local
      fun conc field (SERVENT a) = field a
    in
    val name = conc #name
    val aliases = conc #aliases
    val port = conc #port
    val protocol = conc #protocol
    end (* local *)

  (* Server DB query functions *)
    local
      type servent = (string * string list * int * string)
      fun getServEnt NONE = NONE
	| getServEnt (SOME(name, aliases, port, protocol)) = SOME(SERVENT{
	      name = name, aliases = aliases, port = port, protocol = protocol
	    })
      val getServerByName' : (string  * string option) -> servent option
	    = netdbFun "getServByName"
      val getServerByPort' : (int  * string option) -> servent option
	    = netdbFun "getServByPort"
    in
    val getByName = getServEnt o getServerByName'
    val getByPort = getServEnt o getServerByPort'
    end (* local *)

  end

(*
 * $Log: serv-db.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:24  george
 *   Version 109.24
 *
 *)
