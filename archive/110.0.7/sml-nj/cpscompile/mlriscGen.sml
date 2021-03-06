(* mlriscGen.sml --- translate CPS to MLRISC.
 *
 * COPYRIGHT (c) 1996 AT&T Bell Laboratories.
 *
 *)

functor MLRiscGen
  (structure MachineSpec: MACH_SPEC
   structure C          : CPSREGS where T.Region = CPSRegions
   structure Cells	: CELLS
   structure ConstType  : CONST_TYPE
   structure PseudoOp   : SMLNJ_PSEUDO_OP_TYPE
   structure MLTreeComp : MLTREECOMP 
     where type T.Constant.const = ConstType.const
     sharing MLTreeComp.T = C.T
     sharing PseudoOp = MLTreeComp.T.PseudoOp) : CPSGEN =
struct
  structure M : MLTREE = C.T
  structure Tags = System.Tags
  structure P = CPS.P
  structure LE = LabelExp
  structure R = CPSRegions
  structure CG = Control.CG

  structure MachSpec = MachineSpec

  structure CallGc = 
    CallGc(structure MLTreeComp=MLTreeComp
	   structure Cells=Cells
	   structure MS=MachineSpec
	   structure C=C
	   structure ConstType=ConstType)

  structure ArgP = 
    ArgPassing(structure Cells=Cells
	       structure C=C
	       structure MS=MachineSpec)

  structure Frag = Frag(M)

  structure MemDisambiguate = MemDisambiguate(structure Cells=Cells)

  structure MkRecord = 
    MkRecord(structure C=C
	     structure MLTreeComp=MLTreeComp)

  fun error msg = ErrorMsg.impossible ("MLRiscGen." ^ msg)

  val emit = MLTreeComp.mlriscComp
  val comp = MLTreeComp.mltreeComp

  val newReg = Cells.newReg
  val newFreg = Cells.newFreg

  val M.REG allocptrR = C.allocptr

  val dedicated = 
    map (M.GPR o M.REG) C.dedicatedR @ map (M.FPR o M.FREG) C.dedicatedF

  fun codegen(funcs : CPS.function list, limits:CPS.lvar -> (int*int), err) = let
    val maxAlloc  = #1 o limits
    val instructionCount = #2 o limits 

    (* labelTbl: mapping of function names (CPS.lvars) to labels *)
    exception LabelBind and TypTbl
    val labelTbl : Label.label Intmap.intmap = Intmap.new(32, LabelBind)
    val functionLabel = Intmap.map labelTbl
    val addLabelTbl = Intmap.add labelTbl

    val typTbl  : CPS.cty Intmap.intmap = Intmap.new(32, TypTbl)
    val addTypBinding = Intmap.add typTbl
    val typmap = Intmap.map typTbl

    fun mkGlobalTables(fk, f, _, _, _) = 
      (addLabelTbl (f, Label.newLabel(Int.toString f));
       case fk 
	of CPS.CONT => addTypBinding(f, CPS.CNTt)
         | _ => addTypBinding(f, CPS.BOGt)
       (*esac*))

    exception Strings and Reals
    val stringTable : Label.label IntStrMap.intstrmap = IntStrMap.new (32,Strings)
    val realTable : Label.label IntStrMap.intstrmap = IntStrMap.new (32,Reals)

    local
      fun find table frag s =
	(IntStrMap.map table (StrgHash.hashString s,s))
	  handle _ => let
	      val lab = Label.newLabel""
	    in
	      Frag.add (lab, frag s);
	      IntStrMap.add table (StrgHash.hashString s,s,lab);
	      lab
	    end
    in
      val findString = find stringTable Frag.STRINGfrag
      val findReal = find realTable Frag.REALfrag
    end

    fun genCluster(cluster) = let
      val _ = if !Control.debugging then app PPCps.printcps0 cluster else () 

      val sizeOfCluster = length cluster

      (* per-cluster tables *)
      exception RegMap and GenTbl 
      (* genTbl -- is used to retrieve the parameter passing 
       * conventions once a function has been compiled.
       *)
      val genTbl : Frag.frag Intmap.intmap = Intmap.new(sizeOfCluster, GenTbl)

      (* {fp,gp}RegTbl -- mapping of lvars to registers  *)
      val fpRegTbl : int Intmap.intmap = Intmap.new(2, RegMap)
      val gpRegTbl : int Intmap.intmap = Intmap.new(32, RegMap)
      fun clearTables() =(Intmap.clear fpRegTbl; Intmap.clear gpRegTbl)
      val addRegBinding = Intmap.add gpRegTbl
      val addFregBinding = Intmap.add fpRegTbl

      (* memDisambiguation uses the new register counters, 
       * so this must be reset here.
       *)
      val regmap = Cells.resetRegs()

      val memDisambig = 
	if !CG.memDisambiguate then MemDisambiguate.build(cluster) 
	else (fn _ => R.RO_MEM)

      fun getRegion(CPS.VAR v, i) =	
	   (case memDisambig v
	    of R.RECORD vl => #1 (List.nth(vl, i+1))
	     | R.OFFSET(j, vl) => #1 (List.nth(vl, i+j+1))
	     | r => r
	    (*esac*))
	| getRegion _ = R.RO_MEM

      (* pre-align allocptr *)
      val align = Alignment.build cluster
      fun alignAllocptr f = 
	if align f then emit(M.MV(allocptrR, M.ORB(C.allocptr, M.LI 4)))
	else ()

      fun grabty(CPS.VAR v) = typmap v
	| grabty(CPS.LABEL v) = typmap v
	| grabty(CPS.REAL _) = CPS.FLTt
	| grabty(CPS.INT _) = CPS.INTt
	| grabty(CPS.INT32 _) = CPS.INT32t
	| grabty(CPS.VOID) = CPS.FLTt
	| grabty _ = CPS.BOGt

      (* The baseptr contains the start address of the entire compilation unit *)
      fun laddr(lab, k) =
	M.ADD(C.baseptr,
	      M.LABEL(LE.PLUS(LE.LABEL lab, 
			     LE.CONST(k-MachineSpec.constBaseRegOffset))))

      (* a CPS register may be implemented as a physical 
       * register or a memory location.
       *)
      fun assign(M.REG r, v) = M.MV(r, v)
	| assign(r as M.LOAD32(ea, region), v) = M.STORE32(ea, v, region)
	| assign _ = error "assign"

      fun regbind(CPS.VAR v) = 
            ((M.REG(Intmap.map gpRegTbl v)) handle e => 
               (print ("\n* can't find a register for lvar " ^ (Int.toString v) ^ "\n");
                raise e))
	| regbind(CPS.INT i) = M.LI (i+i+1)
	| regbind(CPS.INT32 w) = M.LI32 w
	| regbind(CPS.LABEL v) = laddr(functionLabel v, 0)
	| regbind(CPS.REAL f) = laddr(findReal f, 0)
	| regbind(CPS.STRING s) = laddr(findString s, 0)
	| regbind _ = error "regbind"

      fun fregbind(CPS.VAR v) = 
             ((M.FREG(Intmap.map fpRegTbl v)) handle e =>
               (print ("\n* can't find a fpregister for lvar " ^ (Int.toString v) ^ "\n");
                raise e))
	| fregbind(v as CPS.REAL _) = M.LOADD(regbind v, R.REAL)
	| fregbind _ = error "fregbind"

      (* Add type bindings for each definition. This is used to determine
       * the parameter passing convention for standard functions.
       *)
      fun initTypBindings e = let
	val add = addTypBinding
      in
	case e
	of CPS.RECORD(_,_,v,e) => (add(v,CPS.BOGt); initTypBindings e)
	 | CPS.SELECT(_,_,v,t,e) => (add(v,t); initTypBindings e)
	 | CPS.OFFSET(_,_,v,e) => (add(v,CPS.BOGt); initTypBindings e)
	 | CPS.SWITCH(_,_,el) => app initTypBindings el
	 | CPS.SETTER(_,_,e) => initTypBindings e
	 | CPS.LOOKER(_,_,v,t,e) => (add(v,t); initTypBindings e)
	 | CPS.ARITH(_,_,v,t,e) => (add(v,t); initTypBindings e)
	 | CPS.PURE(_,_,v,t,e) => (add(v,t); initTypBindings e)
	 | CPS.BRANCH(_,_,_,e1,e2) => (initTypBindings e1; initTypBindings e2)
	 | CPS.APP _ => ()
	 | _ => error "initTypBindings"
      end

      (*   One entry to a function, the parameters will be in formal
       * parameter passing registers. Within the body of the function, they
       * are moved immediately to fresh temporary registers. This ensures
       * that the life time of the formal paramters is restricted to the 
       * function body and is critical in avoiding artificial register
       * interferences.
       *)
      fun initialRegBindings(vl, rl, tl) = let
	fun eCopy(x::xs, M.GPR(M.REG r)::rl, rds, rss, xs', rl') = let
	      val t = newReg()
	    in addRegBinding(x, t); eCopy(xs, rl, t::rds, r::rss, xs', rl')
	    end
	  | eCopy(x::xs, r::rl, rds, rss, xs', rl') = 
	      eCopy(xs, rl, rds, rss, x::xs', r::rl')
	  | eCopy([], [], [], [], xs', rl') = (xs', rl')
	  | eCopy([], [], rds, rss, xs', rl') = 
	     (emit(M.COPY(rds, rss)); (xs', rl'))

	fun eOther(x::xs, M.GPR(r)::rl, xs', rl') = let
	      val t = newReg()
	    in addRegBinding(x, t); emit(M.MV(t, r)); eOther(xs, rl, xs', rl')
            end
	  | eOther(x::xs, (M.FPR(M.FREG f))::rl, xs', rl') = 
	      eOther(xs, rl, x::xs', f::rl')
	  | eOther([], [], xs, rl) = (xs, rl)

	fun eFcopy([], []) = ()
	  | eFcopy(xs, rl) = let
	      val fs = map (fn _ => newFreg()) xs
	    in
	      ListPair.app addFregBinding (xs, fs);
	      emit(M.FCOPY(fs, rl))
	    end
	val (vl', rl') = eCopy(vl, rl, [], [], [], [])
      in
	eFcopy(eOther(vl', rl', [], []));
	ListPair.app addTypBinding (vl, tl)
      end

      fun updtHeapPtr(hp) = let
	fun advBy hp = emit(M.MV(allocptrR, M.ADD(C.allocptr, M.LI hp)))
      in
	(* Keep allocation pointer aligned on odd boundary *)
	(* Note: We have accounted for the extra space this eats up in 
	 *    limit.sml
	 *)
	if hp = 0 then () 
        else if Word.andb(Word.fromInt hp, 0w4) <> 0w0 then advBy(hp+4)
	else advBy(hp)
      end

      fun testLimit hp = let
        fun assignCC(M.CC cc, v) = M.CCMV(cc, v)
	  | assignCC(M.LOADCC(ea,region), v) = M.STORECC(ea, v, region)
	  | assignCC _ = error "testLimit.assign"
      in
	updtHeapPtr(hp);
	assignCC(C.exhausted, M.CMP(M.GTU, C.allocptr, C.limitptr, M.LR))
      end

      (* Int 31 tag optimization *)
      fun addTag e = M.ADD(e, M.LI 1)
      fun stripTag e = M.SUB(e, M.LI 1, M.LR)
      fun orTag e = M.ORB(e, M.LI 1)
      fun tag(signed, e) = let		(* true if signed *)
	fun double r = if signed then M.ADDT(r,r) else M.ADD(r,r)
      in
	case e 
	 of M.REG _ => addTag(double e) 
          | _ => let
	       val tmp = newReg()
	     in M.SEQ(M.MV(tmp, e), addTag(double (M.REG tmp)))
	     end
      end
      fun untag(_, CPS.INT i) = M.LI(i)
	| untag(true, v) = M.SRA(regbind v, M.LI 1, M.LR)
	| untag(false, v) = M.SRL(regbind v, M.LI 1, M.LR)

      fun int31add(addOp, [CPS.INT k, w]) = addOp(M.LI(k+k), regbind w)
	| int31add(addOp, [w, v as CPS.INT _]) = int31add(addOp, [v,w])
	| int31add(addOp, [v,w]) = addOp(regbind v, stripTag(regbind w))

      fun int31sub(subOp, [CPS.INT k,w]) = subOp(M.LI (k+k+2), regbind w, M.LR)
	| int31sub(subOp, [v, CPS.INT k]) = subOp(regbind v, M.LI(k+k), M.LR)
	| int31sub(subOp, [v,w]) = addTag(subOp(regbind v, regbind w, M.LR))

      fun int31xor([CPS.INT k, w]) = M.XORB(M.LI(k+k), regbind w)
	| int31xor([w,v as CPS.INT _]) = int31xor [v,w]
	| int31xor([v,w]) = addTag (M.XORB(regbind v, regbind w))

      fun int31mul(signed, args) = let
        val mulOp = if signed then M.MULT else M.MULU
	fun f [CPS.INT k, CPS.INT j] = addTag(mulOp(M.LI (k+k), M.LI j))
	  | f [CPS.INT k, w] = addTag(mulOp(untag(signed, w), M.LI(k+k)))
	  | f [v, w as CPS.INT _] = f ([w, v])
	  | f [v, w] = addTag(mulOp(stripTag(regbind v), untag(signed, w)))
      in f args
      end

      fun int31div(signed, args) = let
	val divOp = if signed then M.DIVT else M.DIVU
	fun f [CPS.INT k, CPS.INT j] = divOp(M.LI k, M.LI j, M.LR)
	  | f [CPS.INT k, w] = divOp(M.LI k, untag(signed, w), M.LR)
	  | f [v, CPS.INT k] = divOp(untag(signed, v), M.LI k, M.LR)
	  | f [v, w] = divOp(untag(signed, v), untag(signed, w), M.LR)
      in tag(signed, f args)
      end

      fun int31lshift [CPS.INT k, w] =
	    addTag (M.SLL(M.LI(k+k), untag(false, w), M.LR))
	| int31lshift [v, CPS.INT k] = 
	    addTag(M.SLL(stripTag(regbind v), M.LI k, M.LR))
	| int31lshift [v,w] = 
	    addTag(M.SLL(stripTag(regbind v), untag(false, w), M.LR))

      fun int31rshift(rshiftOp, [v, CPS.INT k]) =  
	    orTag(rshiftOp(regbind v, M.LI k, M.LR))
	| int31rshift(rshiftOp, [v,w]) =
	    orTag(rshiftOp(regbind v, untag(false, w), M.LR))

      fun getObjDescriptor(v) = 
	M.LOAD32(M.SUB(regbind v, M.LI 4, M.LR), getRegion(v, ~1))

      fun getObjLength(v) = 
	M.SRA(getObjDescriptor(v), M.LI(Tags.width_tags -1), M.LR)

      (* Note: because formals are moved into fresh temporaries,
       * (formals intersection actuals) is empty. 
       *)
      fun callSetup(formals, actuals) = let
	fun gather([], [], cpRd, cpRs, fcopies, moves) = 
	     (case (cpRd,cpRs) of ([],[]) => () | _ => emit(M.COPY(cpRd, cpRs));
	      case fcopies
                of [] => () 
	         | _ => emit(M.FCOPY(map #1 fcopies, map #2 fcopies));
	      app emit moves)
	  | gather(M.GPR(M.REG rd)::fmls, act::acts, cpRd, cpRs, f, m) = 
	     (case regbind act
	       of M.REG rs => gather(fmls, acts, rd::cpRd, rs::cpRs, f, m)
   	        | e => gather(fmls, acts, cpRd, cpRs, f, M.MV(rd, e)::m)
	     (*esac*))
	  | gather(M.GPR(M.LOAD32(ea,r))::fmls, act::acts, cpRd, cpRs, f, m) =
	     gather(fmls, acts, cpRd, cpRs, f, M.STORE32(ea, regbind act, r)::m)
	  | gather(M.FPR(M.FREG fd)::fmls, act::acts, cpRd, cpRs, f, m) = 
	     (case fregbind act
	       of M.FREG fs => gather(fmls, acts, cpRd, cpRs, (fd, fs)::f, m)
	        | e => gather(fmls, acts, cpRd, cpRs, f, M.FMV(fd, e)::m)
	     (*esac*))
	  | gather _ = error "callSetup.gather"
      in
	gather(formals, actuals, [], [], [], [])
      end

      (* scale-and-add *)
      fun scale1(a, CPS.INT 0) = a
	| scale1(a, CPS.INT k) = M.ADD(a, M.LI k)
	| scale1(a, i) = M.ADD(a, untag(true, i))

      fun scale4(a, CPS.INT 0) = a
	| scale4(a, CPS.INT i) = M.ADD(a, M.LI(i*4))
	| scale4(a, i) = M.ADD(a, M.SLL(stripTag(regbind i), M.LI 1, M.LR))

      fun scale8(a, CPS.INT 0) = a
	| scale8(a, CPS.INT i) = M.ADD(a, M.LI(i*8))
	| scale8(a, i) = M.ADD(a, M.SLL(stripTag(regbind i), M.LI 2, M.LR))

      (* add to storelist, the address where a boxed update has occured *)
      fun recordStore(tmp, hp) =
	(emit(M.STORE32(M.ADD(C.allocptr, M.LI hp), tmp, R.STORELIST));
	 emit(M.STORE32(M.ADD(C.allocptr, M.LI(hp+4)), C.storeptr, R.STORELIST));
	 emit(assign(C.storeptr, M.ADD(C.allocptr, M.LI hp))))
	   
      fun unsignedCmp oper = case oper
	of P.>   => M.GTU | P.>=  => M.GEU | P.<   => M.LTU | P.<=  => M.LEU
 	 | P.eql => M.EQ  | P.neq => M.NEQ

      fun signedCmp oper = case oper
	of P.> => M.GT    | P.>= => M.GE   | P.< => M.LT    | P.<= => M.LE
 	 | P.neq => M.NEQ | P.eql => M.EQ 

      fun branchToLabel(lab) = M.JMP(M.LABEL(LE.LABEL(lab)), [lab])

      local
	open CPS
      in

      fun alloc(x, e, rest, hp) = allocR(newReg(), x, e, rest, hp)
      
      and allocR(r, x, e, rest, hp) = 
       (addRegBinding(x, r);
	emit(M.MV(r, e));  
	gen(rest, hp))

      and falloc(x, e, rest, hp) = fallocF(newFreg(), x, e, rest, hp)
      
      and fallocF(f, x, e, rest, hp) =
        (addFregBinding(x, f); 
	 emit(M.FMV(f, e)); 
	 gen(rest, hp))

      and nop(x, v, e, hp) = alloc(x, regbind v, e, hp)

      and copy(x, v, rest, hp) = let
	val dst = newReg()
      in
	addRegBinding(x, dst);
	case regbind v
	 of M.REG src => emit(M.COPY([dst], [src]))
          | e => emit(M.MV(dst, e))
	(*esac*);
        gen(rest, hp)
      end

      and branch (cmp, [v,w], d, e, hp) = let
	val trueLab = Label.newLabel""
      in
	(* is single assignment great or what! *)
	emit(M.BCC(cmp, M.CMP(cmp, regbind v, regbind w, M.LR), trueLab));
	gen(e, hp);
	genlab(trueLab, d, hp)
      end

      and arith(oper, v, w, x, e, hp) = 
	alloc(x, oper(regbind v, regbind w), e, hp)

      and orderedArith(oper, v, w, x, order, e, hp) = 
	alloc(x, oper(regbind v, regbind w, order), e, hp)

      and logical(oper, v, w, x, e, hp) = 
	alloc(x, oper(regbind v, untag(false, w), M.LR), e, hp)

      and genlab(lab, e, hp) = (comp (M.DEFINELABEL lab); gen(e, hp))

      and gen(RECORD((CPS.RK_SPILL | CPS.RK_CONT), vl, w, e), hp) =
	    gen(RECORD(CPS.RK_RECORD, vl, w, e), hp)
	| gen(RECORD(CPS.RK_FCONT, vl, w, e), hp) =
	    gen(RECORD(CPS.RK_FBLOCK, vl, w, e), hp)
	| gen(RECORD(CPS.RK_FBLOCK, vl, w, e), hp) = let
	    val len = List.length vl
	    val desc = 
	      if len=1 then Tags.desc_reald 
	      else Tags.make_desc(len, Tags.tag_realdarray)
	    val vl' = 
	      map (fn (x as CPS.REAL _, _) => 
		        (M.GPR(regbind x), SELp(0, OFFp 0))
	            | (x, p as SELp _) => (M.GPR(regbind x), p)
		    | (x, p as OFFp 0) => (M.FPR(fregbind x), p)
		    | _ => error "gen:RECORD:RK_FBLOCK")
	          vl
	    val ptr = newReg()
	    (* At initialization the allocation pointer is aligned on
	     * an odd-word boundary, and the heap offset set to zero. If an
	     * odd number of words have been allocated then the heap pointer
	     * is misaligned for this record creation.
	     *)
	    val hp = 
	      if Word.andb(Word.fromInt hp, 0w4) <> 0w0 then hp+4 else hp
          in		  
	    addRegBinding(w, ptr);
	    MkRecord.frecord
	      {desc=M.LI desc, fields=vl', ans=ptr, mem=memDisambig w, hp=hp};
	    gen(e, hp + 4 + len*8)
	  end
	| gen(RECORD(kind, vl, w, e), hp) = let
	    val len = length vl
	    val desc = case (kind, len)
	      of (CPS.RK_I32BLOCK, l) => Tags.make_desc (l*4, Tags.tag_string)
	       | (CPS.RK_VECTOR, l) => Tags.make_desc (l, Tags.tag_record)
	       | (_, 2) => Tags.desc_pair
	       | (_, l) => Tags.make_desc (l, Tags.tag_record)
              (*esac*)
	    val vl' = map (fn (v,p) => (regbind v, p)) vl
	    (* pad strings *)
	    val contents = case kind 
	      of CPS.RK_I32BLOCK => vl' @ [(M.LI 0, OFFp 0)]
	       | _ => vl'
	      (*esac*)
	    val ptr = newReg()
	  in
	    addRegBinding(w, ptr);
	    MkRecord.record 
	      {desc=M.LI desc, fields=contents, ans=ptr, mem=memDisambig w, hp=hp};
	    gen(e, hp + 4 + len*4 )
          end

	(*** SELECT ***)
	| gen(SELECT(i,INT k,x,t,e), hp) =
           let val unboxedfloat = MachSpec.unboxedFloats
               fun isFlt t = 
                 if unboxedfloat then (case t of FLTt => true | _ => false)
                 else false
               fun fallocSp(x,e,hp) =
                 (addFregBinding(x,newFreg());gen(e, hp))
              (* warning: the following generated code should never be 
                 executed; its semantics is completely screwed up !
               *)
            in if isFlt t then fallocSp(x, e, hp)
	       else alloc(x, M.LI k, e, hp)(* BOGUS *)
           end
	| gen(SELECT(i,v,x,FLTt,e), hp) = let
	    val a as M.REG ar = regbind v
	    val f = newFreg()
	  in fallocF(f, x, M.LOADD(scale8(a, INT i), R.REAL), e, hp)
	  end
	| gen(SELECT(i,v,x,_,e), hp) = let
	    val a = regbind v
	    val r = newReg()
	    val region = getRegion(v, i)
          in allocR(r, x, M.LOAD32(scale4(a, INT i), region), e, hp)
          end
	| gen(OFFSET(i,v,x,e), hp) = alloc(x, scale4(regbind v, INT i), e, hp)

	(*** APP ***)
	| gen(APP(INT k, args), hp) = updtHeapPtr(hp)
	| gen(APP(func as VAR f, args), hp) = let
	    val formals as (M.GPR dest::_) =  
	          ArgP.standard(typmap f, map grabty args)
	  in
	    callSetup(formals, args);
	    emit(testLimit hp);
	    emit(M.JMP(dest, []));
	    comp(M.ESCAPEBLOCK(formals @ (M.CCR C.exhausted :: dedicated)))
	  end
	| gen(APP(func as LABEL f, args), hp) = 
	  (case Intmap.map genTbl f
	    of Frag.KNOWNFUN(ref(Frag.GEN formals)) => 
	        (updtHeapPtr(hp);
		 callSetup(formals, args); 
		 emit(branchToLabel(functionLabel f)))
	     | Frag.KNOWNFUN(r as ref(Frag.UNGEN(f,vl,tl,e))) => let
		 val formals = ArgP.known tl
		 val lab = functionLabel f
	       in
		 r := Frag.GEN formals;
		 updtHeapPtr(hp);
		 callSetup(formals, args);
		 comp(M.DEFINELABEL lab);
		 alignAllocptr f;
		 initialRegBindings(vl, formals, tl);
		 initTypBindings e;
		 gen(e, 0)
	       end
	     | Frag.KNOWNCHK(r as ref(Frag.UNGEN(f,vl,tl,e))) => let
	         val formals = 
		   if MachSpec.fixedArgPassing then ArgP.fixed tl
		   else ArgP.known tl
		 val lab = functionLabel f
	       in
		 r:=Frag.GEN formals;
		 callSetup(formals, args);
		 emit(testLimit hp);
		 emit(branchToLabel(lab));
		 comp(M.ORDERED[M.PSEUDO_OP(PseudoOp.MARK),
				M.DEFINELABEL lab]);
		 CallGc.knwCheckLimit 
		   {maxAlloc=4*maxAlloc f, regfmls=formals, regtys=tl, 
		    return=branchToLabel(lab)};
	         alignAllocptr f;
		 initialRegBindings(vl, formals, tl);
		 initTypBindings e;
		 gen(e, 0)
	       end
	     | Frag.KNOWNCHK(ref(Frag.GEN formals)) => 
	         (callSetup(formals, args); 
		  emit(testLimit hp);
		  emit(branchToLabel(functionLabel f)))
	     | Frag.STANDARD{fmlTyps, ...} => let
	         val formals = ArgP.standard(typmap f, fmlTyps)
	       in
		 callSetup(formals, args);
		 emit(testLimit hp);
		 emit(branchToLabel(functionLabel f))
	       end
	     | _ => error "APP"
	  (*esac*))

	(*** SWITCH ***)
	| gen(SWITCH(v, _, l), hp) = let
	    val lab = Label.newLabel""
	    val labs = map (fn _ => Label.newLabel"") l
	    val tmpR = newReg() val tmp = M.REG tmpR
	  in
	    emit(M.MV(tmpR, laddr(lab, 0)));
	    emit(M.JMP(M.ADD(tmp, M.LOAD32 (scale4(tmp, v), R.RO_MEM)), labs));
	    comp(M.PSEUDO_OP(PseudoOp.JUMPTABLE{base=lab, targets=labs}));
	    ListPair.app (fn (lab, e) => genlab(lab, e, hp)) (labs, l)
	  end

	(*** PURE ***)
	| gen(PURE(P.pure_arith{oper=P.orb, ...}, [v,w], x, _, e), hp) = 
	    alloc(x, M.ORB(regbind v, regbind w), e, hp)
	| gen(PURE(P.pure_arith{oper=P.andb, ...}, [v,w], x, _, e), hp) = 
	    alloc(x, M.ANDB(regbind v, regbind w), e, hp)
	| gen(PURE(P.pure_arith{oper, kind}, args as [v,w], x, ty, e), hp) = 
	  (case kind
	    of P.INT 31 => (case oper
	         of P.xorb   => alloc(x, int31xor(args), e, hp)
	          | P.lshift => alloc(x, int31lshift args, e, hp)
		  | P.rshift => alloc(x, int31rshift(M.SRA,args), e, hp)
		  | _ => error "gen:PURE INT 31"
	        (*esac*))	
	     | P.INT 32  => (case oper
	         of P.xorb  => arith(M.XORB, v, w, x, e, hp)
	          | P.lshift => logical(M.SLL, v, w, x, e, hp)
		  | P.rshift => logical(M.SRA, v, w, x, e, hp)
		  | _ => error "gen:PURE INT 32"
	        (*esac*))
	     | P.UINT 31 => (case oper
		 of P.+    => alloc(x, int31add(M.ADD, args), e, hp)
	          | P.-    => alloc(x, int31sub(M.SUB, args), e, hp)
		  | P.*    => alloc(x, int31mul(false, args), e, hp)
		  | P./    => (* This is not really a pure 
			         operation -- oh well *)
			       (updtHeapPtr hp;
				alloc(x, int31div(false, args), e, 0))
	          | P.xorb => alloc(x, int31xor(args), e, hp)
	          | P.lshift  => alloc(x, int31lshift args, e, hp)
		  | P.rshift  => alloc(x, int31rshift(M.SRA,args), e, hp)
		  | P.rshiftl => alloc(x, int31rshift(M.SRL,args), e, hp)
		  | _ => error "gen:PURE UINT 31"
	        (*esac*))
	     | P.UINT 32 => (case oper
		 of P.+     => arith(M.ADD, v, w, x, e, hp)
 	          | P.-     => orderedArith(M.SUB, v, w, x, M.LR, e, hp)
		  | P.*     => arith(M.MULU, v, w, x, e, hp)
		  | P./     => (updtHeapPtr hp; 
				orderedArith(M.DIVU, v, w, x, M.LR, e, 0))
	          | P.xorb  => arith(M.XORB, v, w, x, e, hp)
	          | P.lshift => logical(M.SLL, v, w, x, e, hp)
		  | P.rshift => logical(M.SRA, v, w, x, e, hp)
		  | P.rshiftl=> logical(M.SRL, v, w, x, e, hp)
		  | _ => error "gen:PURE UINT 32"
	        (*esac*))
	  (*esac*))
	| gen(PURE(P.pure_arith{oper=P.notb, kind}, [v], x, _, e), hp) =
	  (case kind 
	    of P.UINT 32 => alloc(x, M.XORB(regbind v, M.LI32 0wxFFFFFFFF), e, hp)
   	     | P.INT 32 => alloc(x, M.XORB(regbind v, M.LI32 0wxFFFFFFFF), e, hp)
	     | P.UINT 31 => alloc(x, M.SUB(M.LI 0, regbind v, M.LR), e, hp)
	     | P.INT 31 => alloc(x, M.SUB(M.LI 0, regbind v, M.LR), e, hp)
	  (*esac*))
	| gen(PURE(P.copy ft, [v], x, _, e), hp) =
	   (case ft
	    of (31, 32) => alloc(x, M.SRL(regbind v, M.LI 1, M.LR), e, hp)
	     | (8, 31) => copy(x, v, e, hp)
	     | (8, 32) => alloc(x, M.SRL(regbind v, M.LI 1, M.LR), e, hp)
	     | (n,m) => if n = m then copy(x, v, e, hp) else error "gen:PURE:copy"
           (*esac*))
	| gen(PURE(P.extend ft, [v], x, _ ,e), hp) = 
	  (case ft
	   of (8,31) => 
	        alloc(x, M.SRA(M.SLL(regbind v,M.LI 23,M.LR), M.LI 23, M.LR), 
		      e, hp)
	    | (8,32) =>
		alloc(x, M.SRA(M.SLL(regbind v, M.LI 23, M.LR), M.LI 24, M.LR), 
		      e, hp)
	    | (31,32) => alloc(x, M.SRA(regbind v, M.LI 1, M.LR), e, hp)
            | (n, m) => 
		if n = m then copy(x, v, e, hp) else error "gen:PURE:extend"
            (*esac*))
	| gen(PURE(P.trunc ft, [v], x, _, e), hp) = 
	  (case ft
	   of (32, 31) => 
	        alloc(x, M.ORB(M.SLL(regbind v, M.LI 1, M.LR), M.LI 1), e, hp)
	    | (31, 8) => alloc(x, M.ANDB(regbind v, M.LI 0x1ff), e, hp)
	    | (32, 8) => alloc(x, tag(false, M.ANDB(regbind v, M.LI 0xff)), e, hp)
	    | (n, m) => if n = m then copy(x, v, e, hp) else error "gen:PURE:trunc"
	   (*esac*))
	| gen(PURE(P.real{fromkind=P.INT 31, tokind}, [v], x, _, e), hp) = 
	  (case tokind
	    of P.FLOAT 64 => (case v
		 of INT n => falloc(x, M.CVTI2D(M.LI n), e, hp)
	          | _ => falloc(x, M.CVTI2D(untag(true, v)), e, hp)
	        (*esac*))
	     | _ => error "gen:PURE:P.real"
          (*esac*))
	| gen(PURE(P.length, [v], x, _, e), hp) = alloc(x, getObjLength v, e, hp)
	| gen(PURE(P.objlength, [v], x, _, e), hp) = 
	    alloc(x, orTag(getObjLength(v)), e, hp)
	| gen(PURE(P.pure_arith{oper, kind=P.FLOAT 64}, [v], x, _, e), hp) = let
	    val r = fregbind v
	  in
	    case oper
	     of P.~ => falloc(x, M.FNEGD(r), e, hp)
	      | P.abs => falloc(x, M.FABSD(r), e, hp)
          end
	| gen(PURE(P.subscriptv, [v, INT w], x, t, e), hp) = 
	    gen(SELECT(w, v, x, t, e), hp)
	| gen(PURE(P.subscriptv, [v, w], x, _, e), hp) =
	    alloc(x, M.LOAD32(scale4(regbind v, w), R.RO_MEM), e, hp)
	| gen(PURE(P.pure_numsubscript{kind=P.INT 8}, [a,i], x, _, e), hp) = 
	    alloc(x, tag(false,M.LOAD8(scale1(regbind a, i), R.RW_MEM)), e, hp) 
	| gen(PURE(P.gettag, [v], x, _, e), hp) = 
	    alloc(x, 
		  tag(false, M.ANDB(getObjDescriptor(v), M.LI(Tags.power_tags-1))),
		  e, hp)
	| gen(PURE(P.mkspecial, [i, v], x, _, e), hp) = let
	    val desc = case i
	      of INT n => M.LI(Tags.make_desc(n, Tags.tag_special))
	       | _ => M.ORB(M.SLL(untag(true, i), M.LI Tags.width_tags, M.LR),
			   M.LI Tags.desc_special)
	    val ptr = newReg()
	  in
	    MkRecord.record{desc=desc, fields=[(regbind v, OFFp 0)],
			    ans=ptr, mem=memDisambig x, hp=hp};
	    addRegBinding(x, ptr);
	    gen(e, hp+8)
	  end
	| gen(PURE(P.makeref, [v], x, _, e), hp) = let
	    val ptr = newReg()
	    val tag = M.LI(Tags.make_desc(1, Tags.tag_array))
	    val mem = memDisambig x
	  in
	    emit(M.STORE32(M.ADD(C.allocptr, M.LI hp), tag, mem));
	    emit(M.STORE32(M.ADD(C.allocptr, M.LI(hp+4)), regbind v, mem));
	    emit(M.MV(ptr, M.ADD(C.allocptr, M.LI(hp+4))));
	    addRegBinding(x, ptr);
	    gen(e, hp+8)
	  end
	| gen(PURE(P.fwrap,[u],w,_,e), hp) = 
	    gen(RECORD(CPS.RK_FBLOCK,[(u,OFFp 0)],w,e), hp)
	| gen(PURE(P.funwrap,[u],w,_,e), hp) = gen(SELECT(0,u,w,FLTt,e), hp)
	| gen(PURE(P.iwrap,[u],w,_,e), _) = error "iwrap not implemented"
	| gen(PURE(P.iunwrap,[u],w,_,e), _) = error "iunwrap not implemented"
	| gen(PURE(P.i32wrap,[u],w,_,e), hp) = 
	    gen(RECORD(CPS.RK_I32BLOCK,[(u,OFFp 0)],w,e), hp)
	| gen(PURE(P.i32unwrap,[u],w,_,e), hp) = gen(SELECT(0,u,w,INT32t,e), hp)
	| gen(PURE(P.wrap,[u],w,_,e), hp) = copy(w, u, e, hp)
	| gen(PURE(P.unwrap,[u],w,_,e), hp) = copy(w, u, e, hp)
	| gen(PURE(P.cast,[u],w,_,e), hp) = copy(w, u, e, hp)
	| gen(PURE(P.getcon,[u],w,t,e), hp) = gen(SELECT(0,u,w,t,e), hp)
	| gen(PURE(P.getexn,[u],w,t,e), hp) = gen(SELECT(0,u,w,t,e), hp)
	(*** ARITH ***)
	| gen(ARITH(P.arith{kind=P.INT 31, oper}, args, x, _, e), hp) = 
	  (updtHeapPtr hp;
	   case oper
	    of P.+ => alloc(x, int31add(M.ADDT, args), e, 0)
	     | P.- => alloc(x, int31sub(M.SUBT, args), e, 0)
	     | P.* => alloc(x, int31mul(true, args), e, 0)
	     | P./ => alloc(x, int31div(true, args), e, 0)
	     | P.~ => alloc(x, M.SUBT(M.LI 2, regbind(hd args), M.LR), e, 0)
	     | _ => error "gen:ARITH INT 31"
	  (*esac*))	
	| gen(ARITH(P.arith{kind=P.INT 32, oper}, [v,w], x, _, e), hp) =
	  (updtHeapPtr hp;
	   case oper
	    of P.+     => arith(M.ADDT, v, w, x, e, 0)
	     | P.-     => orderedArith(M.SUBT, v, w, x, M.LR, e, 0)
	     | P.*     => arith(M.MULT, v, w, x, e, 0)
	     | P./     => orderedArith(M.DIVT, v, w, x, M.LR, e, 0)
	     | _ => error "P.arith{kind=INT 32, oper}, [v,w], ..."
	  (*esac*))
	| gen(ARITH(P.arith{kind=P.INT 32, oper=P.~ }, [v], x, _, e), hp) =
	    (updtHeapPtr hp;
	     alloc(x, M.SUBT(M.LI 0, regbind v, M.LR), e, 0))

	  (* Note: for testu operations we use a somewhat arcane method
	   * to generate traps on overflow conditions. A better approach
	   * would be to generate a trap-if-negative instruction available
	   * on a variety of machines, e.g. mips and sparc (maybe others).
	   *)
	| gen(ARITH(P.testu(32, 32), [v], x, _, e), hp) = let
	     val xreg = newReg()
	     val vreg = regbind v
	  in
	    updtHeapPtr hp;
	    emit(M.MV(xreg, M.ADDT(vreg, regbind(INT32 0wx80000000))));
	    allocR(xreg, x, vreg, e, 0)
          end
	| gen(ARITH(P.testu(31, 31), [v], x, _, e), hp) = let
	     val xreg = newReg()
	     val vreg = regbind v
	  in
	    updtHeapPtr hp;
	    emit(M.MV(xreg, M.ADDT(vreg, regbind(INT32 0wx80000000))));
	    allocR(xreg, x, vreg, e, 0)
          end
	| gen(ARITH(P.testu(32,31), [v], x, _, e), hp) = let
	    val vreg = regbind v
	    val tmp = newReg()
	    val tmpR = M.REG tmp
	    val lab = Label.newLabel ""
	  in
	    emit(M.MV(tmp, regbind(INT32 0wx3fffffff)));
	    emit(M.BCC(M.LEU, M.CMP(M.LEU, vreg, tmpR, M.LR), lab));
	    updtHeapPtr hp;
	    emit(M.MV(tmp, M.SLL(tmpR, M.LI 1, M.LR)));
	    emit(M.MV(tmp, M.ADDT(tmpR, tmpR)));
	    comp(M.DEFINELABEL lab);
	    alloc(x, tag(false, vreg), e, hp)
          end
	| gen(ARITH(P.test(32,31), [v], x, _, e), hp) = 
	   (updtHeapPtr hp; alloc(x, tag(true, regbind v), e, 0))
	| gen(ARITH(P.test(n, m), [v], x, _, e), hp) = 
	   if n = m then copy(x, v, e, hp) else error "gen:ARITH:test"
	| gen(ARITH(P.arith{oper, kind=P.FLOAT 64}, vl, x, _, e), hp) = let
	    fun binary(oper, [v,w]) = 
	      falloc(x, oper(fregbind v, fregbind w), e, hp)
	    fun ordBinary(oper, [v,w]) =
	      falloc(x, oper(fregbind v, fregbind w, M.LR), e, hp)
	  in
	    case oper
	     of P.+ => binary(M.FADDD, vl)
	      | P.* => binary(M.FMULD, vl)
	      | P.- => ordBinary(M.FSUBD, vl)
	      | P./ => ordBinary(M.FDIVD, vl)
	  end
	(*** LOOKER ***)
	| gen(LOOKER(P.!,[v],w,t,e), hp) = 
	    gen(LOOKER(P.subscript, [v,INT 0], w, t, e), hp)
	| gen(LOOKER(P.subscript, [v,w], x, _, e), hp) =
	    alloc(x, M.LOAD32(scale4(regbind v, w),R.RW_MEM), e, hp)
	| gen(LOOKER(P.numsubscript{kind=P.INT 8},[a,i],x,_,e), hp) = 
	    alloc(x, tag(false, M.LOAD8(scale1(regbind a, i),R.RW_MEM)), e, hp)
	| gen(LOOKER(P.gethdlr,[],x,_,e), hp) = alloc(x, C.exnptr, e, hp)
	| gen(LOOKER(P.getvar, [], x, _, e), hp) = alloc(x, C.varptr, e, hp)
	| gen(LOOKER(P.deflvar, [], x, _, e), hp) = alloc(x, M.LI 0, e, hp)
	| gen(LOOKER(P.numsubscript{kind=P.FLOAT 64}, [a, INT i], x, _, e), hp) =
	    gen(SELECT(i, a, x, FLTt, e), hp)
	| gen(LOOKER(P.numsubscript{kind=P.FLOAT 64}, [a,i], x, _, e), hp) =
	    falloc(x, M.LOADD(scale8(regbind a, i),R.RW_MEM), e, hp)
	| gen(LOOKER(P.getspecial, [v], x, _, e), hp) = 
	    alloc(x, 
		  orTag(M.SRA(getObjDescriptor(v),
			      M.LI (Tags.width_tags-1), 
			      M.LR)), 
		  e, hp)
	| gen(LOOKER(P.getpseudo, [i], x, _, e), hp) = 
	    (print "getpseudo not implemented\n"; nop(x, i, e, hp))
	(*** SETTER ***)
	| gen(SETTER(P.update, [a,i,v], e), hp) = let
	    val tmpR = newReg() 
	    val tmp = M.REG tmpR
	    val ea = scale4(regbind a, i)
	    val VAR arr = a
	  in
	    emit(M.MV(tmpR, ea));
	    recordStore(tmp, hp);
	    emit(M.STORE32(tmp, regbind v, memDisambig arr));
	    gen(e, hp+8)
	  end
	| gen(SETTER(P.boxedupdate, args, e), hp) = 
	    gen(SETTER(P.update, args, e), hp)
	| gen(SETTER(P.unboxedupdate, [a, i, v], e), hp) = 
	   (emit(M.STORE32(scale4(regbind a, i), regbind v, R.RW_MEM));
	    gen(e, hp))
	| gen(SETTER(P.numupdate{kind=P.INT 8}, [s,i,v], e), hp) = let
	   val ea = scale1(regbind s, i)
	  in
	    case v 
	     of INT k => emit(M.STORE8(ea, M.LI k, R.RW_MEM))
	      | _ => emit(M.STORE8(ea, untag(false, v), R.RW_MEM))
	    (*esac*);
	    gen(e, hp)
	  end
	| gen(SETTER(P.numupdate{kind=P.FLOAT 64},[a,i,v],e), hp) = let
	    val VAR arr = a
	  in
	    emit(M.STORED(scale8(regbind a, i), fregbind v, memDisambig arr)); 
	    gen(e, hp)
	  end
	| gen(SETTER(P.setspecial, [v, i], e), hp) = let
	    val ea = M.SUB(regbind v, M.LI 4, M.LR)
	    val i' = case i
	      of INT k => M.LI(Tags.make_desc(k, Tags.tag_special))
	       | _ => M.ORB(M.SLL(untag(true, i), M.LI Tags.width_tags, M.LR),
			    M.LI(Tags.desc_special))
	  in
	    M.STORE32(ea, i',R.RW_MEM);
	    gen(e, hp)
	  end
	| gen(SETTER(P.sethdlr,[x],e), hp) = 
	    (emit(assign(C.exnptr, regbind x));  gen(e, hp))
	| gen(SETTER(P.setvar,[x],e), hp) = 
	    (emit(assign(C.varptr, regbind x));  gen(e, hp))
	| gen(SETTER(P.uselvar,[x],e), hp) = gen(e, hp)
	| gen(SETTER(P.acclink,_,e), hp) = gen(e, hp)
	| gen(SETTER(P.setmark,_,e), hp) = gen(e, hp)
	| gen(SETTER(P.free,[x],e), hp) = gen(e, hp)
	| gen(SETTER(P.setpseudo,_,e), hp) = 
	    (print "setpseudo not implemented\n"; gen(e, hp))

	(*** BRANCH  ***)
        | gen(BRANCH(P.cmp{oper,kind=P.INT 31},[INT v, INT k],_,e,d), hp) = let
	    val itow = Word.fromInt
	  in
	    if (case oper 
		  of P.> => v>k | P.>= => v>=k | P.< => v<k | P.<= => v<=k
		   | P.eql => v=k | P.neq => v<>k
		(*esac*)) then  gen(e, hp)
	    else gen(d, hp)
	  end
        | gen(BRANCH(P.cmp{oper, kind=P.INT 31}, vw, _, e, d), hp) = 
	    branch(signedCmp oper, vw, e, d, hp)
        | gen(BRANCH(P.cmp{oper,kind=P.UINT 31},[INT v', INT k'],_,e,d), hp) = let
	    open Word
	    val v = fromInt v' 
	    val k = fromInt k'
          in
	    if (case oper
		 of P.> => v>k   | P.>= => v>=k  | P.< => v<k   | P.<= => v<=k
	          | P.eql => v=k | P.neq => v<>k
		(*esac*)) then
	      gen(e, hp)
	    else gen(d, hp)
	  end
        | gen(BRANCH(P.cmp{oper, kind=P.UINT 31}, vw, _, e, d), hp) = 
	    branch(unsignedCmp oper, vw, e, d, hp)
        | gen(BRANCH(P.cmp{oper,kind=P.UINT 32},[INT32 v,INT32 k],_,e,d), hp) = let
	    open Word32
          in
	    if (case oper
		 of P.> => v>k   | P.>= => v>=k  | P.< => v<k   | P.<= => v<=k
	          | P.eql => v=k | P.neq => v<>k
		(*esac*)) then
	      gen(e, hp)
	    else gen(d, hp)
	  end
        | gen(BRANCH(P.cmp{oper, kind=P.UINT 32}, vw, _, e, d), hp) = 
	    branch(unsignedCmp oper, vw, e, d, hp)

        | gen(BRANCH(P.cmp{oper, kind=P.INT 32}, vw, _, e, d), hp) = 
	    branch(signedCmp oper, vw, e, d, hp)
        | gen(BRANCH(P.fcmp{oper,size=64}, [v,w], _, d, e), hp) = let
	    val trueLab = Label.newLabel""
	    val fcond = case oper
	      of P.fEQ => M.==  | P.fULG => M.?<> 
	       | P.fUN => M.?   | P.fLEG => M.<=> 
	       | P.fGT => M.>   | P.fGE  => M.>=  
	       | P.fUGT => M.?> | P.fUGE => M.?>= 
	       | P.fLT => M.<   | P.fLE  => M.<=  
	       | P.fULT => M.?< | P.fULE => M.?<= 
	       | P.fLG => M.<>  | P.fUE  => M.?= 

	    val cmp = M.FCMP(fcond, fregbind v, fregbind w, M.LR) 
          in
	    emit(M.FBCC(fcond, cmp, trueLab)); 
	    gen(e, hp);
	    genlab(trueLab, d, hp)
          end
	| gen(BRANCH(P.peql, vw, _,e,d), hp) = branch(M.EQ, vw, e, d, hp)
        | gen(BRANCH(P.pneq, vw, _, e, d), hp) = branch(M.NEQ, vw, e, d, hp)
        | gen(BRANCH(P.strneq, [n,v,w],c,d,e), hp) = 
	    gen(BRANCH(P.streq, [n,v,w],c,e,d), hp)
	| gen(BRANCH(P.streq, [INT n,v,w],_,d,e), hp) = let
	    val n' = ((n+3) div 4) * 4
	    val false_lab = Label.newLabel ""
	    val r1 = newReg()
	    val r2 = newReg()
	    fun cmpWord(i) = 
	      M.CMP(M.NEQ, M.LOAD32(M.ADD(M.REG r1,i),R.RO_MEM), 
		           M.LOAD32(M.ADD(M.REG r2,i),R.RO_MEM), M.LR)
	    fun whileLoop () = let
	      val iR = newReg()
	      val i = M.REG iR
	      val loopHead = Label.newLabel ""
	    in
	      emit(M.MV(iR, M.LI 0));
	      comp(M.DEFINELABEL loopHead);
	      emit(M.BCC(M.NEQ, cmpWord(i), false_lab));
	      emit(M.MV(iR, M.ADD(i, M.LI 4)));
	      emit(M.BCC(M.NEQ, M.CMP(M.NEQ, i, M.LI n', M.LR), loopHead))
	    end
	    fun unroll i = 
	      if i=n' then ()
	      else (emit(M.BCC(M.NEQ, cmpWord(M.LI(i)), false_lab));
		    unroll (i+4))

          in
	      emit(M.MV(r1, regbind v));
	      emit(M.MV(r2, regbind w));
	      (* if n' <= 2 then unroll 0 else whileLoop();*)
	      unroll 0;
              gen(d, hp);
	      genlab(false_lab, e, hp)
	  end
	| gen(BRANCH(P.boxed, [x], _, a, b), hp) = let
	    val lab = Label.newLabel""
	    val cmp = M.CMP(M.NEQ, M.ANDB(regbind x, M.LI 1), M.LI 0, M.LR)
          in
	    emit(M.BCC(M.NEQ, cmp, lab));
	    gen(a, hp);
	    genlab(lab, b, hp)
	  end
        | gen(BRANCH(P.unboxed, x,c,a,b), hp) = gen(BRANCH(P.boxed,x,c,b,a), hp)
	| gen(e, hp) =  (PPCps.prcps e; print "\n"; error "genCluster.gen")
      end (*local*)

      fun fragComp () = let
	fun continue () = fcomp (Frag.next())
	and fcomp(NONE) = ()
	  | fcomp(SOME(_, Frag.KNOWNFUN _)) = continue ()
	  | fcomp(SOME(_, Frag.KNOWNCHK _)) = continue ()
	  | fcomp(SOME(_, Frag.STANDARD{func=ref NONE, ...})) = continue ()
	  | fcomp(SOME(lab, Frag.STANDARD{func as ref(SOME (zz as (_,f,vl,tl,e))), 
					  ...})) = let
	      val regfmls as (M.GPR linkreg::_) = ArgP.standard(typmap f, tl)
	      val baseval = 
		M.ADD(linkreg, 
		      M.LABEL(LE.MINUS(LE.CONST MachineSpec.constBaseRegOffset,
				      LE.LABEL lab)))
	    in
	      func := NONE;
	      comp(M.ORDERED[M.PSEUDO_OP(PseudoOp.MARK),
			     M.ENTRYLABEL lab]);
	      alignAllocptr f;
	      emit(assign(C.baseptr, baseval));
	      CallGc.stdCheckLimit{maxAlloc=4 * maxAlloc f, regfmls=regfmls, 
				   regtys=tl, return=M.JMP(linkreg,[])};
	      clearTables();
	      initialRegBindings(vl, regfmls, tl);
	      initTypBindings e;
              if !Control.CG.printit then (
              print "************************************************* \n";
              PPCps.printcps0 zz;
              print "************************************************* \n")
              else ();
	      continue(gen(e, 0))
	    end
	  | fcomp(SOME(lab, Frag.REALfrag r)) =
	      (comp(M.PSEUDO_OP
		     (PseudoOp.REALCONST(lab, IEEEReal.realconst r)) )
		 handle
	          IEEEReal.BadReal _ =>
		    err ErrorMsg.COMPLAIN ("real constant out of range: " ^ r)
			ErrorMsg.nullErrorBody;
	       continue ())
	  | fcomp(SOME(lab, Frag.STRINGfrag s)) = let
	      fun padString s = case ((size s) mod 4)
		of 0 => (s ^ "\000\000\000\000")
		 | 1 => (s ^ "\000\000\000")
		 | 2 => (s ^ "\000\000")
		 | 3 => (s ^ "\000")
		 | _ => error ""
		(*esac*)
	      val pOp = PseudoOp.STRINGCONST(lab, size s, padString s)
            in comp (M.PSEUDO_OP pOp); continue ()
	    end
      in
	fcomp (Frag.next())
      end (* fragComp *)

      (* execution starts at the first CPS function -- the frag 
       * is maintained as a queue.
       *)
      fun initFrags (start::rest : CPS.function list) = let
	fun init(func as (fk, f, _, _, _)) = 
	  Intmap.add genTbl (f, Frag.makeFrag(func, functionLabel f))
      in
	app init rest;
	init start
      end
    in
      initFrags cluster;
      comp(M.BEGINCLUSTER);
      fragComp();
      CallGc.emitLongJumpsToGCInvocation(regmap);
      comp(M.ENDCLUSTER regmap)
    end (* genCluster *)

    and emitMLRiscUnit(f) = let
      val regmap = Cells.resetRegs()
    in
      comp (M.BEGINCLUSTER);
      f regmap; 
      comp (M.ENDCLUSTER regmap)
    end
  in
    app mkGlobalTables funcs;
    app genCluster (Cluster.cluster funcs);
    emitMLRiscUnit (CallGc.emitInvokeGC)
  end (* codegen *)
end (* MLRiscGen *)

(*
 * $Log: mlriscGen.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:45  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.20  1998/01/08 22:35:43  dbm
 *   Fix for bug 1323 (bug1323.2.sml version) on hppa and alpha.
 *
 * Revision 1.19  1997/12/08 03:28:22  george
 *    allocptr not updated before Word32.div operation
 *
 * Revision 1.18  1997/12/01 20:05:43  george
 *   The allocation pointer must be update before word division operations,
 *   since they can trap. Note: It is a mistake to classify such operations
 *   as pure.
 *
 * Revision 1.17  1997/10/27  20:23:07  george
 * *** empty log message ***
 *
 * Revision 1.16  1997/10/27  01:42:42  george
 *   Fixed bug involving alignment of allocation pointer
 *
 * Revision 1.15  1997/10/03  09:40:39  george
 *   allocation pointer not updated before test(32,31)
 *
 * Revision 1.14  1997/09/17  17:15:29  george
 *   included dedicated registers in ESCAPEBLOCK
 *
 * Revision 1.13  1997/09/12  10:13:03  george
 *   Checklimit must be done with unsigned comparisons
 *
 * Revision 1.12  1997/08/27  17:53:54  george
 *    More accurate memory disambiguation maintenance.
 *
 * Revision 1.11  1997/08/13  15:57:52  george
 *   Fixed a bug in which the register counters were not being reset
 *   before memory disambiguation information was computed.
 *
 * Revision 1.10  1997/08/11  18:38:06  george
 *   Implemented correct but very conservative alias information for
 *   reference cells.
 *
 * Revision 1.9  1997/08/07  21:04:35  george
 *   fixed bugs in memory disambiguation
 *
 * Revision 1.8  1997/08/07  02:10:52  george
 *   Refined region information to the granularity of words  in the allocation space
 *
 * Revision 1.7  1997/08/03  14:16:01  george
 *    Allocation pointer increments are performed at function exit
 *    if possible.
 *
 * Revision 1.6  1997/07/28  20:05:02  george
 *   Added support for regions
 *
 * Revision 1.5  1997/07/17  12:37:12  george
 *   The regmap is now represented as an int map rather than using arrays.
 *
 * Revision 1.4  1997/07/10  04:03:00  george
 *   Translation of MARK and DEFINELABEL is now wrapped with ORDERED.
 *
 * Revision 1.3  1997/07/03  13:56:31  george
 *   Now we generate FCOPY.
 *
 * Revision 1.2  1997/05/20  12:17:56  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:34  george
 *   Version 109.24
 *
 *)
