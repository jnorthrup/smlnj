(*
 * WARNING: This file was automatically generated by MDLGen (v3.0)
 * from the machine description file "ppc/ppc.mdl".
 * DO NOT EDIT this file directly
 *)


functor PPCAsmEmitter(structure Instr : PPCINSTR
                      structure Stream : INSTRUCTION_STREAM
                      structure Shuffle : PPCSHUFFLE
                         where I = Instr
                     ) : INSTRUCTION_EMITTER =
struct
   structure I  = Instr
   structure C  = I.C
   structure S  = Stream
   structure P  = S.P
   structure LabelExp = I.LabelExp
   structure Constant = I.Constant
   
   val show_cellset = MLRiscControl.getFlag "asm-show-cellset"
   val show_region  = MLRiscControl.getFlag "asm-show-region"
   val indent_copies = MLRiscControl.getFlag "asm-indent-copies"
   
   fun error msg = MLRiscErrorMsg.error("PPCAsmEmitter",msg)
   
   fun makeStream formatAnnotations =
   let val stream = !AsmStream.asmOutStream
       fun emit' s = TextIO.output(stream,s)
       val newline = ref true
       val tabs = ref 0
       fun tabbing 0 = ()
         | tabbing n = (emit' "\t"; tabbing(n-1))
       fun emit s = (tabbing(!tabs); tabs := 0; newline := false; emit' s)
       fun nl() = (tabs := 0; if !newline then () else (newline := true; emit' "\n"))
       fun comma() = emit ","
       fun tab() = tabs := 1
       fun indent() = tabs := 2
       fun ms n = let val s = Int.toString n
                  in  if n<0 then "-"^String.substring(s,1,size s-1)
                      else s
                  end
       fun emit_label lab = emit(Label.nameOf lab)
       fun emit_labexp le = emit(LabelExp.toString le)
       fun emit_const c = emit(Constant.toString c)
       fun emit_int i = emit(ms i)
       fun paren f = (emit "("; f(); emit ")")
       fun defineLabel lab = emit(Label.nameOf lab^":\n")
       fun entryLabel lab = defineLabel lab
       fun comment msg = (tab(); emit("/* " ^ msg ^ " */"))
       fun annotation a = (comment(Annotations.toString a); nl())
       fun doNothing _ = ()
       fun emit_region mem = comment(I.Region.toString mem)
       val emit_region = 
          if !show_region then emit_region else doNothing
       fun pseudoOp pOp = emit(P.toString pOp)
       fun init size = (comment("Code Size = " ^ ms size); nl())
       val emitCellInfo = AsmFormatUtil.reginfo
                                (emit,formatAnnotations)
       fun emitCell r = (emit(C.toString r); emitCellInfo r)
       fun emit_cellset(title,cellset) =
         (nl(); comment(title^C.CellSet.toString cellset))
       val emit_cellset = 
         if !show_cellset then emit_cellset else doNothing
       fun emit_defs cellset = emit_cellset("defs: ",cellset)
       fun emit_uses cellset = emit_cellset("uses: ",cellset)
       fun emitter instr =
       let
   fun asm_spr (I.XER) = "xer"
     | asm_spr (I.LR) = "lr"
     | asm_spr (I.CTR) = "ctr"
   and emit_spr x = emit (asm_spr x)
   and emit_operand (I.RegOp GP) = emitCell GP
     | emit_operand (I.ImmedOp int) = emit_int int
     | emit_operand (I.LabelOp labexp) = emit_labexp labexp
   and asm_load (I.LBZ) = "lbz"
     | asm_load (I.LBZE) = "lbze"
     | asm_load (I.LHZ) = "lhz"
     | asm_load (I.LHZE) = "lhze"
     | asm_load (I.LHA) = "lha"
     | asm_load (I.LHAE) = "lhae"
     | asm_load (I.LWZ) = "lwz"
     | asm_load (I.LWZE) = "lwze"
     | asm_load (I.LDE) = "lde"
   and emit_load x = emit (asm_load x)
   and asm_store (I.STB) = "stb"
     | asm_store (I.STBE) = "stbe"
     | asm_store (I.STH) = "sth"
     | asm_store (I.STHE) = "sthe"
     | asm_store (I.STW) = "stw"
     | asm_store (I.STWE) = "stwe"
     | asm_store (I.STDE) = "stde"
   and emit_store x = emit (asm_store x)
   and asm_fload (I.LFS) = "lfs"
     | asm_fload (I.LFSE) = "lfse"
     | asm_fload (I.LFD) = "lfd"
     | asm_fload (I.LFDE) = "lfde"
   and emit_fload x = emit (asm_fload x)
   and asm_fstore (I.STFS) = "stfs"
     | asm_fstore (I.STFSE) = "stfse"
     | asm_fstore (I.STFD) = "stfd"
     | asm_fstore (I.STFDE) = "stfde"
   and emit_fstore x = emit (asm_fstore x)
   and asm_cmp (I.CMP) = "cmp"
     | asm_cmp (I.CMPL) = "cmpl"
   and emit_cmp x = emit (asm_cmp x)
   and asm_fcmp (I.FCMPO) = "fcmpo"
     | asm_fcmp (I.FCMPU) = "fcmpu"
   and emit_fcmp x = emit (asm_fcmp x)
   and asm_unary (I.NEG) = "neg"
     | asm_unary (I.EXTSB) = "extsb"
     | asm_unary (I.EXTSH) = "extsh"
     | asm_unary (I.EXTSW) = "extsw"
     | asm_unary (I.CNTLZW) = "cntlzw"
     | asm_unary (I.CNTLZD) = "cntlzd"
   and emit_unary x = emit (asm_unary x)
   and asm_funary (I.FMR) = "fmr"
     | asm_funary (I.FNEG) = "fneg"
     | asm_funary (I.FABS) = "fabs"
     | asm_funary (I.FNABS) = "fnabs"
     | asm_funary (I.FSQRT) = "fsqrt"
     | asm_funary (I.FSQRTS) = "fsqrts"
     | asm_funary (I.FRSP) = "frsp"
     | asm_funary (I.FCTIW) = "fctiw"
     | asm_funary (I.FCTIWZ) = "fctiwz"
     | asm_funary (I.FCTID) = "fctid"
     | asm_funary (I.FCTIDZ) = "fctidz"
     | asm_funary (I.FCFID) = "fcfid"
   and emit_funary x = emit (asm_funary x)
   and asm_farith (I.FADD) = "fadd"
     | asm_farith (I.FSUB) = "fsub"
     | asm_farith (I.FMUL) = "fmul"
     | asm_farith (I.FDIV) = "fdiv"
     | asm_farith (I.FADDS) = "fadds"
     | asm_farith (I.FSUBS) = "fsubs"
     | asm_farith (I.FMULS) = "fmuls"
     | asm_farith (I.FDIVS) = "fdivs"
   and emit_farith x = emit (asm_farith x)
   and asm_farith3 (I.FMADD) = "fmadd"
     | asm_farith3 (I.FMADDS) = "fmadds"
     | asm_farith3 (I.FMSUB) = "fmsub"
     | asm_farith3 (I.FMSUBS) = "fmsubs"
     | asm_farith3 (I.FNMADD) = "fnmadd"
     | asm_farith3 (I.FNMADDS) = "fnmadds"
     | asm_farith3 (I.FNMSUB) = "fnmsub"
     | asm_farith3 (I.FNMSUBS) = "fnmsubs"
     | asm_farith3 (I.FSEL) = "fsel"
   and emit_farith3 x = emit (asm_farith3 x)
   and asm_arith (I.ADD) = "add"
     | asm_arith (I.SUBF) = "subf"
     | asm_arith (I.MULLW) = "mullw"
     | asm_arith (I.MULLD) = "mulld"
     | asm_arith (I.MULHW) = "mulhw"
     | asm_arith (I.MULHWU) = "mulhwu"
     | asm_arith (I.DIVW) = "divw"
     | asm_arith (I.DIVD) = "divd"
     | asm_arith (I.DIVWU) = "divwu"
     | asm_arith (I.DIVDU) = "divdu"
     | asm_arith (I.AND) = "and"
     | asm_arith (I.OR) = "or"
     | asm_arith (I.XOR) = "xor"
     | asm_arith (I.NAND) = "nand"
     | asm_arith (I.NOR) = "nor"
     | asm_arith (I.EQV) = "eqv"
     | asm_arith (I.ANDC) = "andc"
     | asm_arith (I.ORC) = "orc"
     | asm_arith (I.SLW) = "slw"
     | asm_arith (I.SLD) = "sld"
     | asm_arith (I.SRW) = "srw"
     | asm_arith (I.SRD) = "srd"
     | asm_arith (I.SRAW) = "sraw"
     | asm_arith (I.SRAD) = "srad"
   and emit_arith x = emit (asm_arith x)
   and asm_arithi (I.ADDI) = "addi"
     | asm_arithi (I.ADDIS) = "addis"
     | asm_arithi (I.SUBFIC) = "subfic"
     | asm_arithi (I.MULLI) = "mulli"
     | asm_arithi (I.ANDI_Rc) = "andi."
     | asm_arithi (I.ANDIS_Rc) = "andis."
     | asm_arithi (I.ORI) = "ori"
     | asm_arithi (I.ORIS) = "oris"
     | asm_arithi (I.XORI) = "xori"
     | asm_arithi (I.XORIS) = "xoris"
     | asm_arithi (I.SRAWI) = "srawi"
     | asm_arithi (I.SRADI) = "sradi"
   and emit_arithi x = emit (asm_arithi x)
   and asm_rotate (I.RLWNM) = "rlwnm"
     | asm_rotate (I.RLDCL) = "rldcl"
     | asm_rotate (I.RLDCR) = "rldcr"
   and emit_rotate x = emit (asm_rotate x)
   and asm_rotatei (I.RLWINM) = "rlwinm"
     | asm_rotatei (I.RLWIMI) = "rlwimi"
     | asm_rotatei (I.RLDICL) = "rldicl"
     | asm_rotatei (I.RLDICR) = "rldicr"
     | asm_rotatei (I.RLDIC) = "rldic"
     | asm_rotatei (I.RLDIMI) = "rldimi"
   and emit_rotatei x = emit (asm_rotatei x)
   and asm_ccarith (I.CRAND) = "crand"
     | asm_ccarith (I.CROR) = "cror"
     | asm_ccarith (I.CRXOR) = "crxor"
     | asm_ccarith (I.CRNAND) = "crnand"
     | asm_ccarith (I.CRNOR) = "crnor"
     | asm_ccarith (I.CREQV) = "creqv"
     | asm_ccarith (I.CRANDC) = "crandc"
     | asm_ccarith (I.CRORC) = "crorc"
   and emit_ccarith x = emit (asm_ccarith x)
   and asm_bit (I.LT) = "lt"
     | asm_bit (I.GT) = "gt"
     | asm_bit (I.EQ) = "eq"
     | asm_bit (I.SO) = "so"
     | asm_bit (I.FL) = "lt"
     | asm_bit (I.FG) = "gt"
     | asm_bit (I.FE) = "eq"
     | asm_bit (I.FU) = "un"
     | asm_bit (I.FX) = "lt"
     | asm_bit (I.FEX) = "gt"
     | asm_bit (I.VX) = "eq"
     | asm_bit (I.OX) = "so"
   and emit_bit x = emit (asm_bit x)

(*#line 563.7 "ppc/ppc.mdl"*)
   fun emitx (s, I.RegOp _) = (if ((String.sub (s, (size s) - 1)) = #"e")
          then 
          ( emit (String.substring (s, 0, (size s) - 1)); 
            emit "xe" )
          else 
          ( emit s; 
            emit "x" ))
     | emitx (s, _) = emit s

(*#line 569.7 "ppc/ppc.mdl"*)
   fun eOERc {OE=false, Rc=false} = ()
     | eOERc {OE=false, Rc=true} = emit "."
     | eOERc {OE=true, Rc=false} = emit "o"
     | eOERc {OE=true, Rc=true} = emit "o."

(*#line 573.7 "ppc/ppc.mdl"*)
   fun eRc false = ""
     | eRc true = "."

(*#line 574.7 "ppc/ppc.mdl"*)
   fun cr_bit (cr, bit) = (4 * (C.physicalRegisterNum cr)) + 
       (case bit of
         I.LT => 0
       | I.GT => 1
       | I.EQ => 2
       | I.SO => 3
       | I.FL => 0
       | I.FG => 1
       | I.FE => 2
       | I.FU => 3
       | I.FX => 0
       | I.FEX => 1
       | I.VX => 2
       | I.OX => 3
       )

(*#line 581.7 "ppc/ppc.mdl"*)
   fun eCRbit x = emit (Int.toString (cr_bit x))

(*#line 582.7 "ppc/ppc.mdl"*)
   fun eLK true = emit "l"
     | eLK false = ()

(*#line 583.7 "ppc/ppc.mdl"*)
   fun eI (I.RegOp _) = ()
     | eI _ = emit "i"

(*#line 584.7 "ppc/ppc.mdl"*)
   fun eBI (bo, bf, bit) = 
       (case (bo, C.physicalRegisterNum bf) of
         (I.ALWAYS, _) => ()
       | (I.COUNTER{cond=NONE, ...}, _) => ()
       | (_, 0) => emit (asm_bit bit)
       | (_, n) => emit ((("4*cr" ^ (Int.toString n)) ^ "+") ^ (asm_bit bit))
       )

(*#line 590.7 "ppc/ppc.mdl"*)
   fun emit_bo bo = emit 
       (case bo of
         I.TRUE => "t"
       | I.FALSE => "f"
       | I.ALWAYS => ""
       | I.COUNTER{eqZero, cond=NONE} => (if eqZero
            then "dz"
            else "dnz")
       | I.COUNTER{eqZero, cond=SOME cc} => (if eqZero
            then "dz"
            else "dnz") ^ (if cc
            then "t"
            else "f")
       )

(*#line 601.7 "ppc/ppc.mdl"*)
   fun eME (SOME me) = 
       ( emit ", "; 
         emit_int me )
     | eME NONE = ()

(*#line 604.7 "ppc/ppc.mdl"*)
   fun addr (ra, I.RegOp rb) = 
       ( emitCell ra; 
         emit ", "; 
         emitCell rb )
     | addr (ra, d) = 
       ( emit_operand d; 
         emit "("; 
         emitCell ra; 
         emit ")" )
   fun emitInstr' instr = 
       (case instr of
         I.L{ld, rt, ra, d, mem} => 
         ( emitx (asm_load ld, d); 
           emit "\t"; 
           emitCell rt; 
           emit ", "; 
           addr (ra, d); 
           emit_region mem )
       | I.LF{ld, ft, ra, d, mem} => 
         ( emitx (asm_fload ld, d); 
           emit "\t"; 
           emitCell ft; 
           emit ", "; 
           addr (ra, d); 
           emit_region mem )
       | I.ST{st, rs, ra, d, mem} => 
         ( emitx (asm_store st, d); 
           emit "\t"; 
           emitCell rs; 
           emit ", "; 
           addr (ra, d); 
           emit_region mem )
       | I.STF{st, fs, ra, d, mem} => 
         ( emitx (asm_fstore st, d); 
           emit "\t"; 
           emitCell fs; 
           emit ", "; 
           addr (ra, d); 
           emit_region mem )
       | I.UNARY{oper, rt, ra, Rc, OE} => 
         ( emit_unary oper; 
           eOERc {Rc=Rc, OE=OE}; 
           emit "\t"; 
           emitCell rt; 
           emit ", "; 
           emitCell ra )
       | I.ARITH{oper, rt, ra, rb, Rc, OE} => 
         ( emit_arith oper; 
           eOERc {Rc=Rc, OE=OE}; 
           emit "\t"; 
           emitCell rt; 
           emit ", "; 
           emitCell ra; 
           emit ", "; 
           emitCell rb )
       | I.ARITHI{oper, rt, ra, im} => 
         ( emit_arithi oper; 
           emit "\t"; 
           emitCell rt; 
           emit ", "; 
           emitCell ra; 
           emit ", "; 
           emit_operand im )
       | I.ROTATE{oper, ra, rs, sh, mb, me} => 
         ( emit_rotate oper; 
           emit "\t"; 
           emitCell ra; 
           emit ", "; 
           emitCell rs; 
           emit ", "; 
           emitCell sh; 
           emit ", "; 
           emit_int mb; 
           eME me )
       | I.ROTATEI{oper, ra, rs, sh, mb, me} => 
         ( emit_rotatei oper; 
           emit "\t"; 
           emitCell ra; 
           emit ", "; 
           emitCell rs; 
           emit ", "; 
           emit_operand sh; 
           emit ", "; 
           emit_int mb; 
           eME me )
       | I.COMPARE{cmp, l, bf, ra, rb} => 
         ( emit_cmp cmp; 
           eI rb; 
           emit "\t"; 
           emitCell bf; 
           emit ", "; 
           emit (if l
              then "1"
              else "0"); 
           emit ", "; 
           emitCell ra; 
           emit ", "; 
           emit_operand rb )
       | I.FCOMPARE{cmp, bf, fa, fb} => 
         ( emit_fcmp cmp; 
           emit "\t"; 
           emitCell bf; 
           emit ", "; 
           emitCell fa; 
           emit ", "; 
           emitCell fb )
       | I.FUNARY{oper, ft, fb, Rc} => 
         ( emit_funary oper; 
           eRc Rc; 
           emit "\t"; 
           emitCell ft; 
           emit ", "; 
           emitCell fb )
       | I.FARITH{oper, ft, fa, fb, Rc} => 
         ( emit_farith oper; 
           eRc Rc; 
           emit "\t"; 
           emitCell ft; 
           emit ", "; 
           emitCell fa; 
           emit ", "; 
           emitCell fb )
       | I.FARITH3{oper, ft, fa, fb, fc, Rc} => 
         ( emit_farith3 oper; 
           eRc Rc; 
           emit "\t"; 
           emitCell ft; 
           emit ", "; 
           emitCell fa; 
           emit ", "; 
           emitCell fb; 
           emit ", "; 
           emitCell fc )
       | I.CCARITH{oper, bt, ba, bb} => 
         ( emit_ccarith oper; 
           emit "\t"; 
           eCRbit bt; 
           emit ", "; 
           eCRbit ba; 
           emit ", "; 
           eCRbit bb )
       | I.MCRF{bf, bfa} => 
         ( emit "mcrf\t"; 
           emitCell bf; 
           emit ", "; 
           emitCell bfa )
       | I.MTSPR{rs, spr} => 
         ( emit "mt"; 
           emitCell spr; 
           emit "\t"; 
           emitCell rs )
       | I.MFSPR{rt, spr} => 
         ( emit "mf"; 
           emitCell spr; 
           emit "\t"; 
           emitCell rt )
       | I.TW{to, ra, si} => 
         ( emit "tw"; 
           eI si; 
           emit "\t"; 
           emit_int to; 
           emit ", "; 
           emitCell ra; 
           emit ", "; 
           emit_operand si )
       | I.TD{to, ra, si} => 
         ( emit "td"; 
           eI si; 
           emit "\t"; 
           emit_int to; 
           emit ", "; 
           emitCell ra; 
           emit ", "; 
           emit_operand si )
       | I.BC{bo, bf, bit, addr, LK, fall} => 
         ( emit "b"; 
           emit_bo bo; 
           eLK LK; 
           emit "\t"; 
           eBI (bo, bf, bit); 
           emit ", "; 
           emit_operand addr )
       | I.BCLR{bo, bf, bit, LK, labels} => 
         ( emit "b"; 
           emit_bo bo; 
           emit "lr"; 
           eLK LK; 
           emit "\t"; 
           eBI (bo, bf, bit))
       | I.B{addr, LK} => 
         ( emit "b"; 
           eLK LK; 
           emit "\t"; 
           emit_operand addr )
       | I.CALL{def, use, mem} => 
         ( emit "blrl"; 
           emit_region mem; 
           emit_defs def; 
           emit_uses use )
       | I.COPY{dst, src, impl, tmp} => emitInstrs (Shuffle.shuffle {tmp=tmp, 
            dst=dst, src=src})
       | I.FCOPY{dst, src, impl, tmp} => emitInstrs (Shuffle.shufflefp {tmp=tmp, 
            dst=dst, src=src})
       | I.ANNOTATION{i, a} => 
         ( comment (Annotations.toString a); 
           nl (); 
           emitInstr i )
       | I.SOURCE{} => emit "source"
       | I.SINK{} => emit "sink"
       | I.PHI{} => emit "phi"
       )
          and emitInstr i = (tab(); emitInstr' i; nl())
          and emitInstrIndented i = (indent(); emitInstr' i; nl())
          and emitInstrs instrs =
           app (if !indent_copies then emitInstrIndented
                else emitInstr) instrs
      in  emitInstr instr end
   
   in  S.STREAM{beginCluster=init,
                pseudoOp=pseudoOp,
                emit=emitter,
                endCluster=doNothing,
                defineLabel=defineLabel,
                entryLabel=entryLabel,
                comment=comment,
                exitBlock=doNothing,
                annotation=annotation
               }
   end
end

