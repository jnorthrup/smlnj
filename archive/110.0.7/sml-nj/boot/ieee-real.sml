(* ieee-real.sml
 *
 * COPYRIGHT (c) 1996 AT&T Bell Laboratories.
 *)

structure IEEEReal : IEEE_REAL =
  struct

  (* this may cause portability problems to 64-bit systems *)
    structure Int = Int31

    exception Unordered

    datatype real_order = LESS | EQUAL | GREATER | UNORDERED

    datatype nan_mode = QUIET | SIGNALLING

    datatype float_class
      = NAN of nan_mode
      | INF
      | ZERO
      | NORMAL
      | SUBNORMAL

    datatype rounding_mode
      = TO_NEAREST
      | TO_NEGINF
      | TO_POSINF
      | TO_ZERO

    val ctlRoundingMode : int option -> int =
	    CInterface.c_function "SMLNJ-Math" "ctlRoundingMode"

    fun intToRM 0 = TO_NEAREST
      | intToRM 1 = TO_ZERO
      | intToRM 2 = TO_POSINF
      | intToRM 3 = TO_NEGINF

    fun setRoundingMode' m = (ctlRoundingMode (SOME m); ())

    fun setRoundingMode TO_NEAREST	= setRoundingMode' 0
      | setRoundingMode TO_ZERO		= setRoundingMode' 1
      | setRoundingMode TO_POSINF	= setRoundingMode' 2
      | setRoundingMode TO_NEGINF	= setRoundingMode' 3

    fun getRoundingMode () = intToRM (ctlRoundingMode NONE)

    type decimal_approx = {
	kind : float_class,
	sign : bool,
	digits : int list,
	exp : int
      }

    fun toString {kind, sign, digits, exp} = let
	  fun fmtExp 0 = []
	    | fmtExp i = ["E", Int.toString i]
	  fun fmtDigits ([], tail) = tail
	    | fmtDigits (d::r, tail) = (Int.toString d) :: fmtDigits(r, tail)
	  in
	    case (sign, kind, digits)
	     of (true, ZERO, _) => "~0.0"
	      | (false, ZERO, _) => "0.0"
	      | (true, (NORMAL|SUBNORMAL), []) => "~0.0"
	      | (false, (NORMAL|SUBNORMAL), []) => "0.0"
	      | (true, (NORMAL|SUBNORMAL), _) =>
		  String.concat("~0." :: fmtDigits(digits, fmtExp exp))
	      | (false, (NORMAL|SUBNORMAL), _) =>
		  String.concat("0." :: fmtDigits(digits, fmtExp exp))
	      | (true, INF, _) => "~inf"
	      | (false, INF, _) => "inf"
	      | (_, NAN _, []) => "nan"
	      | (_, NAN _, _) => String.concat("nan(" :: fmtDigits(digits, [")"]))
	    (* end case *)
	  end

(** TODO: implement fromString **)
    fun fromString s = NONE

  end;


(*
 * $Log: ieee-real.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:38  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/05/29 14:44:22  jhr
 *   SML'97 Basis Library changes (phase 1)
 *
 * Revision 1.1.1.1  1997/01/14  01:38:14  george
 *   Version 109.24
 *
 *)
