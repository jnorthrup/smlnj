(* host-db-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature NET_HOST_DB =
  sig
    eqtype in_addr
    eqtype addr_family
    type entry
    val name     : entry -> string
    val aliases  : entry -> string list
    val addrType : entry -> addr_family
    val addr     : entry -> in_addr
    val addrs    : entry -> in_addr list
    val getByName    : string -> entry option
    val getByAddr    : in_addr -> entry option

    val getHostName : unit -> string

    val scan       : (char, 'a) StringCvt.reader -> (in_addr, 'a) StringCvt.reader
    val fromString : string -> in_addr option
    val toString   : in_addr -> string

  end

(*
 * $Log: host-db-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:24  george
 *   Version 109.24
 *
 *)
