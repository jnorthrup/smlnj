(* bind-posix.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * This file binds the Posix signatures and structure in the pervasive
 * top-level environment.
 *
 *)

signature POSIX_FLAGS = POSIX_FLAGS
signature POSIX_ERROR = POSIX_ERROR
signature POSIX_SIGNAL = POSIX_SIGNAL
signature POSIX_PROCESS = POSIX_PROCESS
signature POSIX_PROC_ENV = POSIX_PROC_ENV
signature POSIX_FILE_SYS = POSIX_FILE_SYS
signature POSIX_IO = POSIX_IO
signature POSIX_SYS_DB = POSIX_SYS_DB
signature POSIX_TTY = POSIX_TTY
signature POSIX = POSIX

structure Posix = Posix 


(*
 * $Log: bind-posix.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:37  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/06/07 15:27:24  jhr
 *   SML'97 Basis Library changes (phase 3; Posix changes)
 *
 * Revision 1.1.1.1  1997/01/14  01:38:12  george
 *   Version 109.24
 *
 *)
