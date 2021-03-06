(*
 * Convert a given static env to a "dependency-analysis env".
 *
 * (C) 1999 Lucent Technologies, Bell Laboratories
 *
 * Author: Matthias Blume (blume@kurims.kyoto-u.ac.jp)
 *)
signature STATENV2DAENV = sig
    val cvt : GenericVC.BareEnvironment.staticEnv ->
	DAEnv.env * (unit -> SymbolSet.set)

    (* The thunk passed to cvtMemo will not be called until the first
     * attempt to query the resulting DAEnv.env.
     * If the symbols for which queries succeed are known, then one
     * should further guard the resulting env with an appropriate filter
     * to avoid queries that are known in advance to be unsuccessful
     * because they would needlessly cause the thunk to be called. *)
    val cvtMemo :
	(unit -> GenericVC.BareEnvironment.staticEnv) ->
	DAEnv.env
end

structure Statenv2DAEnv :> STATENV2DAENV = struct

    structure BE = GenericVC.BareEnvironment

    fun cvt_fctenv look = DAEnv.FCTENV (cvt_result o look)

    and cvt_result (BE.CM_ENV { look, ... }) = SOME (cvt_fctenv look)
      | cvt_result BE.CM_NONE = NONE

    fun cvt sb = let
	fun l2s l = let
	    fun addModule (sy, set) =
		case Symbol.nameSpace sy of
		    (Symbol.STRspace | Symbol.SIGspace |
		     Symbol.FCTspace | Symbol.FSIGspace) =>
		    SymbolSet.add (set, sy)
		   | _ => set
	in
	    foldl addModule SymbolSet.empty l
	end
	val dae = cvt_fctenv (BE.cmEnvOfModule sb)
	fun mkDomain () = l2s (BE.catalogEnv sb)
    in
	(dae, mkDomain)
    end

    fun cvtMemo getSB = let
	val l = ref (fn s => raise Fail "se2dae: uninitialized")
	fun looker s = let
	    fun getCME () = BE.cmEnvOfModule (getSB ())
	    val lk = cvt_result o (getCME ())
	in
	    l := lk;
	    lk s
	end
    in
	l := looker;
	DAEnv.FCTENV (fn s => !l s)
    end
end
