(* machspec.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

structure HppaSpec : MACH_SPEC = 
struct

    open DefaultMachSpec

    val architecture	= "hppa"
    val spillAreaSz	= 4000
    val numRegs		= length HppaCpsRegs.miscregs + 3
    val numFloatRegs	= 
      length HppaCpsRegs.floatregs + length HppaCpsRegs.savedfpregs
    val bigEndian	= true
    val startgcOffset	= ~28
    val pseudoRegOffset = ~36
    val constBaseRegOffset = 8192
end

(*
 * $Log: hppaspec.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:46  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:38  george
 *   Version 109.24
 *
 *)
