(* alpha32Rewrite.sml -- rewrite an alpha instruction 
 *
 * COPYRIGHT (c) 1997 Bell Labs
 *)
functor X86Rewrite(Instr : X86INSTR) : X86REWRITE = struct
  structure I=Instr
  structure C=I.C

  fun operand (rs,rt) opnd =
    (case opnd
     of I.Direct r => if C.sameColor(r,rs) then I.Direct rt else opnd
      | I.Displace{base, disp, mem} => 
	  if C.sameColor(base,rs) then I.Displace{base=rt, disp=disp, mem=mem} 
          else opnd
      | I.Indexed{base as SOME b, index, scale, disp, mem} => let
	  val base'= if C.sameColor(b,rs) then SOME rt else base
	  val index'=if C.sameColor(index,rs) then rt else index
	in I.Indexed{base=base', index=index', scale=scale, disp=disp, mem=mem}
	end
      | I.Indexed{base, index, scale, disp, mem=mem}  => 
	if C.sameColor(index,rs) then 
	  I.Indexed{base=base, index=rt, scale=scale, disp=disp, mem=mem}
	else opnd
      | _ => opnd
    (*esac*))

  fun rewriteUse(instr, rs, rt) = let
    val operand = operand (rs, rt)
    fun replace r = if C.sameColor(r,rs) then rt else r
  in
    case instr
    of I.JMP(opnd, labs) => I.JMP(operand opnd, labs)
     | I.JCC{cond, opnd} => I.JCC{cond=cond, opnd = operand opnd}
     | I.CALL{opnd, defs, uses, return, cutsTo, mem} => 
         I.CALL{opnd=operand opnd, defs=defs, return=return,
                uses=C.CellSet.map {from=rs,to=rt} uses, cutsTo=cutsTo,
                mem=mem}
     | I.MOVE{mvOp, src, dst as I.Direct _} => 
         I.MOVE{mvOp=mvOp, src=operand src, dst=dst}
     | I.MOVE{mvOp, src, dst} => 
         I.MOVE{mvOp=mvOp, src=operand src, dst=operand dst}
     | I.LEA{r32, addr} => I.LEA{r32=r32, addr=operand addr}
     | I.CMPL{lsrc, rsrc} => I.CMPL{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.CMPW{lsrc, rsrc} => I.CMPW{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.CMPB{lsrc, rsrc} => I.CMPB{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.TESTL{lsrc, rsrc} => I.TESTL{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.TESTW{lsrc, rsrc} => I.TESTW{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.TESTB{lsrc, rsrc} => I.TESTB{lsrc=operand lsrc, rsrc=operand rsrc}
     | I.BITOP{bitOp, lsrc, rsrc} => 
        I.BITOP{bitOp=bitOp, lsrc=operand lsrc, rsrc=operand rsrc}
     | I.BINARY{binOp, src, dst} => 
	I.BINARY{binOp=binOp, src=operand src, dst=operand dst}
     | I.CMPXCHG{lock, sz, src, dst} => 
	I.CMPXCHG{lock=lock, sz=sz, src=operand src, dst=operand dst}
     | I.MULTDIV{multDivOp, src} => 
	I.MULTDIV{multDivOp=multDivOp, src=operand src}
     | I.MUL3{dst, src1, src2} => 
	I.MUL3{dst=dst, src1=operand src1, src2=src2}
     | I.UNARY{unOp, opnd} => I.UNARY{unOp=unOp, opnd=operand opnd}
     | I.SET{cond, opnd} => I.SET{cond=cond, opnd=operand opnd}
     | I.PUSHL opnd => I.PUSHL(operand opnd)
     | I.PUSHW opnd => I.PUSHW(operand opnd)
     | I.PUSHB opnd => I.PUSHB(operand opnd)
     | I.POP opnd  => I.POP(operand opnd)
     | I.COPY{dst, src, tmp} => 
	I.COPY{dst=dst, src=map replace src, tmp=tmp}
     | I.FSTPT opnd => I.FSTPT(operand opnd)
     | I.FSTPL opnd => I.FSTPL(operand opnd)
     | I.FSTPS opnd => I.FSTPS(operand opnd)
     | I.FSTL opnd => I.FSTL(operand opnd)
     | I.FSTS opnd => I.FSTS(operand opnd)
     | I.FLDT opnd => I.FLDT(operand opnd)
     | I.FLDL opnd => I.FLDL(operand opnd)
     | I.FLDS opnd => I.FLDS(operand opnd)
     | I.FUCOM opnd => I.FUCOM(operand opnd)
     | I.FUCOMP opnd => I.FUCOMP(operand opnd)
     | I.FENV{fenvOp,opnd} => I.FENV{fenvOp=fenvOp, opnd=operand opnd}
     | I.FBINARY{binOp, src, dst} => 
	I.FBINARY{binOp=binOp, src=operand src, dst=dst}
     | I.FIBINARY{binOp, src} => 
	I.FIBINARY{binOp=binOp, src=operand src}

       (* Pseudo floating point instructions *)
     | I.FMOVE{fsize,src,dst} => 
        I.FMOVE{fsize=fsize,src=operand src,dst=operand dst}
     | I.FILOAD{isize,ea,dst} => 
        I.FILOAD{isize=isize,ea=operand ea,dst=operand dst}
     | I.FBINOP{fsize,binOp,lsrc,rsrc,dst} =>
        I.FBINOP{fsize=fsize,binOp=binOp,
                 lsrc=operand lsrc,rsrc=operand rsrc,dst=operand dst}
     | I.FIBINOP{isize,binOp,lsrc,rsrc,dst} =>
        I.FIBINOP{isize=isize,binOp=binOp,
                  lsrc=operand lsrc,rsrc=operand rsrc,dst=operand dst}
     | I.FUNOP{fsize,unOp,src,dst} =>
        I.FUNOP{fsize=fsize,unOp=unOp,src=operand src,dst=operand dst}
     | I.FCMP{fsize,lsrc,rsrc} =>
        I.FCMP{fsize=fsize,lsrc=operand lsrc,rsrc=operand rsrc}

     | I.CMOV{cond, src, dst} => I.CMOV{cond=cond, src=operand src, dst=dst}
     | I.ANNOTATION{i,a}=> 
        I.ANNOTATION{i=rewriteUse(i,rs,rt),
                        a=case a of
                           C.DEF_USE{cellkind=C.GP,defs,uses} =>
                             C.DEF_USE{cellkind=C.GP,uses=map replace uses,
                                       defs=defs}
                          | _ => a}
     | _ => instr
  end (* rewriteUse *)

  fun rewriteDef(instr, rs, rt) = let
    fun operand(opnd as I.Direct r) = 
           if C.sameColor(r,rs) then I.Direct rt else opnd
    fun replace r = if C.sameColor(r,rs) then rt else r
  in
    case instr 
    of I.CALL{opnd, defs, uses, return, cutsTo, mem} => 
         I.CALL{opnd=opnd, cutsTo=cutsTo, 
                return=C.CellSet.map {from=rs,to=rt} return,
                defs=C.CellSet.map {from=rs,to=rt} defs, uses=uses, mem=mem}
     | I.MOVE{mvOp, src, dst} => I.MOVE{mvOp=mvOp, src=src, dst=operand dst}
     | I.LEA{r32, addr} => I.LEA{r32=replace r32, addr=addr}
     | I.BINARY{binOp, src, dst} => I.BINARY{binOp=binOp, src=src, dst=operand dst}
     | I.CMPXCHG{lock, sz, src, dst} => 
	I.CMPXCHG{lock=lock, sz=sz, src=src, dst=operand dst}
     | I.MUL3{dst, src1, src2} => I.MUL3{dst=replace dst, src1=src1, src2=src2}
     | I.UNARY{unOp, opnd} => I.UNARY{unOp=unOp, opnd=operand opnd}
     | I.SET{cond, opnd} => I.SET{cond=cond, opnd=operand opnd}
     | I.COPY{dst, src, tmp} => I.COPY{dst=map replace dst, src=src, tmp=tmp}
     | I.CMOV{cond, src, dst} => I.CMOV{cond=cond, src=src, dst=replace dst}
     | I.ANNOTATION{i,a}=> 
         I.ANNOTATION{i=rewriteDef(i,rs,rt),
                        a=case a of
                           C.DEF_USE{cellkind=C.GP,defs,uses} =>
                             C.DEF_USE{cellkind=C.GP,uses=uses,
                                       defs=map replace defs}
                          | _ => a}

     | _ => instr
  end


  fun frewriteUse(instr, fs, ft) = let
    fun foperand(opnd as I.FDirect f) = 
         if C.sameColor(f,fs) then I.FDirect ft else opnd
      | foperand(opnd as I.FPR f) = 
         if C.sameColor(f,fs) then I.FPR ft else opnd
      | foperand opnd = opnd

    fun replace f = if C.sameColor(f,fs) then ft else f
  in
    case instr
    of I.FCOPY{dst, src, tmp,...} => I.FCOPY{dst=dst, src=map replace src, tmp=tmp}
     | I.FLDL opnd => I.FLDL(foperand opnd)
     | I.FLDS opnd => I.FLDS(foperand opnd)
     | I.CALL{opnd, defs, uses, return, cutsTo, mem} => 
         I.CALL{opnd=opnd, defs=defs, return=return, cutsTo=cutsTo,
                uses=C.CellSet.map {from=fs, to=ft} uses, mem=mem}
     | I.FBINARY{binOp, src, dst} => 
	 I.FBINARY{binOp=binOp, src=foperand src, dst=foperand dst}
     | I.FUCOM opnd => I.FUCOM(foperand opnd)
     | I.FUCOMP opnd => I.FUCOMP(foperand opnd)

       (* Pseudo floating point instructions *)
     | I.FMOVE{fsize,dst,src} =>
        I.FMOVE{fsize=fsize,dst=dst,src=foperand src}
     | I.FBINOP{fsize,binOp,lsrc,rsrc,dst} =>
        I.FBINOP{fsize=fsize,binOp=binOp,
                 lsrc=foperand lsrc,rsrc=foperand rsrc,dst=dst}
     | I.FIBINOP{isize,binOp,lsrc,rsrc,dst} =>
        I.FIBINOP{isize=isize,binOp=binOp,
                  lsrc=foperand lsrc,rsrc=foperand rsrc,dst=dst}
     | I.FUNOP{fsize,unOp,src,dst} =>
        I.FUNOP{fsize=fsize,unOp=unOp,src=foperand src,dst=dst}
     | I.FCMP{fsize,lsrc,rsrc} =>
        I.FCMP{fsize=fsize,lsrc=foperand lsrc,rsrc=foperand rsrc}

     | I.ANNOTATION{i,a}=> 
         I.ANNOTATION{i=frewriteUse(i,fs,ft),
                        a=case a of
                           C.DEF_USE{cellkind=C.FP,defs,uses} =>
                             C.DEF_USE{cellkind=C.FP,uses=map replace uses,
                                       defs=defs}
                          | _ => a}
     | _ => instr
  end

  fun frewriteDef(instr, fs, ft) = let
    fun foperand(opnd as I.FDirect r) = 
         if C.sameColor(r,fs) then I.FDirect ft else opnd
      | foperand(opnd as I.FPR r) = 
         if C.sameColor(r,fs) then I.FPR ft else opnd
      | foperand opnd = opnd
    fun replace f = if C.sameColor(f,fs) then ft else f
  in
    case instr
    of I.FCOPY{dst, src, tmp, ...} => I.FCOPY{dst=map replace dst, src=src, tmp=tmp}
     | I.FSTPT opnd => I.FSTPT(foperand opnd)
     | I.FSTPL opnd => I.FSTPL(foperand opnd)
     | I.FSTPS opnd => I.FSTPS(foperand opnd)
     | I.FSTL opnd => I.FSTL(foperand opnd)
     | I.FSTS opnd => I.FSTS(foperand opnd)
     | I.CALL{opnd, defs, uses, return, cutsTo, mem} => 
         I.CALL{opnd=opnd, defs=C.CellSet.map {from=fs, to=ft} defs, 
                           return=C.CellSet.map {from=fs, to=ft} return,
                uses=uses, cutsTo=cutsTo, mem=mem}
     | I.FBINARY{binOp, src, dst} => I.FBINARY{binOp=binOp, src=src, dst=foperand dst}

       (* Pseudo floating point instructions *)
     | I.FMOVE{fsize,src,dst} => 
        I.FMOVE{fsize=fsize,src=src,dst=foperand dst}
     | I.FILOAD{isize,ea,dst} => 
        I.FILOAD{isize=isize,ea=ea,dst=foperand dst}
     | I.FBINOP{fsize,binOp,lsrc,rsrc,dst} =>
        I.FBINOP{fsize=fsize,binOp=binOp,lsrc=lsrc,rsrc=rsrc,dst=foperand dst}
     | I.FIBINOP{isize,binOp,lsrc,rsrc,dst} =>
        I.FIBINOP{isize=isize,binOp=binOp,lsrc=lsrc,rsrc=rsrc,dst=foperand dst}
     | I.FUNOP{fsize,unOp,src,dst} =>
        I.FUNOP{fsize=fsize,unOp=unOp,src=src,dst=foperand dst}

     | I.ANNOTATION{i,a}=> 
         I.ANNOTATION{i=frewriteDef(i,fs,ft),
                        a=case a of
                           C.DEF_USE{cellkind=C.FP,defs,uses} =>
                             C.DEF_USE{cellkind=C.FP,uses=uses,
                                       defs=map replace defs}
                          | _ => a}
     | _  => instr
  end
end

