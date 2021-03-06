(* bbsched2.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

(** bbsched2.sml - invoke scheduling after span dependent resolution **)

functor BBSched2
    (structure Flowgraph : FLOWGRAPH
     structure Jumps : SDI_JUMPS
     structure Emitter : INSTRUCTION_EMITTER
       sharing Emitter.P = Flowgraph.P
       sharing Flowgraph.I = Jumps.I = Emitter.I): BBSCHED =

struct

  structure F = Flowgraph
  structure I = F.I
  structure C = I.C
  structure E = Emitter
  structure J = Jumps
  structure P = Flowgraph.P

  fun error msg = MLRiscErrorMsg.error("BBSched",msg)

  datatype code =
      SDI of {size : int ref,		(* variable sized *)
	      insn : I.instruction}
    | FIXED of {size: int,		(* size of fixed instructions *)
		insns: I.instruction list}
   
  datatype compressed = 
      PSEUDO of P.pseudo_op
    | LABEL  of Label.label
    | CODE of  code list
    | CLUSTER of {comp : compressed list, regmap : int -> int}

  val clusterList : compressed list ref = ref []
  fun cleanUp() = clusterList := []

  fun bbsched(cluster as F.CLUSTER{blocks, regmap, ...}) = let
    val regmap = C.lookup regmap
    fun compress(F.PSEUDO pOp::rest) = PSEUDO pOp::compress rest
      | compress(F.LABEL lab::rest) = LABEL lab:: compress rest
      | compress(F.BBLOCK{insns, ...}::rest) = let
	  fun mkCode(0, [], [], code) = code
	    | mkCode(size, insns, [], code) = FIXED{size=size, insns=insns}:: code
	    | mkCode(size, insns, instr::instrs, code) = let
		val s = J.minSize instr
	      in
		if J.isSdi instr then let
		    val sdi = SDI{size=ref s, insn=instr}
		  in
		    if size = 0 then 
		      mkCode(0, [], instrs, sdi::code)
		    else 
		      mkCode(0, [], instrs, 
			     sdi::FIXED{size=size, insns=insns}::code)
		  end
		else mkCode(size+s, instr::insns, instrs, code)
	      end
	in 
	  CODE(mkCode(0, [], !insns, [])) :: compress rest
	end
      | compress [] = []
      | compress _ = error "compress"
  in clusterList:=CLUSTER{comp = compress blocks, regmap=regmap}:: (!clusterList)
  end

  fun finish() = let
    fun labels(PSEUDO pOp::rest, pos) = 
          (P.adjustLabels(pOp, pos); labels(rest, pos+P.sizeOf(pOp,pos)))
      | labels(LABEL lab::rest, pos) = 
	 (Label.setAddr(lab,pos); labels(rest, pos))
      | labels(CODE code::rest, pos) = let
	  fun size(FIXED{size, ...}) = size
	    | size(SDI{size, ...}) = !size
	in labels(rest, List.foldl (fn (c, b) => size(c) + b) pos code)
	end
      | labels(CLUSTER{comp, ...}::rest, pos) = labels(rest, labels(comp,pos))
      | labels([], pos) = pos

    fun adjust(CLUSTER{comp, regmap}::cluster, pos, changed) = let
          fun f (PSEUDO pOp::rest, pos, changed) = 
	        f(rest, pos+P.sizeOf(pOp,pos), changed)
	    | f (LABEL _::rest, pos, changed) = f(rest, pos, changed)
	    | f (CODE code::rest, pos, changed) = let
		fun doCode(FIXED{size, ...}::rest, pos, changed) = 
		      doCode(rest, pos+size, changed)
		  | doCode(SDI{size, insn}::rest, pos, changed) = let
	  	      val newSize = J.sdiSize(insn, regmap, Label.addrOf, pos)
 	  	    in
		      if newSize <= !size then doCode(rest, !size + pos, changed)
		      else (size:=newSize; doCode(rest, newSize+pos, true))
		    end
		  | doCode([], pos, changed) = f(rest, pos, changed)
              in doCode(code, pos, changed)
	      end
	    | f ([], pos, changed) = adjust(cluster, pos, changed)
	    | f _ = error "adjust.f"
        in f(comp, pos, changed)
	end
      | adjust(_::_, _, _) = error "adjust"
      | adjust([], _, changed) = changed

    fun fixpoint zl = let 
      val size = labels(zl, 0)
    in if adjust(zl, 0, false) then fixpoint zl else size
    end

    val Emitter.S.STREAM{emit,defineLabel,beginCluster,pseudoOp,...} = 
            Emitter.makeStream []

    fun emitCluster(CLUSTER{comp, regmap},loc) = let
      val emit = emit regmap
      fun process(PSEUDO pOp,loc) = (pseudoOp pOp; loc + P.sizeOf(pOp,loc))
	| process(LABEL lab,loc) = (defineLabel lab; loc)
	| process(CODE code,loc) = let
	    fun emitInstrs insns = app emit insns
	    fun e(FIXED{insns, size,...},loc) = (emitInstrs insns; loc+size)
	      | e(SDI{size, insn},loc) = 
                   (emitInstrs(J.expand(insn, !size, loc)); !size + loc)
	  in foldl e loc code
	  end
	| process _ = error "process"
    in foldl process loc comp
    end
      | emitCluster _ = error "emitCluster"

    val compressed = (rev (!clusterList)) before cleanUp()
  in
    beginCluster(fixpoint compressed);
    foldl emitCluster 0 compressed; 
    ()
  end (*finish*)

end (* bbsched2 *)


