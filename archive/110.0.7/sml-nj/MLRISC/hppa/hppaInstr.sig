signature HPPAINSTR = sig
  structure Constant : CONSTANT
  structure Region : REGION

  type csets = int list * int list
  structure C : CELLS where type cellset = csets

  datatype store = STW | STH | STB 

  (* All branching is done with nullification *)
  datatype cmp = COMBT | COMBF 

  datatype cmpi = COMIBT | COMIBF

  datatype load = LDWX | LDHX | LDBX

  datatype loadi = LDW | LDH | LDB

  datatype arith = ADD | ADDO | SH1ADD | SH1ADDO 
		 | SUB | SUBO | OR  | XOR | AND 

  datatype arithi = ADDI | ADDIO | ADDIL | SUBI | SUBIO 

  datatype shiftv = VEXTRU | VEXTRS | ZVDEP

  datatype shift = EXTRU | EXTRS | ZDEP

  datatype farith = FADD | FSUB | FMPY | FDIV | XMPYU

  (* FCNVXF --- the source is the LHS single precision floating register *)
  datatype funary = FCPY | FABS | FCNVXF

  datatype fstore = FSTDS | FSTWS

  datatype fstorex = FSTDX | FSTWX

  (* FLDWX and FLDWS -- loads the RHS of the floating register *)
  datatype floadx = FLDDX | FLDWX
 
  datatype fload = FLDDS | FLDWS

  datatype bcond = EQ | LT | LE | LTU | LEU | NE | GE | GT | GTU | GEU
  datatype fcond = 
    == | != | ? | <=> | > | >= | ?> | ?>= | < | <= | ?< | ?<= | <> | ?= 

  datatype scond = ALL_ZERO | LEFTMOST_ONE | LEFTMOST_ZERO | RIGHTMOST_ONE
                 | RIGHTMOST_ZERO 

  datatype field_selector = F | S | D | R | T | P

  datatype operand =
      IMMED of int
    | LabExp of LabelExp.labexp * field_selector
    | HILabExp of LabelExp.labexp * field_selector
    | LOLabExp of LabelExp.labexp * field_selector
    | ConstOp of Constant.const

  (* FLDWS, FLDWX = define the R half of the FP register.
   * FSTWS = uses the R half of the FP register.
   *)
  datatype instruction =  
      STORE   of {st:store,   b:int,  d:operand,  r:int, mem:Region.region}
    | LOAD    of {l:load,     r1:int, r2:int, t:int, mem:Region.region}
    | LOADI   of {li:loadi,   i:operand,  r:int,  t:int, mem:Region.region}
    | ARITH   of {a:arith,    r1:int, r2:int, t:int}
    | ARITHI  of {ai:arithi,  i:operand,  r:int,  t:int}
    | COMCLR  of {cc:bcond,   r1:int, r2:int, t:int}
    | SHIFTV  of {sv:shiftv,  r:int,  len:int, t:int}
    | SHIFT   of {s:shift,    r:int,  p:int,  len:int, t:int}
    | BCOND   of {cmp: cmp,   bc:bcond,  r1:int, r2:int, 
		  t:Label.label, f:Label.label}
    | BCONDI  of {cmpi: cmpi, bc:bcond,  i:int,  r2:int, 
		  t:Label.label, f:Label.label}
    | B       of Label.label
    | FBCC    of {t:Label.label, f:Label.label}
    | BV      of {x:int,      b:int,   labs: Label.label list}
    | BL      of {x:operand,  t:int, defs: C.cellset, uses:C.cellset}
    | BLE     of {d:operand,  b:int, sr:int, t:int,
		  defs: C.cellset, uses:C.cellset}
      (* BLE implicitly defines %r31. The destination register t 
       * is assigned in the delay slot.
       *)
    | LDIL    of {i:operand,  t:int}
    | LDO     of {i:operand,  b:int,   t:int}

    | MTCTL   of {r:int, t:int}

    | FSTORE  of {fst:fstore, b:int,   d:int,   r:int, mem:Region.region}
    | FSTOREX of {fstx:fstorex, b:int, x:int, r:int, mem:Region.region}
    | FLOAD   of {fl:fload,   b:int,   d:int,   t:int, mem:Region.region}
    | FLOADX  of {flx:floadx, b:int,   x:int,   t:int, mem:Region.region}
    | FARITH  of {fa:farith,  r1:int,  r2:int,  t:int}
    | FUNARY  of {fu:funary,  f:int,   t:int}
    | FCMP    of fcond * int * int
    | FTEST
    | BREAK   of int * int
    | NOP
    | COPY    of int list * int list * instruction list option ref
    | FCOPY   of int list * int list * instruction list option ref
end


(*
 * $Log: hppaInstr.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:34  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/09/29 20:58:30  george
 *   Propagate region information through instruction set
 *
# Revision 1.2  1997/05/22  03:23:11  dbm
#   Minor change to use SML '97 style spec.
#
# Revision 1.1.1.1  1997/04/19  18:14:22  george
#   Version 109.27
#
 *)
