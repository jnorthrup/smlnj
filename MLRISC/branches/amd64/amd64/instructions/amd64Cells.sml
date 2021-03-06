(*
 * WARNING: This file was automatically generated by MDLGen (v3.1)
 * from the machine description file "amd64/amd64.mdl".
 * DO NOT EDIT this file directly
 *)


signature AMD64CELLS =
sig
   include CELLS
   val EFLAGS : CellsBasis.cellkind
   val FFLAGS : CellsBasis.cellkind
   val CTR_L : CellsBasis.cellkind
   val CELLSET : CellsBasis.cellkind
   val showGP : CellsBasis.register_id -> string
   val showFP : CellsBasis.register_id -> string
   val showCC : CellsBasis.register_id -> string
   val showEFLAGS : CellsBasis.register_id -> string
   val showFFLAGS : CellsBasis.register_id -> string
   val showMEM : CellsBasis.register_id -> string
   val showCTR_L : CellsBasis.register_id -> string
   val showCELLSET : CellsBasis.register_id -> string
   val showGPWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showFPWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showCCWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showEFLAGSWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showFFLAGSWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showMEMWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showCTR_LWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val showCELLSETWithSize : CellsBasis.register_id * CellsBasis.sz -> string
   val rax : CellsBasis.cell
   val rcx : CellsBasis.cell
   val rdx : CellsBasis.cell
   val rbx : CellsBasis.cell
   val rsp : CellsBasis.cell
   val rbp : CellsBasis.cell
   val rsi : CellsBasis.cell
   val rdi : CellsBasis.cell
   val r8 : CellsBasis.cell
   val r9 : CellsBasis.cell
   val r10 : CellsBasis.cell
   val r11 : CellsBasis.cell
   val r12 : CellsBasis.cell
   val r13 : CellsBasis.cell
   val r14 : CellsBasis.cell
   val r15 : CellsBasis.cell
   val xmm0 : CellsBasis.cell
   val xmm1 : CellsBasis.cell
   val xmm2 : CellsBasis.cell
   val xmm3 : CellsBasis.cell
   val xmm4 : CellsBasis.cell
   val xmm5 : CellsBasis.cell
   val xmm6 : CellsBasis.cell
   val xmm7 : CellsBasis.cell
   val xmm8 : CellsBasis.cell
   val xmm9 : CellsBasis.cell
   val xmm10 : CellsBasis.cell
   val xmm11 : CellsBasis.cell
   val xmm12 : CellsBasis.cell
   val xmm13 : CellsBasis.cell
   val xmm14 : CellsBasis.cell
   val xmm15 : CellsBasis.cell
   val eflags : CellsBasis.cell
   val addGP : CellsBasis.cell * cellset -> cellset
   val addFP : CellsBasis.cell * cellset -> cellset
   val addCC : CellsBasis.cell * cellset -> cellset
   val addEFLAGS : CellsBasis.cell * cellset -> cellset
   val addFFLAGS : CellsBasis.cell * cellset -> cellset
   val addMEM : CellsBasis.cell * cellset -> cellset
   val addCTR_L : CellsBasis.cell * cellset -> cellset
   val addCELLSET : CellsBasis.cell * cellset -> cellset
end

structure AMD64Cells : AMD64CELLS =
struct
   exception AMD64Cells
   fun error msg = MLRiscErrorMsg.error("AMD64Cells",msg)
   open CellsBasis
   fun showGPWithSize (r, ty) = (fn (0, 8) => "%al"
                                  | (4, 8) => "%ah"
                                  | (1, 8) => "%cl"
                                  | (5, 8) => "%ch"
                                  | (2, 8) => "%dl"
                                  | (6, 8) => "%dh"
                                  | (3, 8) => "%bl"
                                  | (7, 8) => "%bh"
                                  | (r, 8) => ("%r" ^ (Int.toString r)) ^ "b"
                                  | (0, 16) => "%ax"
                                  | (4, 16) => "%sp"
                                  | (1, 16) => "%cx"
                                  | (5, 16) => "%bp"
                                  | (2, 16) => "%dx"
                                  | (6, 16) => "%si"
                                  | (3, 16) => "%bx"
                                  | (7, 16) => "%di"
                                  | (r, 16) => ("%r" ^ (Int.toString r)) ^ "w"
                                  | (0, 32) => "%eax"
                                  | (4, 32) => "%esp"
                                  | (1, 32) => "%ecx"
                                  | (5, 32) => "%ebp"
                                  | (2, 32) => "%edx"
                                  | (6, 32) => "%esi"
                                  | (3, 32) => "%ebx"
                                  | (7, 32) => "%edi"
                                  | (r, 32) => ("%r" ^ (Int.toString r)) ^ "d"
                                  | (0, 64) => "%rax"
                                  | (4, 64) => "%rsp"
                                  | (1, 64) => "%rcx"
                                  | (5, 64) => "%rbp"
                                  | (2, 64) => "%rdx"
                                  | (6, 64) => "%rsi"
                                  | (3, 64) => "%rbx"
                                  | (7, 64) => "%rdi"
                                  | (r, 64) => "%r" ^ (Int.toString r)
                                  | (r, _) => "%" ^ (Int.toString r)
                                ) (r, ty)
   and showFPWithSize (r, ty) = (fn (f, _) => (if (f < 16)
                                       then ("%xmm" ^ (Int.toString f))
                                       else ("%f" ^ (Int.toString f)))
                                ) (r, ty)
   and showCCWithSize (r, ty) = (fn _ => "cc"
                                ) (r, ty)
   and showEFLAGSWithSize (r, ty) = (fn _ => "$eflags"
                                    ) (r, ty)
   and showFFLAGSWithSize (r, ty) = (fn _ => "$fflags"
                                    ) (r, ty)
   and showMEMWithSize (r, ty) = (fn _ => "mem"
                                 ) (r, ty)
   and showCTR_LWithSize (r, ty) = (fn _ => "ctrl"
                                   ) (r, ty)
   and showCELLSETWithSize (r, ty) = (fn _ => "CELLSET"
                                     ) (r, ty)
   fun showGP r = showGPWithSize (r, 64)
   fun showFP r = showFPWithSize (r, 64)
   fun showCC r = showCCWithSize (r, 32)
   fun showEFLAGS r = showEFLAGSWithSize (r, 32)
   fun showFFLAGS r = showFFLAGSWithSize (r, 32)
   fun showMEM r = showMEMWithSize (r, 8)
   fun showCTR_L r = showCTR_LWithSize (r, 0)
   fun showCELLSET r = showCELLSETWithSize (r, 0)
   val EFLAGS = CellsBasis.newCellKind {name="EFLAGS", nickname="eflags"}
   and FFLAGS = CellsBasis.newCellKind {name="FFLAGS", nickname="fflags"}
   and CTR_L = CellsBasis.newCellKind {name="CTR_L", nickname="ctrl"}
   and CELLSET = CellsBasis.newCellKind {name="CELLSET", nickname="cellset"}
   structure MyCells = Cells
      (exception Cells = AMD64Cells
       val firstPseudo = 256
       val desc_GP = CellsBasis.DESC {low=0, high=15, kind=CellsBasis.GP, defaultValues=[], 
              zeroReg=NONE, toString=showGP, toStringWithSize=showGPWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_FP = CellsBasis.DESC {low=16, high=31, kind=CellsBasis.FP, 
              defaultValues=[], zeroReg=NONE, toString=showFP, toStringWithSize=showFPWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_EFLAGS = CellsBasis.DESC {low=32, high=32, kind=EFLAGS, defaultValues=[], 
              zeroReg=NONE, toString=showEFLAGS, toStringWithSize=showEFLAGSWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_FFLAGS = CellsBasis.DESC {low=33, high=33, kind=FFLAGS, defaultValues=[], 
              zeroReg=NONE, toString=showFFLAGS, toStringWithSize=showFFLAGSWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_MEM = CellsBasis.DESC {low=34, high=33, kind=CellsBasis.MEM, 
              defaultValues=[], zeroReg=NONE, toString=showMEM, toStringWithSize=showMEMWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_CTR_L = CellsBasis.DESC {low=34, high=33, kind=CTR_L, defaultValues=[], 
              zeroReg=NONE, toString=showCTR_L, toStringWithSize=showCTR_LWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       and desc_CELLSET = CellsBasis.DESC {low=34, high=33, kind=CELLSET, defaultValues=[], 
              zeroReg=NONE, toString=showCELLSET, toStringWithSize=showCELLSETWithSize, 
              counter=ref 0, dedicated=ref 0, physicalRegs=ref CellsBasis.array0}
       val cellKindDescs = [(CellsBasis.GP, desc_GP), (CellsBasis.FP, desc_FP), 
              (CellsBasis.CC, desc_GP), (EFLAGS, desc_EFLAGS), (FFLAGS, desc_FFLAGS), 
              (CellsBasis.MEM, desc_MEM), (CTR_L, desc_CTR_L), (CELLSET, desc_CELLSET)]
       val cellSize = 8
      )

   open MyCells
   val addGP = CellSet.add
   and addFP = CellSet.add
   and addCC = CellSet.add
   and addEFLAGS = CellSet.add
   and addFFLAGS = CellSet.add
   and addMEM = CellSet.add
   and addCTR_L = CellSet.add
   and addCELLSET = CellSet.add
   val RegGP = Reg GP
   and RegFP = Reg FP
   and RegCC = Reg CC
   and RegEFLAGS = Reg EFLAGS
   and RegFFLAGS = Reg FFLAGS
   and RegMEM = Reg MEM
   and RegCTR_L = Reg CTR_L
   and RegCELLSET = Reg CELLSET
   val rax = RegGP 0
   val rcx = RegGP 1
   val rdx = RegGP 2
   val rbx = RegGP 3
   val rsp = RegGP 4
   val rbp = RegGP 5
   val rsi = RegGP 6
   val rdi = RegGP 7
   val r8 = RegGP 8
   val r9 = RegGP 9
   val r10 = RegGP 10
   val r11 = RegGP 11
   val r12 = RegGP 12
   val r13 = RegGP 13
   val r14 = RegGP 14
   val r15 = RegGP 15
   val xmm0 = RegFP 0
   val xmm1 = RegFP 1
   val xmm2 = RegFP 2
   val xmm3 = RegFP 3
   val xmm4 = RegFP 4
   val xmm5 = RegFP 5
   val xmm6 = RegFP 6
   val xmm7 = RegFP 7
   val xmm8 = RegFP 8
   val xmm9 = RegFP 9
   val xmm10 = RegFP 10
   val xmm11 = RegFP 11
   val xmm12 = RegFP 12
   val xmm13 = RegFP 13
   val xmm14 = RegFP 14
   val xmm15 = RegFP 15
   val stackptrR = RegGP 4
   val asmTmpR = RegGP 0
   val fasmTmp = RegFP 0
   val eflags = RegEFLAGS 0
end

