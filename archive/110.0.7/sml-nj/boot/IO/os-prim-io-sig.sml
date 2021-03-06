(* os-prim-io-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * This is an interface to a PrimIO structure augmented with OS specific
 * functions to create readers and writers.
 *
 *)

signature OS_PRIM_IO =
  sig
    structure PrimIO : PRIM_IO

    type file_desc

    val openRd  : string -> PrimIO.reader
    val openWr  : string -> PrimIO.writer
    val openApp : string -> PrimIO.writer

    val mkReader : {
	    fd : file_desc,
	    name : string,
  	    initBlkMode : bool
	  } -> PrimIO.reader
    val mkWriter: {
	    fd : file_desc,
	    name : string,
	    appendMode : bool,
	    initBlkMode : bool, 
	    chunkSize : int
	  } -> PrimIO.writer

  end


(*
 * $Log: os-prim-io-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:39  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:19  george
 *   Version 109.24
 *
 *)
