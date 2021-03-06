(* buildFlowgraph.sml
 *
 * COPYRIGHT (c) 2001 Bell Labs, Lucent Technologies
 *)
signature CONTROL_FLOWGRAPH_GEN =
sig

   structure S   : INSTRUCTION_STREAM
   structure I   : INSTRUCTIONS
   structure P   : PSEUDO_OPS
   structure CFG : CONTROL_FLOW_GRAPH
   		where I = I
                  and P = P
   (*
    * This creates an emitter which can be used to build a CFG incrementally
    *)
   type instrStream = 
     (I.instruction, Annotations.annotations, I.C.cellset, CFG.cfg) S.stream

   val build : unit -> instrStream

end




functor BuildFlowgraph 
  (structure Props  : INSN_PROPERTIES
   structure Stream : INSTRUCTION_STREAM
   structure CFG    : CONTROL_FLOW_GRAPH  
			  where I = Props.I
			    and P = Stream.P
  ) : CONTROL_FLOWGRAPH_GEN =
struct
  structure CFG = CFG
  structure P = CFG.P
  structure I = Props.I
  structure G = Graph
  structure S = Stream
  structure Fmt = Format
  structure PB  = PseudoOpsBasisTyp

  exception LabelNotFound

  type instrStream = 
     (I.instruction, Annotations.annotations, CFG.I.C.cellset, CFG.cfg) S.stream

  fun error msg = MLRiscErrorMsg.error ("BuildFlowGraph", msg)

  val hashLabel = Word.toInt o Label.hash

  fun build ()  = let
    val cfg as ref(G.GRAPH graph) = ref(CFG.new())
   
    (* list of blocks generated so far *)
    val blockList   = ref ([] : CFG.block list)

    (* list of entry labels to patch successors of ENTRY *)
    val entryLabels = ref ([] : Label.label list)
   
    (* block id associated with a label*)
    val labelMap    = IntHashTable.mkTable(32, LabelNotFound)
    val findLabel   = IntHashTable.find labelMap
    val addLabel    = IntHashTable.insert labelMap

    (* Data in text segment is read-only *)
    datatype segment_t = TEXT | DATA | RO_DATA | BSS
    val segmentF    = ref TEXT

    (* the block names *)
    val blockNames   = ref [] : Annotations.annotations ref

    (* can instructions be reordered *)
    val reorder      = ref [] : Annotations.annotations ref

    (* noblock or invalid block has id of ~1 *)
    val noBlock = CFG.newBlock(~1, ref 0)

    (* current block being built up *)
    val currentBlock = ref noBlock


    (* add a new block and make it the current block being built up *)
    fun newBlock(freq) = let
      val G.GRAPH graph = !cfg
      val id = #new_id graph ()
      val blk as CFG.BLOCK{annotations, ...} = CFG.newBlock(id, ref freq)
    in
      currentBlock := blk;
      annotations := !blockNames @ !reorder;
      blockList := blk :: !blockList;
      #add_node graph (id, blk);
      blk
    end


    (* get current basic block *)
    fun getBlock () = 
     (case !currentBlock of CFG.BLOCK{id= ~1, ...} => newBlock(1) | blk => blk)


    (* ------------------------cluster---------------------------*)
    (* start a new cluster *)
    fun beginCluster _ = 
      (blockList := [];
       entryLabels := [];
       IntHashTable.clear labelMap;
       blockNames := [];
       currentBlock := noBlock)

    (* emit an instruction *)
    fun emit i = let
      val CFG.BLOCK{insns, ...} = getBlock()
      fun terminate() = currentBlock := noBlock;
    in 
      insns := i:: !insns;
      case Props.instrKind(i)
      of Props.IK_JUMP => terminate()
       | Props.IK_CALL_WITH_CUTS => terminate()
       | _ => ()
      (*esac*)
    end

    (* make current block an exit block *)
    fun exitBlock liveout = let
      fun setLiveOut(CFG.BLOCK{annotations, ...}) = 
	annotations := #create CFG.LIVEOUT liveout :: !annotations
    in 
      case !currentBlock
       of CFG.BLOCK{id= ~1, ...} =>
	   (case !blockList
	     of [] => error "exitBlocks"
	      | blk::_ => setLiveOut blk
	   (*esac*))
        | blk => setLiveOut blk
    end (* exitBlock *)


    (* end cluster --- all done *)
    fun endCluster (annotations) = let
      val cfg as G.GRAPH graph = (!cfg before cfg := CFG.new())
      val _ = CFG.init(cfg)		(* create unique ENTRY/EXIT nodes *)

      val ENTRY = hd(#entries graph ())
      val EXIT = hd(#exits graph ())

      fun addEdge(from, to, kind) =
	#add_edge graph (from, to, CFG.EDGE{k=kind, w=ref 0, a=ref[]})

      fun target lab =
	(case (IntHashTable.find labelMap (hashLabel lab))
	  of SOME bId => bId 
	   | NONE => EXIT)

      fun jump(from, [Props.ESCAPES], _) = addEdge(from, EXIT, CFG.FALLSTHRU)
	| jump(from, [Props.LABELLED lab], _) = addEdge(from, target lab, CFG.JUMP)
	| jump(from, [Props.LABELLED lab, Props.FALLTHROUGH], blks) = let
	   fun next(CFG.BLOCK{id, ...}::_) = id
	     | next [] = error "jump.next"
          in
	    addEdge(from, target lab, CFG.BRANCH true);
	    addEdge(from, next blks, CFG.BRANCH false)
	  end
	| jump(from, [f as Props.FALLTHROUGH, l as Props.LABELLED _], blks) = 
	    jump(from, [l, f], blks)
	| jump(from, targets, _) = let
	    fun switch(Props.LABELLED lab, n) = 
	         (addEdge(from, target lab, CFG.SWITCH(n)); n+1)
	      | switch _ = error "jump.switch"
          in List.foldl switch 0 targets; ()
          end

      and fallsThru(id, blks) = 
	case blks
	 of [] => addEdge(id, EXIT, CFG.FALLSTHRU)
	    | CFG.BLOCK{id=next, ...}::_ => addEdge(id, next, CFG.FALLSTHRU)
	  (*esac*)

	and addEdges [] = ()
	  | addEdges(CFG.BLOCK{id, insns=ref[], ...}::blocks) = fallsThru(id, blocks)
	  | addEdges(CFG.BLOCK{id, insns=ref(instr::_), ...}::blocks) = let
	      fun doJmp () = jump(id, Props.branchTargets instr, blocks)
	    in
	     case Props.instrKind instr
	      of Props.IK_JUMP => doJmp()
	       | Props.IK_CALL_WITH_CUTS => doJmp()
	       | _ => fallsThru(id, blocks)
	     (*esac*);
	     addEdges(blocks)
	    end
      in
	addEdges (rev(!blockList));
	app (fn lab => addEdge(ENTRY, target lab, CFG.ENTRY)) (!entryLabels);
	let val an = CFG.annotations cfg in  an := annotations @ (!an) end;
	cfg
      end (* endCluster *)


      (* ------------------------annotations-----------------------*)
      (* XXX: Bug: EMPTYBLOCK does not really generate an empty block 
       *	but merely terminates the current block. Contradicts the comment
       *  in instructions/mlriscAnnotations.sig.
       *  It should be (newBlock(1); newBlock(1); ())
       *)

      (* Add a new annotation *)
      fun addAnnotation a = 
       (case a 
	 of MLRiscAnnotations.BLOCKNAMES names =>
	     (blockNames := names;  newBlock(1); ())
	  | MLRiscAnnotations.EMPTYBLOCK => (newBlock(1); ())
	  | MLRiscAnnotations.EXECUTIONFREQ f => 
	     (case !currentBlock
	       of CFG.BLOCK{id= ~1, ...} => (newBlock(f); ())
		| CFG.BLOCK{freq, ...} => freq := f
	     (*esac*))
	  | a => let 
	       val CFG.BLOCK{annotations,...} = getBlock()
	     in  annotations := a :: !annotations
	     end
       (*esac*))

      (* get annotation associated with flow graph *)
      fun getAnnotations () = CFG.annotations(!cfg)

      (* add a comment annotation to the current block *)
      fun comment msg = 
	case !segmentF 
         of TEXT => addAnnotation (#create MLRiscAnnotations.COMMENT msg)
          | _ => let
		val Graph.GRAPH graph = !cfg
		val CFG.INFO{data, ...} = #graph_info graph
              in data :=  PB.COMMENT msg :: !data
	      end


      (* -------------------------labels---------------------------*)
      (* BUG: Does not respect any ordering between labels and pseudoOps. 
       * This could be a problem with jump tables. 
       *)
      fun addPseudoOp p = let
	val Graph.GRAPH graph = !cfg
	val CFG.INFO{data, ...} = #graph_info graph

	fun addAlignment () = 
	  (case !segmentF
           of TEXT => let
		val CFG.BLOCK{align, ...} = newBlock(1)
              in align := SOME p
    	      end
	    | _ => data := p :: !data
	  (*esac*))

	fun startSegment(seg) = (data := p :: !data; segmentF := seg)

	fun addData () = data := p :: !data

	fun chkAddData(seg) =
	  (case !segmentF
	   of TEXT => 
	       error (Fmt.format "addPseudoOp: %s in TEXT segment" [Fmt.STR seg])
	    | _ => addData()
	  (*esac*))

      in
	case p
	of PB.ALIGN_SZ _ => addAlignment()
	 | PB.ALIGN_ENTRY => addAlignment()
	 | PB.ALIGN_LABEL => addAlignment()
	 | PB.DATA_LABEL _ =>
	     (case !segmentF 
	      of TEXT => error "addPseudoOp: DATA_LABEL in TEXT segment"
	       | _ => (data := p:: !data)
	     (*esac*))

	 | PB.DATA_READ_ONLY => startSegment(RO_DATA)
	 | PB.DATA => startSegment(DATA)
	 | PB.TEXT => startSegment(TEXT)
	 | PB.BSS => startSegment(BSS)
	 | PB.SECTION _ => 
	    (case !segmentF
	      of TEXT => error "addPseudoOp: SECTION in TEXT segment"
	       | _ => data := p :: !data
	    (*esac*))
	 | PB.REORDER => (reorder := []; newBlock(1); ())
	 | PB.NOREORDER => 
	     (reorder := [#create MLRiscAnnotations.NOREORDER ()]; newBlock(1); ())

	 | PB.INT _    => chkAddData("INT")
	 | PB.FLOAT _  => chkAddData("FLOAT")
	 | PB.ASCII _  => chkAddData("ASCII")
	 | PB.ASCIIZ _ => chkAddData("ASCIIZ")
	 | PB.SPACE _  => chkAddData("SPACE")
	 | PB.COMMENT _ => chkAddData("COMMENT")
	 | PB.IMPORT _ => addData()
	 | PB.EXPORT _ => addData()
	 | PB.EXT _ => chkAddData("EXT")
      end

      fun defineLabel lab = 
	(case !segmentF 
	 of TEXT => 
	     (case findLabel (hashLabel lab)
	       of NONE => let
		    fun newBlk () = 
		      (case !currentBlock
			of CFG.BLOCK{id= ~1, ...} => newBlock(1)
			 | CFG.BLOCK{insns=ref[], ...} => !currentBlock (* probably aligned block *)
			 | _ => newBlock(1)
		      (*esac*))
		    val CFG.BLOCK{id, labels, ...} = newBlk()
		  in 
		      labels := lab :: !labels;
		      addLabel(hashLabel lab, id)
		  end
		| SOME _ => 
		   error (concat
		     ["multiple definitions of label \"", Label.toString lab, "\""])
	      (*esac*))
 	 | _ => let	
	       (* non-text segment *)
	       val Graph.GRAPH graph = !cfg
	       val CFG.INFO{data, ...} = #graph_info graph
             in
	      data := PB.DATA_LABEL lab :: !data
	     end
       (*esac*))
      
    fun entryLabel lab = (defineLabel lab; entryLabels := lab :: !entryLabels)
  in
    S.STREAM
      { 
         comment       = comment,
         getAnnotations= getAnnotations,
         annotation    = addAnnotation,
         defineLabel   = defineLabel,
         entryLabel    = entryLabel,
         pseudoOp      = addPseudoOp,
         beginCluster  = beginCluster,
         emit          = emit,
         exitBlock     = exitBlock,
         endCluster    = endCluster
      }
  end (* build *)
end
