(*
 * WARNING: This file was automatically generated by MDLGen (v3.0)
 * from the machine description file "hppa/hppa.mdl".
 * DO NOT EDIT this file directly
 *)


functor HppaMCEmitter(structure Instr : HPPAINSTR
                      structure MLTreeEval : MLTREE_EVAL where T = Instr.T
                      structure Stream : INSTRUCTION_STREAM 
                      structure CodeString : CODE_STRING
                     ) : INSTRUCTION_EMITTER =
struct
   structure I = Instr
   structure C = I.C
   structure Constant = I.Constant
   structure T = I.T
   structure S = Stream
   structure P = S.P
   structure W = Word32
   
   (* Hppa is big endian *)
   
   fun error msg = MLRiscErrorMsg.error("HppaMC",msg)
   fun makeStream _ =
   let infix && || << >> ~>>
       val op << = W.<<
       val op >> = W.>>
       val op ~>> = W.~>>
       val op || = W.orb
       val op && = W.andb
       val itow = W.fromInt
       fun emit_bool false = 0w0 : W.word
         | emit_bool true = 0w1 : W.word
       val emit_int = itow
       fun emit_word w = w
       fun emit_label l = itow(Label.addrOf l)
       fun emit_labexp le = itow(MLTreeEval.valueOf le)
       fun emit_const c = itow(Constant.valueOf c)
       val loc = ref 0
   
       (* emit a byte *)
       fun eByte b =
       let val i = !loc in loc := i + 1; CodeString.update(i,b) end
   
       (* emit the low order byte of a word *)
       (* note: fromLargeWord strips the high order bits! *)
       fun eByteW w =
       let val i = !loc
       in loc := i + 1; CodeString.update(i,Word8.fromLargeWord w) end
   
       fun doNothing _ = ()
       fun fail _ = raise Fail "MCEmitter"
       fun getAnnotations () = error "getAnnotations"
   
       fun pseudoOp pOp = P.emitValue{pOp=pOp, loc= !loc,emit=eByte}
   
       fun init n = (CodeString.init n; loc := 0)
   
   
   fun eWord32 w = 
       let val b8 = w
           val w = w >> 0wx8
           val b16 = w
           val w = w >> 0wx8
           val b24 = w
           val w = w >> 0wx8
           val b32 = w
       in 
          ( eByteW b32; 
            eByteW b24; 
            eByteW b16; 
            eByteW b8 )
       end
   fun emit_GP r = itow (CellsBasis.physicalRegisterNum r)
   and emit_FP r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CR r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CC r = itow (CellsBasis.physicalRegisterNum r)
   and emit_MEM r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CTRL r = itow (CellsBasis.physicalRegisterNum r)
   and emit_CELLSET r = itow (CellsBasis.physicalRegisterNum r)
   fun emit_fmt (I.SGL) = (0wx0 : Word32.word)
     | emit_fmt (I.DBL) = (0wx1 : Word32.word)
     | emit_fmt (I.QUAD) = (0wx3 : Word32.word)
   and emit_loadi (I.LDW) = (0wx12 : Word32.word)
     | emit_loadi (I.LDH) = (0wx11 : Word32.word)
     | emit_loadi (I.LDB) = (0wx10 : Word32.word)
   and emit_store (I.STW) = (0wx1a : Word32.word)
     | emit_store (I.STH) = (0wx19 : Word32.word)
     | emit_store (I.STB) = (0wx18 : Word32.word)
   and emit_load (I.LDWX) = (0wx2, 0wx0, 0wx0)
     | emit_load (I.LDWX_S) = (0wx2, 0wx1, 0wx0)
     | emit_load (I.LDWX_M) = (0wx2, 0wx0, 0wx1)
     | emit_load (I.LDWX_SM) = (0wx2, 0wx1, 0wx1)
     | emit_load (I.LDHX) = (0wx1, 0wx0, 0wx0)
     | emit_load (I.LDHX_S) = (0wx1, 0wx1, 0wx0)
     | emit_load (I.LDHX_M) = (0wx1, 0wx0, 0wx1)
     | emit_load (I.LDHX_SM) = (0wx1, 0wx1, 0wx1)
     | emit_load (I.LDBX) = (0wx0, 0wx0, 0wx0)
     | emit_load (I.LDBX_M) = (0wx0, 0wx0, 0wx1)
   and emit_cmp (I.COMBT) = (0wx20 : Word32.word)
     | emit_cmp (I.COMBF) = (0wx22 : Word32.word)
   and emit_cmpi (I.COMIBT) = (0wx21 : Word32.word)
     | emit_cmpi (I.COMIBF) = (0wx23 : Word32.word)
   and emit_arith (I.ADD) = (0wx18 : Word32.word)
     | emit_arith (I.ADDL) = (0wx28 : Word32.word)
     | emit_arith (I.ADDO) = (0wx38 : Word32.word)
     | emit_arith (I.SH1ADD) = (0wx19 : Word32.word)
     | emit_arith (I.SH1ADDL) = (0wx29 : Word32.word)
     | emit_arith (I.SH1ADDO) = (0wx39 : Word32.word)
     | emit_arith (I.SH2ADD) = (0wx1a : Word32.word)
     | emit_arith (I.SH2ADDL) = (0wx2a : Word32.word)
     | emit_arith (I.SH2ADDO) = (0wx3a : Word32.word)
     | emit_arith (I.SH3ADD) = (0wx1b : Word32.word)
     | emit_arith (I.SH3ADDL) = (0wx2b : Word32.word)
     | emit_arith (I.SH3ADDO) = (0wx3b : Word32.word)
     | emit_arith (I.SUB) = (0wx10 : Word32.word)
     | emit_arith (I.SUBO) = (0wx30 : Word32.word)
     | emit_arith (I.OR) = (0wx9 : Word32.word)
     | emit_arith (I.XOR) = (0wxa : Word32.word)
     | emit_arith (I.AND) = (0wx8 : Word32.word)
     | emit_arith (I.ANDCM) = (0wx0 : Word32.word)
   and emit_arithi (I.ADDI) = (0wx2d, 0wx0)
     | emit_arithi (I.ADDIO) = (0wx2d, 0wx1)
     | emit_arithi (I.ADDIL) = error "ADDIL"
     | emit_arithi (I.SUBI) = (0wx25, 0wx0)
     | emit_arithi (I.SUBIO) = (0wx25, 0wx1)
   and emit_farith (I.FADD_S) = (0wx0, 0wx0)
     | emit_farith (I.FADD_D) = (0wx0, 0wx1)
     | emit_farith (I.FADD_Q) = (0wx0, 0wx3)
     | emit_farith (I.FSUB_S) = (0wx1, 0wx0)
     | emit_farith (I.FSUB_D) = (0wx1, 0wx1)
     | emit_farith (I.FSUB_Q) = (0wx1, 0wx3)
     | emit_farith (I.FMPY_S) = (0wx2, 0wx0)
     | emit_farith (I.FMPY_D) = (0wx2, 0wx1)
     | emit_farith (I.FMPY_Q) = (0wx2, 0wx3)
     | emit_farith (I.FDIV_S) = (0wx3, 0wx0)
     | emit_farith (I.FDIV_D) = (0wx3, 0wx1)
     | emit_farith (I.FDIV_Q) = (0wx3, 0wx3)
     | emit_farith (I.XMPYU) = error "XMPYU"
   and emit_funary (I.FCPY_S) = (0wx2, 0wx0)
     | emit_funary (I.FCPY_D) = (0wx2, 0wx1)
     | emit_funary (I.FCPY_Q) = (0wx2, 0wx3)
     | emit_funary (I.FABS_S) = (0wx3, 0wx0)
     | emit_funary (I.FABS_D) = (0wx3, 0wx1)
     | emit_funary (I.FABS_Q) = (0wx3, 0wx3)
     | emit_funary (I.FSQRT_S) = (0wx4, 0wx0)
     | emit_funary (I.FSQRT_D) = (0wx4, 0wx1)
     | emit_funary (I.FSQRT_Q) = (0wx4, 0wx3)
     | emit_funary (I.FRND_S) = (0wx5, 0wx0)
     | emit_funary (I.FRND_D) = (0wx5, 0wx1)
     | emit_funary (I.FRND_Q) = (0wx5, 0wx3)
   and emit_fcnv (I.FCNVFF_SD) = (0wx0, 0wx0, 0wx1)
     | emit_fcnv (I.FCNVFF_SQ) = (0wx0, 0wx0, 0wx3)
     | emit_fcnv (I.FCNVFF_DS) = (0wx0, 0wx1, 0wx0)
     | emit_fcnv (I.FCNVFF_DQ) = (0wx0, 0wx1, 0wx3)
     | emit_fcnv (I.FCNVFF_QS) = (0wx0, 0wx3, 0wx0)
     | emit_fcnv (I.FCNVFF_QD) = (0wx0, 0wx3, 0wx1)
     | emit_fcnv (I.FCNVXF_S) = (0wx1, 0wx0, 0wx0)
     | emit_fcnv (I.FCNVXF_D) = (0wx1, 0wx0, 0wx1)
     | emit_fcnv (I.FCNVXF_Q) = (0wx1, 0wx0, 0wx3)
     | emit_fcnv (I.FCNVFX_S) = (0wx2, 0wx0, 0wx0)
     | emit_fcnv (I.FCNVFX_D) = (0wx2, 0wx1, 0wx0)
     | emit_fcnv (I.FCNVFX_Q) = (0wx2, 0wx3, 0wx0)
     | emit_fcnv (I.FCNVFXT_S) = (0wx3, 0wx0, 0wx0)
     | emit_fcnv (I.FCNVFXT_D) = (0wx3, 0wx1, 0wx0)
     | emit_fcnv (I.FCNVFXT_Q) = (0wx3, 0wx3, 0wx0)
   and emit_fstorex (I.FSTDX) = (0wxb, 0wx0, 0wx0, 0wx0)
     | emit_fstorex (I.FSTDX_S) = (0wxb, 0wx0, 0wx1, 0wx0)
     | emit_fstorex (I.FSTDX_M) = (0wxb, 0wx0, 0wx0, 0wx1)
     | emit_fstorex (I.FSTDX_SM) = (0wxb, 0wx0, 0wx1, 0wx1)
     | emit_fstorex (I.FSTWX) = (0wx9, 0wx1, 0wx0, 0wx0)
     | emit_fstorex (I.FSTWX_S) = (0wx9, 0wx1, 0wx1, 0wx0)
     | emit_fstorex (I.FSTWX_M) = (0wx9, 0wx1, 0wx0, 0wx1)
     | emit_fstorex (I.FSTWX_SM) = (0wx9, 0wx1, 0wx1, 0wx1)
   and emit_floadx (I.FLDDX) = (0wxb, 0wx0, 0wx0, 0wx0)
     | emit_floadx (I.FLDDX_S) = (0wxb, 0wx0, 0wx1, 0wx0)
     | emit_floadx (I.FLDDX_M) = (0wxb, 0wx0, 0wx0, 0wx1)
     | emit_floadx (I.FLDDX_SM) = (0wxb, 0wx0, 0wx1, 0wx1)
     | emit_floadx (I.FLDWX) = (0wx9, 0wx1, 0wx0, 0wx0)
     | emit_floadx (I.FLDWX_S) = (0wx9, 0wx1, 0wx1, 0wx0)
     | emit_floadx (I.FLDWX_M) = (0wx9, 0wx1, 0wx0, 0wx1)
     | emit_floadx (I.FLDWX_SM) = (0wx9, 0wx1, 0wx1, 0wx1)
   and emit_bcond (I.EQ) = (0wx1 : Word32.word)
     | emit_bcond (I.LT) = (0wx2 : Word32.word)
     | emit_bcond (I.LE) = (0wx3 : Word32.word)
     | emit_bcond (I.LTU) = (0wx4 : Word32.word)
     | emit_bcond (I.LEU) = (0wx5 : Word32.word)
     | emit_bcond (I.NE) = error "NE"
     | emit_bcond (I.GE) = error "GE"
     | emit_bcond (I.GT) = error "GT"
     | emit_bcond (I.GTU) = error "GTU"
     | emit_bcond (I.GEU) = error "GEU"
   and emit_bitcond (I.BSET) = (0wx2 : Word32.word)
     | emit_bitcond (I.BCLR) = (0wx6 : Word32.word)
   and emit_fcond (I.False_) = (0wx0 : Word32.word)
     | emit_fcond (I.False) = (0wx1 : Word32.word)
     | emit_fcond (I.?) = (0wx2 : Word32.word)
     | emit_fcond (I.!<=>) = (0wx3 : Word32.word)
     | emit_fcond (I.==) = (0wx4 : Word32.word)
     | emit_fcond (I.EQT) = (0wx5 : Word32.word)
     | emit_fcond (I.?=) = (0wx6 : Word32.word)
     | emit_fcond (I.!<>) = (0wx7 : Word32.word)
     | emit_fcond (I.!?>=) = (0wx8 : Word32.word)
     | emit_fcond (I.<) = (0wx9 : Word32.word)
     | emit_fcond (I.?<) = (0wxa : Word32.word)
     | emit_fcond (I.!>=) = (0wxb : Word32.word)
     | emit_fcond (I.!?>) = (0wxc : Word32.word)
     | emit_fcond (I.<=) = (0wxd : Word32.word)
     | emit_fcond (I.?<=) = (0wxe : Word32.word)
     | emit_fcond (I.!>) = (0wxf : Word32.word)
     | emit_fcond (I.!?<=) = (0wx10 : Word32.word)
     | emit_fcond (I.>) = (0wx11 : Word32.word)
     | emit_fcond (I.?>) = (0wx12 : Word32.word)
     | emit_fcond (I.!<=) = (0wx13 : Word32.word)
     | emit_fcond (I.!?<) = (0wx14 : Word32.word)
     | emit_fcond (I.>=) = (0wx15 : Word32.word)
     | emit_fcond (I.?>=) = (0wx16 : Word32.word)
     | emit_fcond (I.!<) = (0wx17 : Word32.word)
     | emit_fcond (I.!?=) = (0wx18 : Word32.word)
     | emit_fcond (I.<>) = (0wx19 : Word32.word)
     | emit_fcond (I.!=) = (0wx1a : Word32.word)
     | emit_fcond (I.NET) = (0wx1b : Word32.word)
     | emit_fcond (I.!?) = (0wx1c : Word32.word)
     | emit_fcond (I.<=>) = (0wx1d : Word32.word)
     | emit_fcond (I.True_) = (0wx1e : Word32.word)
     | emit_fcond (I.True) = (0wx1f : Word32.word)
   fun Load {Op, b, t, im14} = 
       let val b = emit_GP b
           val t = emit_GP t
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((t << 0wx10) + (im14 && 0wx3fff))))
       end
   and Store {st, b, r, im14} = 
       let val st = emit_store st
           val b = emit_GP b
           val r = emit_GP r
       in eWord32 ((st << 0wx1a) + ((b << 0wx15) + ((r << 0wx10) + (im14 && 0wx3fff))))
       end
   and IndexedLoad {Op, b, x, u, ext4, m, t} = 
       let val b = emit_GP b
           val x = emit_GP x
           val t = emit_GP t
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((x << 0wx10) + ((u << 0wxd) + ((ext4 << 0wx6) + ((m << 0wx5) + (t + 0wxc000)))))))
       end
   and ShortDispLoad {Op, b, im5, s, a, cc, ext4, m, t} = 
       let val b = emit_GP b
           val t = emit_GP t
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + (((im5 && 0wx1f) << 0wx10) + ((s << 0wxe) + ((a << 0wxd) + ((cc << 0wxa) + ((ext4 << 0wx6) + ((m << 0wx5) + (t + 0wx1000)))))))))
       end
   and ShoftDispShort {Op, b, r, s, a, cc, ext4, m, im5} = eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((r << 0wx10) + ((s << 0wxe) + ((a << 0wxd) + ((cc << 0wxa) + ((ext4 << 0wx6) + ((m << 0wx5) + ((im5 && 0wx1f) + 0wx1000)))))))))
   and LongImmed {Op, r, im21} = 
       let val r = emit_GP r
       in eWord32 ((Op << 0wx1a) + ((r << 0wx15) + (im21 && 0wx1fffff)))
       end
   and Arith {r2, r1, a, t} = 
       let val r2 = emit_GP r2
           val r1 = emit_GP r1
           val a = emit_arith a
           val t = emit_GP t
       in eWord32 ((r2 << 0wx15) + ((r1 << 0wx10) + ((a << 0wx6) + (t + 0wx8000000))))
       end
   and Arithi {Op, r, t, e, im11} = 
       let val r = emit_GP r
           val t = emit_GP t
       in eWord32 ((Op << 0wx1a) + ((r << 0wx15) + ((t << 0wx10) + ((e << 0wxb) + (im11 && 0wx7ff)))))
       end
   and Extract {Op, r, t, ext3, p, clen} = 
       let val r = emit_GP r
           val t = emit_GP t
           val p = emit_int p
           val clen = emit_int clen
       in eWord32 ((Op << 0wx1a) + ((r << 0wx15) + ((t << 0wx10) + ((ext3 << 0wxa) + ((p << 0wx5) + clen)))))
       end
   and Deposit {Op, t, r, ext3, cp, clen} = 
       let val t = emit_GP t
           val r = emit_GP r
           val cp = emit_int cp
           val clen = emit_int clen
       in eWord32 ((Op << 0wx1a) + ((t << 0wx15) + ((r << 0wx10) + ((ext3 << 0wxa) + ((cp << 0wx5) + clen)))))
       end
   and Shift {Op, r2, r1, ext3, cp, t} = 
       let val r2 = emit_GP r2
           val r1 = emit_GP r1
           val t = emit_GP t
       in eWord32 ((Op << 0wx1a) + ((r2 << 0wx15) + ((r1 << 0wx10) + ((ext3 << 0wxa) + ((cp << 0wx5) + t)))))
       end
   and ConditionalBranch {Op, r2, r1, c, w1, n, w} = 
       let val r2 = emit_GP r2
           val r1 = emit_GP r1
           val c = emit_bcond c
           val n = emit_bool n
       in eWord32 ((Op << 0wx1a) + ((r2 << 0wx15) + ((r1 << 0wx10) + ((c << 0wxd) + ((w1 << 0wx2) + ((n << 0wx1) + w))))))
       end
   and ConditionalBranchi {Op, r2, im5, c, w1, n, w} = 
       let val r2 = emit_GP r2
           val c = emit_bcond c
           val n = emit_bool n
       in eWord32 ((Op << 0wx1a) + ((r2 << 0wx15) + ((im5 << 0wx10) + ((c << 0wxd) + ((w1 << 0wx2) + ((n << 0wx1) + w))))))
       end
   and BranchExternal {Op, b, w1, s, w2, n, w} = 
       let val b = emit_GP b
           val n = emit_bool n
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((w1 << 0wx10) + ((s << 0wxd) + ((w2 << 0wx2) + ((n << 0wx1) + w))))))
       end
   and BranchAndLink {Op, t, w1, ext3, w2, n, w} = 
       let val t = emit_GP t
           val n = emit_bool n
       in eWord32 ((Op << 0wx1a) + ((t << 0wx15) + ((w1 << 0wx10) + ((ext3 << 0wxd) + ((w2 << 0wx2) + ((n << 0wx1) + w))))))
       end
   and BranchVectored {Op, t, x, ext3, n} = 
       let val t = emit_GP t
           val x = emit_GP x
           val n = emit_bool n
       in eWord32 ((Op << 0wx1a) + ((t << 0wx15) + ((x << 0wx10) + ((ext3 << 0wxd) + (n << 0wx1)))))
       end
   and Break {Op, im13, ext8, im5} = eWord32 ((Op << 0wx1a) + (((im13 && 0wx1fff) << 0wxd) + ((ext8 << 0wx5) + (im5 && 0wx1f))))
   and BranchOnBit {p, r, c, w1, n, w} = 
       let val p = emit_int p
           val r = emit_GP r
           val n = emit_bool n
       in eWord32 ((p << 0wx15) + ((r << 0wx10) + ((c << 0wxd) + ((w1 << 0wx2) + ((n << 0wx1) + (w + 0wxc4000000))))))
       end
   and MoveToControlReg {Op, t, r, rv, ext8} = 
       let val t = emit_CR t
           val r = emit_GP r
       in eWord32 ((Op << 0wx1a) + ((t << 0wx15) + ((r << 0wx10) + ((rv << 0wxd) + (ext8 << 0wx5)))))
       end
   and CompareClear {r2, r1, c, f, ext, t} = 
       let val r2 = emit_GP r2
           val r1 = emit_GP r1
           val t = emit_GP t
       in eWord32 ((r2 << 0wx15) + ((r1 << 0wx10) + ((c << 0wxd) + ((f << 0wxc) + ((ext << 0wx6) + (t + 0wx8000000))))))
       end
   and CompareImmClear {r, t, c, f, im11} = 
       let val r = emit_GP r
           val t = emit_GP t
       in eWord32 ((r << 0wx15) + ((t << 0wx10) + ((c << 0wxd) + ((f << 0wxc) + ((im11 && 0wx7ff) + 0wx90000000)))))
       end
   and CoProcShort {Op, b, im5, s, a, ls, uid, rt} = 
       let val b = emit_GP b
           val rt = emit_FP rt
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((im5 << 0wx10) + ((s << 0wxe) + ((a << 0wxd) + ((ls << 0wx9) + ((uid << 0wx6) + (rt + 0wx1000))))))))
       end
   and CoProcIndexed {Op, b, x, s, u, ls, uid, m, rt} = 
       let val b = emit_GP b
           val x = emit_GP x
           val rt = emit_FP rt
       in eWord32 ((Op << 0wx1a) + ((b << 0wx15) + ((x << 0wx10) + ((s << 0wxe) + ((u << 0wxd) + ((ls << 0wx9) + ((uid << 0wx6) + ((m << 0wx5) + rt))))))))
       end
   and NOP {} = eWord32 0wx8000240
   and Nop {nop} = (if nop
          then (NOP {})
          else ())
   and FloatOp0Maj0C {r, sop, fmt, t} = 
       let val r = emit_FP r
           val t = emit_FP t
       in eWord32 ((r << 0wx15) + ((sop << 0wxd) + ((fmt << 0wxb) + (t + 0wx30000000))))
       end
   and FloatOp1Maj0C {r, sop, df, sf, t} = 
       let val r = emit_FP r
           val t = emit_FP t
       in eWord32 ((r << 0wx15) + ((sop << 0wxf) + ((df << 0wxd) + ((sf << 0wxb) + (t + 0wx30000200)))))
       end
   and FloatOp2Maj0C {r1, r2, sop, fmt, n, c} = 
       let val r1 = emit_FP r1
           val r2 = emit_FP r2
       in eWord32 ((r1 << 0wx15) + ((r2 << 0wx10) + ((sop << 0wxd) + ((fmt << 0wxb) + ((n << 0wx5) + (c + 0wx30000400))))))
       end
   and FloatOp3Maj0C {r1, r2, sop, fmt, n, t} = 
       let val r1 = emit_FP r1
           val r2 = emit_FP r2
           val t = emit_FP t
       in eWord32 ((r1 << 0wx15) + ((r2 << 0wx10) + ((sop << 0wxd) + ((fmt << 0wxb) + ((n << 0wx5) + (t + 0wx30000600))))))
       end
   and FloatOp0Maj0E {r, sop, fmt, r2, t2, t} = 
       let val r = emit_FP r
           val t = emit_FP t
       in eWord32 ((r << 0wx15) + ((sop << 0wxd) + ((fmt << 0wxb) + ((r2 << 0wx7) + ((t2 << 0wx6) + (t + 0wx38000000))))))
       end
   and FloatOp1Maj0E {r, sop, df, sf, r2, t2, t} = 
       let val r = emit_FP r
           val t = emit_FP t
       in eWord32 ((r << 0wx15) + ((sop << 0wxf) + ((df << 0wxd) + ((sf << 0wxb) + ((r2 << 0wx7) + ((t2 << 0wx6) + (t + 0wx38000200)))))))
       end
   and FloatOp2Maj0E {r1, r2, sop, r22, f, r11, c} = 
       let val r1 = emit_FP r1
           val r2 = emit_FP r2
       in eWord32 ((r1 << 0wx15) + ((r2 << 0wx10) + ((sop << 0wxd) + ((r22 << 0wxc) + ((f << 0wxb) + ((r11 << 0wx7) + (c + 0wx38000400)))))))
       end
   and FloatOp3Maj0E {r1, r2, sop, r22, f, r11, t} = 
       let val r1 = emit_FP r1
           val r2 = emit_FP r2
           val t = emit_FP t
       in eWord32 ((r1 << 0wx15) + ((r2 << 0wx10) + ((sop << 0wxd) + ((r22 << 0wxc) + ((f << 0wxb) + ((r11 << 0wx7) + (t + 0wx38000600)))))))
       end
   and FloatMultiOp {rm1, rm2, ta, ra, f, tm} = eWord32 ((rm1 << 0wx15) + ((rm2 << 0wx10) + ((ta << 0wxb) + ((ra << 0wx6) + ((f << 0wx5) + (tm + 0wx38000000))))))
   and FTest {} = eWord32 0wx30002420

(*#line 644.7 "hppa/hppa.mdl"*)
   val zeroR = Option.valOf (C.zeroReg CellsBasis.GP)

(*#line 645.7 "hppa/hppa.mdl"*)
   fun opn opnd = 
       let 
(*#line 646.11 "hppa/hppa.mdl"*)
           fun hi21 n = (itow n) >> 0wxb

(*#line 647.11 "hppa/hppa.mdl"*)
           fun hi21X n = (itow n) ~>> 0wxb

(*#line 648.11 "hppa/hppa.mdl"*)
           fun lo11 n = (itow n) && 0wx7ff
       in 
          (case opnd of
            I.HILabExp(lexp, _) => hi21X (MLTreeEval.valueOf lexp)
          | I.LOLabExp(lexp, _) => lo11 (MLTreeEval.valueOf lexp)
          | I.LabExp(lexp, _) => itow (MLTreeEval.valueOf lexp)
          | I.IMMED i => itow i
          | I.REG _ => error "REG"
          )
       end

(*#line 659.6 "hppa/hppa.mdl"*)
   fun disp lab = (itow (((Label.addrOf lab) - ( ! loc)) - 8)) ~>> 0wx2

(*#line 660.6 "hppa/hppa.mdl"*)
   fun low_sign_ext_im14 n = ((n && 0wx1fff) << 0wx1) || ((n && 0wx2000) >> 0wxd)

(*#line 661.6 "hppa/hppa.mdl"*)
   fun low_sign_ext_im11 n = ((n && 0wx3ff) << 0wx1) || ((n && 0wx400) >> 0wxa)

(*#line 662.6 "hppa/hppa.mdl"*)
   fun low_sign_ext_im5 n = ((n && 0wxf) << 0wx1) || ((n && 0wx10) >> 0wx4)

(*#line 664.6 "hppa/hppa.mdl"*)
   fun assemble_3 n = 
       let 
(*#line 665.10 "hppa/hppa.mdl"*)
           val w1 = (n && 0wx4) >> 0wx2

(*#line 666.10 "hppa/hppa.mdl"*)
           val w2 = (n && 0wx3) << 0wx1
       in w1 || w2
       end

(*#line 669.6 "hppa/hppa.mdl"*)
   fun assemble_12 n = 
       let 
(*#line 670.10 "hppa/hppa.mdl"*)
           val w = (n && 0wx800) >> 0wxb

(*#line 671.10 "hppa/hppa.mdl"*)
           val w1 = ((n && 0wx3ff) << 0wx1) || ((n && 0wx400) >> 0wxa)
       in (w1, w)
       end

(*#line 674.6 "hppa/hppa.mdl"*)
   fun assemble_17 n = 
       let 
(*#line 675.10 "hppa/hppa.mdl"*)
           val w = (n && 0wx10000) >> 0wx10

(*#line 676.10 "hppa/hppa.mdl"*)
           val w1 = (n && 0wxf800) >> 0wxb

(*#line 677.10 "hppa/hppa.mdl"*)
           val w2 = ((n && 0wx3ff) << 0wx1) || ((n && 0wx400) >> 0wxa)
       in (w, w1, w2)
       end

(*#line 680.6 "hppa/hppa.mdl"*)
   fun assemble_21 disp = 
       let 
(*#line 681.10 "hppa/hppa.mdl"*)
           val w = (((((disp && 0wx3) << 0wxc) || ((disp && 0wx7c) << 0wxe)) || ((disp && 0wx180) << 0wx7)) || ((disp && 0wxffe00) >> 0wx8)) || ((disp && 0wx100000) >> 0wx14)
       in w
       end

(*#line 689.6 "hppa/hppa.mdl"*)
   fun branchLink (Op, t, lab, ext3, n) = 
       let 
(*#line 690.10 "hppa/hppa.mdl"*)
           val (w, w1, w2) = assemble_17 (disp lab)
       in BranchAndLink {Op=Op, t=t, w1=w1, w2=w2, w=w, ext3=ext3, n=n}
       end

(*#line 693.6 "hppa/hppa.mdl"*)
   fun bcond (cmp, bc, r1, r2, n, t, nop) = 
       let 
(*#line 694.10 "hppa/hppa.mdl"*)
           val (w1, w) = assemble_12 (disp t)
       in ConditionalBranch {Op=emit_cmp cmp, c=bc, r1=r1, r2=r2, n=n, w=w, 
             w1=w1}; 
          Nop {nop=nop}
       end

(*#line 697.6 "hppa/hppa.mdl"*)
   fun bcondi (cmpi, bc, i, r2, n, t, nop) = 
       let 
(*#line 698.10 "hppa/hppa.mdl"*)
           val (w1, w) = assemble_12 (disp t)
       in ConditionalBranchi {Op=emit_cmpi cmpi, c=bc, im5=low_sign_ext_im5 (itow i), 
             r2=r2, n=n, w=w, w1=w1}; 
          Nop {nop=nop}
       end

(*#line 702.6 "hppa/hppa.mdl"*)
   fun branchOnBit (bc, r, p, n, t, nop) = 
       let 
(*#line 703.10 "hppa/hppa.mdl"*)
           val (w1, w) = assemble_12 (disp t)
       in BranchOnBit {p=p, r=r, c=emit_bitcond bc, w1=w1, n=n, w=w}; 
          Nop {nop=nop}
       end

(*#line 707.6 "hppa/hppa.mdl"*)
   fun cmpCond cond = 
       (case cond of
         I.EQ => (0wx1, 0wx0)
       | I.LT => (0wx2, 0wx0)
       | I.LE => (0wx3, 0wx0)
       | I.LTU => (0wx4, 0wx0)
       | I.LEU => (0wx5, 0wx0)
       | I.NE => (0wx1, 0wx1)
       | I.GE => (0wx2, 0wx1)
       | I.GT => (0wx3, 0wx1)
       | I.GTU => (0wx4, 0wx1)
       | I.GEU => (0wx5, 0wx1)
       )
       fun emitter instr =
       let
   fun emitInstr (I.LOADI{li, r, i, t, mem}) = Load {Op=emit_loadi li, b=r, 
          im14=low_sign_ext_im14 (opn i), t=t}
     | emitInstr (I.LOAD{l, r1, r2, t, mem}) = 
       let 
(*#line 807.18 "hppa/hppa.mdl"*)
           val (ext4, u, m) = emit_load l
       in IndexedLoad {Op=0wx3, b=r1, x=r2, ext4=ext4, u=u, t=t, m=m}
       end
     | emitInstr (I.STORE{st, b, d, r, mem}) = Store {st=st, b=b, im14=low_sign_ext_im14 (opn d), 
          r=r}
     | emitInstr (I.ARITH{a, r1, r2, t}) = Arith {a=a, r1=r1, r2=r2, t=t}
     | emitInstr (I.ARITHI{ai, i, r, t}) = 
       (case ai of
         I.ADDIL => LongImmed {Op=0wxa, r=r, im21=assemble_21 (opn i)}
       | _ => 
         let 
(*#line 831.26 "hppa/hppa.mdl"*)
             val (Op, e) = emit_arithi ai
         in Arithi {Op=Op, r=r, t=t, im11=low_sign_ext_im11 (opn i), e=e}
         end
       )
     | emitInstr (I.COMCLR_LDO{cc, r1, r2, t1, i, b, t2}) = 
       let 
(*#line 850.17 "hppa/hppa.mdl"*)
           val (c, f) = cmpCond cc
       in CompareClear {r1=r1, r2=r2, t=t1, c=c, f=f, ext=0wx22}; 
          Load {Op=0wxd, b=b, im14=low_sign_ext_im14 (itow i), t=t2}
       end
     | emitInstr (I.COMICLR_LDO{cc, i1, r2, t1, i2, b, t2}) = 
       let 
(*#line 865.17 "hppa/hppa.mdl"*)
           val (c, f) = cmpCond cc
       in CompareImmClear {r=r2, t=t1, c=c, f=f, im11=low_sign_ext_im11 (opn i1)}; 
          Load {Op=0wxd, b=b, im14=low_sign_ext_im14 (itow i2), t=t2}
       end
     | emitInstr (I.SHIFTV{sv, r, len, t}) = 
       (case sv of
         I.VEXTRU => Extract {Op=0wx34, r=r, t=t, ext3=0wx4, p=0, clen=32 - len}
       | I.VEXTRS => Extract {Op=0wx34, r=r, t=t, ext3=0wx5, p=0, clen=32 - len}
       | I.ZVDEP => Deposit {Op=0wx35, t=t, r=r, ext3=0wx0, cp=0, clen=32 - len}
       )
     | emitInstr (I.SHIFT{s, r, p, len, t}) = 
       (case s of
         I.EXTRU => Extract {Op=0wx34, r=r, t=t, ext3=0wx6, p=p, clen=32 - len}
       | I.EXTRS => Extract {Op=0wx34, r=r, t=t, ext3=0wx7, p=p, clen=32 - len}
       | I.ZDEP => Deposit {Op=0wx35, t=t, r=r, ext3=0wx2, cp=31 - p, clen=32 - len}
       )
     | emitInstr (I.BCOND{cmp, bc, r1, r2, n, nop, t, f}) = bcond (cmp, bc, 
          r1, r2, n, t, nop)
     | emitInstr (I.BCONDI{cmpi, bc, i, r2, n, nop, t, f}) = bcondi (cmpi, 
          bc, i, r2, n, t, nop)
     | emitInstr (I.BB{bc, r, p, n, nop, t, f}) = branchOnBit (bc, r, p, n, 
          t, nop)
     | emitInstr (I.B{lab, n}) = branchLink (0wx3a, zeroR, lab, 0wx0, n)
     | emitInstr (I.LONGJUMP{lab, n, tmp, tmpLab}) = 
       let 
(*#line 963.18 "hppa/hppa.mdl"*)
           val offset = T.SUB (32, T.LABEL lab, T.ADD (32, T.LABEL tmpLab, 
                  T.LI (IntInf.fromInt 4)))
       in Label.setAddr (tmpLab, ( ! loc) + 4); 
          branchLink (0wx3a, tmp, tmpLab, 0wx0, n); 
          LongImmed {Op=0wxa, r=tmp, im21=assemble_21 (itow (MLTreeEval.valueOf offset))}; 
          BranchVectored {Op=0wx3a, t=tmp, x=zeroR, ext3=0wx6, n=n}
       end
     | emitInstr (I.BE{b, d, sr, n, labs}) = 
       let 
(*#line 980.18 "hppa/hppa.mdl"*)
           val (w, w1, w2) = assemble_17 (opn d)
       in BranchExternal {Op=0wx38, b=b, w1=w1, s=assemble_3 (itow sr), w2=w2, 
             n=n, w=w}
       end
     | emitInstr (I.BV{x, b, labs, n}) = BranchVectored {Op=0wx3a, t=b, x=x, 
          ext3=0wx6, n=n}
     | emitInstr (I.BLR{x, t, labs, n}) = BranchVectored {Op=0wx3a, t=t, x=x, 
          ext3=0wx2, n=n}
     | emitInstr (I.BL{lab, t, defs, uses, cutsTo, mem, n}) = branchLink (0wx3a, 
          t, lab, 0wx0, n)
     | emitInstr (I.BLE{d, b, sr, t, defs, uses, cutsTo, mem}) = 
       (case (d, CellsBasis.registerId t) of
         (I.IMMED 0, 31) => BranchExternal {Op=0wx39, b=b, w1=0wx0, s=assemble_3 (itow sr), 
            w2=0wx0, n=true, w=0wx0}
       | _ => error "BLE: not implemented"
       )
     | emitInstr (I.LDIL{i, t}) = LongImmed {Op=0wx8, r=t, im21=assemble_21 (opn i)}
     | emitInstr (I.LDO{i, b, t}) = Load {Op=0wxd, b=b, im14=low_sign_ext_im14 (opn i), 
          t=t}
     | emitInstr (I.MTCTL{r, t}) = MoveToControlReg {Op=0wx0, t=t, r=r, rv=0wx0, 
          ext8=0wxc2}
     | emitInstr (I.FSTORE{fst, b, d, r, mem}) = 
       (case fst of
         I.FSTDS => CoProcShort {Op=0wxb, b=b, im5=low_sign_ext_im5 (itow d), 
            s=0wx0, a=0wx0, ls=0wx1, uid=0wx0, rt=r}
       | I.FSTWS => CoProcShort {Op=0wx9, b=b, im5=low_sign_ext_im5 (itow d), 
            s=0wx0, a=0wx0, ls=0wx1, uid=0wx1, rt=r}
       )
     | emitInstr (I.FSTOREX{fstx, b, x, r, mem}) = 
       let 
(*#line 1064.18 "hppa/hppa.mdl"*)
           val (Op, uid, u, m) = emit_fstorex fstx
       in CoProcIndexed {Op=Op, b=b, x=x, s=0wx0, u=u, m=m, ls=0wx1, uid=uid, 
             rt=r}
       end
     | emitInstr (I.FLOAD{fl, b, d, t, mem}) = 
       (case fl of
         I.FLDDS => CoProcShort {Op=0wxb, b=b, im5=low_sign_ext_im5 (itow d), 
            s=0wx0, a=0wx0, ls=0wx0, uid=0wx0, rt=t}
       | I.FLDWS => CoProcShort {Op=0wx9, b=b, im5=low_sign_ext_im5 (itow d), 
            s=0wx0, a=0wx0, ls=0wx0, uid=0wx1, rt=t}
       )
     | emitInstr (I.FLOADX{flx, b, x, t, mem}) = 
       let 
(*#line 1084.18 "hppa/hppa.mdl"*)
           val (Op, uid, u, m) = emit_floadx flx
       in CoProcIndexed {Op=Op, b=b, x=x, s=0wx0, u=u, m=m, ls=0wx0, uid=uid, 
             rt=t}
       end
     | emitInstr (I.FARITH{fa, r1, r2, t}) = 
       (case fa of
         I.XMPYU => FloatOp3Maj0E {sop=0wx2, f=0wx1, r1=r1, r2=r2, t=t, r11=0wx0, 
            r22=0wx0}
       | _ => 
         let 
(*#line 1095.25 "hppa/hppa.mdl"*)
             val (sop, fmt) = emit_farith fa
         in FloatOp3Maj0C {sop=sop, r1=r1, r2=r2, t=t, n=0wx0, fmt=fmt}
         end
       )
     | emitInstr (I.FUNARY{fu, f, t}) = 
       let 
(*#line 1112.18 "hppa/hppa.mdl"*)
           val (sop, fmt) = emit_funary fu
       in FloatOp0Maj0C {r=f, t=t, sop=sop, fmt=fmt}
       end
     | emitInstr (I.FCNV{fcnv, f, t}) = 
       let 
(*#line 1121.18 "hppa/hppa.mdl"*)
           val (sop, sf, df) = emit_fcnv fcnv
       in FloatOp1Maj0E {r=f, t=t, sop=sop, sf=sf, df=df, r2=0wx1, t2=0wx0}
       end
     | emitInstr (I.FBRANCH{cc, fmt, f1, f2, t, f, n, long}) = 
       ( FloatOp2Maj0C {r1=f1, r2=f2, sop=0wx0, fmt=emit_fmt fmt, n=0wx0, c=emit_fcond cc}; 
         FTest {}; 
         branchLink (0wx3a, zeroR, t, 0wx0, n))
     | emitInstr (I.BREAK{code1, code2}) = error "BREAK"
     | emitInstr (I.NOP) = NOP {}
     | emitInstr (I.SOURCE{}) = ()
     | emitInstr (I.SINK{}) = ()
     | emitInstr (I.PHI{}) = ()
       in
           emitInstr instr
       end
   
   fun emitInstruction(I.ANNOTATION{i, ...}) = emitInstruction(i)
     | emitInstruction(I.INSTR(i)) = emitter(i)
     | emitInstruction(I.LIVE _)  = ()
     | emitInstruction(I.KILL _)  = ()
   | emitInstruction _ = error "emitInstruction"
   
   in  S.STREAM{beginCluster=init,
                pseudoOp=pseudoOp,
                emit=emitInstruction,
                endCluster=fail,
                defineLabel=doNothing,
                entryLabel=doNothing,
                comment=doNothing,
                exitBlock=doNothing,
                annotation=doNothing,
                getAnnotations=getAnnotations
               }
   end
end

