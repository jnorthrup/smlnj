(* posix-sysdb-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * Signature for POSIX 1003.1 system data-base operations
 *
 *)

signature POSIX_SYS_DB =
  sig
    eqtype uid
    eqtype gid
    
    structure Passwd :
      sig
        type passwd

        val name  : passwd -> string
        val uid   : passwd -> uid
        val gid   : passwd -> gid
        val home  : passwd -> string
        val shell : passwd -> string

      end

    structure Group :
      sig
        type group

        val name    : group -> string
        val gid     : group -> gid
        val members : group -> string list
    
      end
    
    val getgrgid : gid -> Group.group
    val getgrnam : string -> Group.group
    val getpwuid : uid -> Passwd.passwd
    val getpwnam : string -> Passwd.passwd

  end (* signature POSIX_SYS_DB *)

(*
 * $Log: posix-sysdb-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:23  george
 *   Version 109.24
 *
 *)
