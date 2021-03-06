(* win32-general-sig.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 * Signature for general Win32 stuff.
 *
 *)

signature WIN32_GENERAL = 
    sig
	structure Word : WORD
	type word

	type hndl
	type system_time = {year: int,
			    month: int,
			    dayOfWeek: int,
			    day: int,
			    hour: int,
			    minute: int,
			    second: int,
			    milliSeconds: int}

	val arcSepChar : char

	val cfun : string -> string -> 'a -> 'b
	val getConst : string -> string -> word

	val log : string list ref
	val logMsg : string -> unit

	val sayDebug : string -> unit

	val getLastError : unit -> word

	val INVALID_HANDLE_VALUE : word
	val isValidHandle : hndl -> bool
    end

(*
 * $Log: win32-general-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:42  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:27  george
 *   Version 109.24
 *
 *)
