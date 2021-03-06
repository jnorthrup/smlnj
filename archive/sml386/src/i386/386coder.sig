(* Copyright 1989 by      Department of Computer Science, 
 *                        The Technical University of Denmak
 *                        DK-2800 Lyngby 
 *
 * 17 Dec. 1991    Yngvi Skaalum Guttesen       (ysg@id.dth.dk)
 *)

signature CODER386 = sig

eqtype Label
val newlabel : unit -> Label

datatype Size = Byte | Word | Long

datatype EA = Direct of int
	    | Displace of int * int
	    | Index of int * int * int * Size
	    | Immedlab of Label
	    | Immed of int

(*************** The 80386 registers ****************************)

val eax : int
val ebx : int
val ecx : int
val edx : int
val esi : int
val edi : int
val ebp : int
val esp : int

(**************** Misc. functions *******************************)

val comment : string -> unit
val finish  : unit   -> string
val align   : unit   -> unit
val mark    : unit   -> unit
val define  : Label  -> unit

(***************** Emitters *************************************)

val emitstring : string -> unit
val realconst : string -> unit
val emitlong : int -> unit
val emitlab : int * Label -> unit

(***************** Memory functions *****************************)

val movl  : EA * EA -> unit
val movb  : EA * EA -> unit
val movzx : EA * EA -> unit
val stos  : EA      -> unit
val lea   : EA * EA -> unit
val push  : EA      -> unit
val pop   : EA      -> unit
val xchg  : EA * EA -> unit

(***************** Logical functions ****************************)

val orl  : EA * EA -> unit
val notl : EA      -> unit
val andl : EA * EA -> unit
val xorl : EA * EA -> unit
val btst : EA * EA -> unit

(**************** Arithmetic functions *************************)

val addl  : EA * EA -> unit
val addl2 : EA * EA -> unit
val subl  : EA * EA -> unit
val negl  : EA      -> unit
val cmpl  : EA * EA -> unit
val asrl  : EA * EA -> unit
val asll  : EA * EA -> unit
val divl  : EA      -> unit
val mull  : EA * EA -> unit
val cdq   : unit    -> unit

(**************** Jumps ****************************************)

val jra : EA -> unit
val jmp : EA -> unit

val jne : EA -> unit
val jeq : EA -> unit
val jgt : EA -> unit
val jge : EA -> unit
val jlt : EA -> unit
val jle : EA -> unit
val jb  : EA -> unit
val jbe : EA -> unit
val ja  : EA -> unit
val jae : EA -> unit
val jc  : EA -> unit
val jnc : EA -> unit

(****************** Floating point functions **********************)

val fcomp  : EA   -> unit
val fadd   : EA   -> unit
val fsub   : EA   -> unit
val fmul   : EA   -> unit
val fdiv   : EA   -> unit
val fstp   : EA   -> unit
val fld    : EA   -> unit
val fnstsw : EA   -> unit
val sahf   : unit -> unit

(***************** Trap functions ********************************)

val trapv   : EA -> unit
val trapmi  : EA -> unit

end (* signature CODER386 *)


