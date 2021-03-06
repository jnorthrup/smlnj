(* bbsched2.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

(** bbsched2.sml - invoke scheduling after span dependent resolution **)

functor BBSched2
    (structure Flowgraph : FLOWGRAPH
     structure Jumps : SDI_JUMPS
     structure Emitter : EMITTER_NEW

       sharing Emitter.F = Flowgraph
       sharing Flowgraph.I = Jumps.I = Emitter.I): BBSCHED =

struct

  structure F = Flowgraph
  structure I = F.I
  structure C = I.C
  structure E = Emitter
  structure J = Jumps
  structure P = Flowgraph.P

  fun error msg = MLRiscErrorMsg.impossible ("BBSched."^msg)

  datatype code =
      SDI of {size : int ref,		(* variable sized *)
	      insn : I.instruction}
    | FIXED of {size: int,		(* size of fixed instructions *)
		insns: I.instruction list}
   
  datatype compressed = 
      PSEUDO of P.pseudo_op
    | LABEL  of Label.label
    | CODE of  code list
    | CLUSTER of {comp : compressed list, regmap : int Intmap.intmap}

  val clusterList : compressed list ref = ref []
  fun cleanUp() = clusterList := []

  fun bbsched(cluster as F.CLUSTER{blocks, regmap, ...}) = let
    fun compress(F.PSEUDO pOp::rest) = PSEUDO pOp::compress rest
      | compress(F.LABEL lab::rest) = LABEL lab:: compress rest
      | compress(F.ORDERED blks::rest) = compress(blks@rest)
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
        in f(comp, pos, changed)
	end
      | adjust(_::_, _, _) = error "adjust"
      | adjust([], _, changed) = changed

    fun fixpoint zl = let 
      val size = labels(zl, 0)
    in if adjust(zl, 0, false) then fixpoint zl else size
    end

    fun emitCluster(CLUSTER{comp, regmap}) = let
      fun emit(PSEUDO pOp) = E.pseudoOp pOp
	| emit(LABEL lab) = E.defineLabel lab
	| emit(CODE code) = let
	    fun emitInstrs insns = app (fn i => E.emitInstr(i, regmap)) insns
	    fun e(FIXED{insns, ...}) = emitInstrs insns
	      | e(SDI{size, insn}) = emitInstrs(J.expand(insn, !size))
	  in app e code
	  end
    in app emit comp
    end

    val compressed = (rev (!clusterList)) before cleanUp()
  in
    E.init(fixpoint compressed);
    app emitCluster compressed
  end (*finish*)

end (* bbsched2 *)


(*
 * $Log: bbsched2.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:35  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.4  1997/09/17 17:11:14  george
 *   Changed this module to perform just span dependency and no scheduling.
 *
# Revision 1.3  1997/07/17  12:28:33  george
#   The regmap is now represented as an int map rather than using arrays.
#
# Revision 1.2  1997/07/10  04:00:27  george
#   Changes to deal with F.ORDERED.
#
# Revision 1.1.1.1  1997/04/19  18:14:20  george
#   Version 109.27
#
 *)
