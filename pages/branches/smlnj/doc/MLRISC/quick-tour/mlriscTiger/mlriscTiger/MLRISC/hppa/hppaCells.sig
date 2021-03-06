(* hppacells.sig
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * CELLS - describes storage units on the machine, such as
 *         dedicated and general registers, memory ...
 *
 *	 This file acts as a bridge between MLRISC and the machine 
 *	 code.
 *
 *)
signature HPPACELLS = sig

  exception Cells

  type regmap = int Intmap.intmap
  datatype cellclass = GP | FP | CC | CR | MEM | CTRL 

  val stackptrR : int			(* stack pointer register *)
  val asmTmpR : int			(* assembly temporary *)
  val fasmTmp : int			(* floating point temporary *)

  val newCell : cellclass -> unit -> int (* generate a new name *)
  val numCell : cellclass -> unit -> int (* number of names in class *)
  val maxCell : unit -> int		 (* max id of name *)
  val cellToString : int * cellclass -> string

  val newReg : unit -> int		(* newClass GP *)
  val newFreg : unit -> int		(* newClass FP *)
  val newCCreg : unit -> int		(* newClass CC *)

  val firstPseudo : int
  val zero : cellclass -> int option 
       (* name of the register that contains zero *)

  val resetRegs : unit -> regmap (* reset any local state *)

  type cellset
  val cellset2string : cellset -> string
  val empty	     : cellset
  val addCell        : cellclass -> int * cellset -> cellset
  val cellsetToRegs  : regmap * cellset -> int list

  val addReg  : int * cellset -> cellset (* addCell GP *)
  val addFreg : int * cellset -> cellset (* addCell FP *)
end


(*
 * $Log$
 * Revision 1.1  2001/10/11 09:52:26  macqueen
 * Initial revision
 *
 * Revision 1.1  1998/05/19 15:49:20  george
 *   Version 110.5
 *
 *)
