(* Copyright 1996 by AT&T Bell Laboratories *)
(* primtyc.sml *)

structure PrimTyc :> PRIM_TYC = 
struct

local fun bug s = ErrorMsg.impossible ("PrimTyc: " ^ s)

in

(* 
 * This datatype defines the set of primitive type constructors. They 
 * probably don't have to be defined as a datatype. A environment-like
 * thing would serve better. The intermediate language can be thought
 * as a language parameterized by the set of primitive type constructors
 * and primitive functions --- which can be represented by a higher-order
 * functors. By the way, PT_VOID is an object we know nothing but that 
 * it is a pointer; or so-called canonical word representations; on a 
 * 32-bit machine, it can be a Pointer or a 31-bit integer; on 64-bit 
 * machines, it could be something else. In the future, we should also 
 * add arrow_kind and tuple_kind, or even array_kind, and vector_kind to 
 * denote various possible representation types. (ZHONG)
 *)

datatype ptyc
  = PT_INT31                         (* 31-bit integer *)
  | PT_INT32                         (* 32-bit integer *)
  | PT_REAL                          (* 64-bit real *)
  | PT_STRING                        (* string type; always a pointer *)
  | PT_EXN                           (* exception type *)

  | PT_ARRAY                         (* the polymorphic array tyc *)
  | PT_VECTOR                        (* the polymorphic vector tyc *)
  | PT_REF                           (* the polymorphic reference tyc *)
  | PT_LIST                          (* the polymorphic list tyc *)

  | PT_CONT                          (* the general-continuation tyc *)
  | PT_CCONT                         (* the control-continuation tyc *)
  | PT_ARROW                         (* the function tyc *)
  | PT_OPTION                        (* the option tyc is optional *)

  | PT_BOXED                         (* the boxed tyc; used for wrapping *)
  | PT_TGD                           (* the tagged tyc; with a integer *)
  | PT_UTGD                          (* the untagged tyc; no int tags *)
  | PT_TNSP                          (* the transparent tyc; fit-in-1-word *)

  | PT_DYN                           (* the dynamic type; with runtime ty *)
  | PT_VOID                          (* generic machine word; supports GC *)
  | PT_OBJ
  | PT_CFUN
  | PT_BARRAY
  | PT_RARRAY
  | PT_SLOCK

(** the primtive type constructor *)
type primtyc = ptyc * int * int

(** the set of primitive type constructors *)
val ptc_int31  = (PT_INT31, 0,  1)
val ptc_int32  = (PT_INT32, 0,  2)
val ptc_real   = (PT_REAL,  0,  3)     
val ptc_string = (PT_STRING,0,  4)   
val ptc_exn    = (PT_EXN,   0,  5)      
val ptc_void   = (PT_VOID,  0,  6)     
val ptc_array  = (PT_ARRAY, 1,  7)    
val ptc_vector = (PT_VECTOR,1,  8)   
val ptc_ref    = (PT_REF,   1,  9)      
val ptc_list   = (PT_LIST,  1, 10)     
val ptc_cont   = (PT_CONT,  1, 11)
val ptc_ccont  = (PT_CCONT, 1, 12)    
val ptc_arrow  = (PT_ARROW, 2, 13)    
val ptc_option = (PT_OPTION,1, 14)   
val ptc_boxed  = (PT_BOXED, 1, 15)
val ptc_tgd    = (PT_TGD,   1, 16)      
val ptc_utgd   = (PT_UTGD,  1, 17)     
val ptc_tnsp   = (PT_TNSP,  1, 18)     
val ptc_dyn    = (PT_DYN,   1, 19)      
val ptc_obj    = (PT_OBJ,   0, 20)
val ptc_cfun   = (PT_CFUN,  0, 21)
val ptc_barray = (PT_BARRAY,0, 22)
val ptc_rarray = (PT_RARRAY,0, 23)
val ptc_slock  = (PT_SLOCK, 0, 24)


(** get the arity of a particular primitive tycon *)
fun pt_arity(_, i, _) = i

(** each primitive type constructor is equipped with a key *)
fun pt_toint (_, _, k) = k

fun pt_fromint k = 
  (case k 
    of  1 => ptc_int31  
     |  2 => ptc_int32  
     |  3 => ptc_real   
     |  4 => ptc_string 
     |  5 => ptc_exn    
     |  6 => ptc_void   
     |  7 => ptc_array  
     |  8 => ptc_vector 
     |  9 => ptc_ref    
     | 10 => ptc_list   
     | 11 => ptc_cont   
     | 12 => ptc_ccont  
     | 13 => ptc_arrow  
     | 14 => ptc_option 
     | 15 => ptc_boxed  
     | 16 => ptc_tgd    
     | 17 => ptc_utgd   
     | 18 => ptc_tnsp   
     | 19 => ptc_dyn    
     | 20 => ptc_obj
     | 21 => ptc_cfun
     | 22 => ptc_barray
     | 23 => ptc_rarray
     | 24 => ptc_slock
     | _ => bug "unexpected integer in pt_fromint")

(** printing out the primitive type constructor *)
fun pt_print (pt, _, _) =
  let fun g (PT_INT31)  = "I"
        | g (PT_INT32)  = "W"
        | g (PT_REAL)   = "F"
        | g (PT_STRING) = "N"      
        | g (PT_EXN)    = "X" 
        | g (PT_ARRAY)  = "A"       
        | g (PT_VECTOR) = "V"      
        | g (PT_REF)    = "P"         
        | g (PT_LIST)   = "L"        
        | g (PT_CONT)   = "D"       
        | g (PT_CCONT)  = "C"       
        | g (PT_ARROW)  = "R"       
        | g (PT_OPTION) = "O"
        | g (PT_BOXED)  = "K"
        | g (PT_TGD)    = "T"
        | g (PT_UTGD)   = "U"
        | g (PT_TNSP)   = "S"
        | g (PT_DYN)    = "Y"
        | g (PT_VOID)   = "Z"
        | g (PT_OBJ)    = "OB"
        | g (PT_CFUN)   = "CF"
        | g (PT_BARRAY) = "BA"
        | g (PT_RARRAY) = "RA"
        | g (PT_SLOCK)  = "SL"
   in g pt
  end

(** check the boxity of values of each prim tyc *)
fun unboxed ((PT_INT32 | PT_REAL), _, _) = true
  | unboxed _ = false 

fun bxupd ((PT_INT31 | PT_INT32 | PT_REAL), _, _) = false
  | bxupd ((PT_LIST | PT_OPTION | PT_VOID), _, _) = false
  | bxupd ((PT_TNSP | PT_TGD | PT_UTGD | PT_BOXED | PT_DYN), _, _) = false
  | bxupd _ = true

fun ubxupd (PT_INT31, _, _) = true
  | ubxupd _ = false

fun isvoid ((PT_INT31 | PT_INT32 | PT_REAL), _, _) = false
  | isvoid _ = true

end (* toplevel local *)
end (* structure PrimTyc *)

(*
 * $Log: primtyc.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:36  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.4  1997/12/03 21:13:25  dbm
 *   Fix for Word8Array.array equality problem (basis/tests/word8array.sml,
 *   test1).
 *   Added ptc_obj, ptc_cfun, ptc_barray, ptc_rarray, ptc_slock, for use
 *   in basics/basictypes.sml to define objectTycon, etc.
 *
 * Revision 1.3  1997/05/05  19:59:42  george
 *   Change the term language into the quasi-A-normal form. Added a new round
 *   of lambda contraction before and after type specialization and
 *   representation analysis. Type specialization including minimum type
 *   derivation is now turned on all the time. Real array is now implemented
 *   as realArray. A more sophisticated partial boxing scheme is added and
 *   used as the default.
 *
 * Revision 1.2  1997/01/31  20:39:32  jhr
 * Replaced uses of "abstraction" with opaque signature matching.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:11  george
 *   Version 109.24
 *
 *)
