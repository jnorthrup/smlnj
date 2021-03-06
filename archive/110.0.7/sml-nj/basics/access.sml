(* Copyright 1996 by AT&T Bell Laboratories *)
(* access.sml *)

structure Access : ACCESS = 
struct

local structure LV = LambdaVar
      structure EM = ErrorMsg
      structure PS = PersStamps
      structure S = Symbol
in 

fun bug msg = EM.impossible("Bugs in Access: "^msg)

type lvar = LV.lvar
type persstamp = PS.persstamp

(* 
 * access: how to find the dynamic value corresponding to a variable.
 * An LVAR is just a lambda-bound variable --- a temporary used to denote
 * a binding in the current compilation unit. EXTERN refers to a binding 
 * defined externally (in other modules). PATH is an absolute address from 
 * a lambda-bound variable (i.e. we find the value of the lambda-bound 
 * variable, and then do selects from that). PATH's are kept in reverse 
 * order. NO_ACCESS is used to denote built-in structures that do not
 * have corresponding dynamic objects (e.g., the built-in InLine is a 
 * structure that declares all the built-in primitives --- it is likely
 * that NO_ACCESS will go away in the future once we have cleaned up the
 * bootstrap procedure.
 *)
datatype access
  = LVAR of lvar
  | EXTERN of persstamp
  | PATH of access * int
  | NO_ACCESS

(*
 * conrep: how to decide the data representations for data constructors. 
 * All true datatypes are divided into four categories, depending on the
 * pair of parameters (m,n) where m is the number of constant constructors
 * and n is the number of value carrying constructors. REF, EXNCONST,
 * and EXNFUN are special constructors for reference cells and exceptions;
 * treating them as data constructors simplifies the match compilations.
 * LISTCONS and LISTNIL are special conreps for unrolled lists. The process
 * of assigning conreps probably should be performed on the intermediate
 * language instead. 
 *)
datatype conrep
  = UNTAGGED                             (* 30 bit + 00; a pointer *)
  | TAGGED of int                        (* a pointer; 1st field is the tag *)
  | TRANSPARENT                          (* 32 bit value *)
  | CONSTANT of int                      (* should be int31 *)
  | REF                                  
  | EXNCONST of access                   (* 2-element record: ref + unit *)
  | EXNFUN of access                   (* 2-element record: ref + val *)
  | LISTCONS                              
  | LISTNIL

datatype consig 
  = CSIG of int * int
  | CNIL

(****************************************************************************
 *                    UTILITY FUNCTIONS ON ACCESS                           *
 ****************************************************************************)

(** printing the access *)
fun prAcc (LVAR i) = "LVAR(" ^ LV.prLvar i ^ ")"
  | prAcc (PATH(a,i)) = "PATH(" ^ Int.toString i ^ ","^ prAcc a ^ ")"
  | prAcc (EXTERN pid) = "EXTERN(" ^ PS.toHex pid ^ ")"
  | prAcc (NO_ACCESS) = "NO_ACCESS"

(** printing the conrep *)
fun prRep (UNTAGGED) = "UT"
  | prRep (TAGGED i) = "TG(" ^ Int.toString i ^ ")"
  | prRep (TRANSPARENT) = "TN"
  | prRep (CONSTANT i) = "CN(" ^ Int.toString i ^ ")"
  | prRep (REF) = "RF"
  | prRep (EXNCONST acc) = "EC" ^ prAcc acc
  | prRep (EXNFUN acc) = "EF" ^ prAcc acc
  | prRep (LISTCONS) = "LC"
  | prRep (LISTNIL) = "LN"

(** printing the data sign *)
fun prCsig (CSIG(i,j)) = "B" ^ Int.toString i ^ "U" ^ Int.toString j
  | prCsig (CNIL) = "CNIL"

(** testing if a conrep is an exception or not *)
fun isExn (EXNCONST _) = true
  | isExn (EXNFUN _) = true
  | isExn _ = false

fun isConst (EXNCONST _) = true
  | isConst (CONSTANT _) = true
  | isConst (LISTNIL) = true
  | isConst _ = false

(** fetching a component out of a structure access *)
fun selAcc (NO_ACCESS, _) = NO_ACCESS (* bug  "Selecting from a NO_ACCESS !" *)
  | selAcc (p, i) = PATH(p, i)

(** duplicating an access variable *)
fun dupAcc (v, mkv) = LVAR(mkv(LV.lvarSym(v)))

fun namedAcc (s, mkv) = LVAR(mkv(SOME s))
fun newAcc (mkv) = LVAR (mkv(NONE))
fun extAcc pid  = EXTERN pid
val nullAcc = NO_ACCESS

fun accLvar (LVAR v) = SOME v
  | accLvar _ = NONE

end (* local *)
end (* structure Access *)

(*
 * $Log: access.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:36  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:09  george
 *   Version 109.24
 *
 *)
