(* os-process.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * The Posix-based implementation of the generic process control
 * interface (OS.Process).
 *
 *)

structure OS_Process : OS_PROCESS =
  struct

    structure P_Proc = Posix.Process
    structure CU = CleanUp

    type status = OS.Process.status (* int *)

    val success = 0
    val failure = 1

    fun system cmd = (case P_Proc.fork()
	   of NONE => (
		P_Proc.exec ("/bin/sh", ["sh", "-c", cmd])
		P_Proc.exit 0w127)
	    | (SOME pid) => let
		fun savSig s = Signals.setHandler (s, Signals.IGNORE)
		val savSigInt = savSig UnixSignals.sigINT
		val savSigQuit = savSig UnixSignals.sigQUIT
		fun restore () = (
		      Signals.setHandler (UnixSignals.sigINT, savSigInt);
		      Signals.setHandler (UnixSignals.sigQUIT, savSigQuit);
		      ())
		fun wait () = (case #2(P_Proc.waitpid(P_Proc.W_CHILD pid, []))
		       of P_Proc.W_EXITED => success
			| (P_Proc.W_EXITSTATUS w) => Word8.toInt w
			| (P_Proc.W_SIGNALED s) => failure (* ?? *)
			| (P_Proc.W_STOPPED s) => failure (* this shouldn't happen *)
		      (* end case *))
		in
		  (wait() before restore())
		    handle ex => (restore(); raise ex)
		end
	  (* end case *))

    val atExit = AtExit.atExit

    fun terminate x = P_Proc.exit(Word8.fromInt x)
    fun exit sts = (CU.clean CU.AtExit; terminate sts)

    val getEnv = Posix.ProcEnv.getenv

  end

(*
 * $Log: os-process.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:42  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/11/25 22:40:37  jhr
 *   The type of General.before has changed.
 *
 * Revision 1.2  1997/08/20  13:09:49  jhr
 *   Lifted OS independent atExit code into its own module, and fixed an
 *   infinite loop that occurred when an atExit action called exit.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:25  george
 *   Version 109.24
 *
 *)
