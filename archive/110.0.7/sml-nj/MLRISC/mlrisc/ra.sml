(* Copyright 1996 AT&T Bell Laboratories 
 *
 *)

(** Graph coloring register allocation.
 ** Implements the 'iterated register coalescing' scheme described 
 ** in POPL'96, and TOPLAS v18 #3, pp 325-353. 
 **)
functor RegAllocator 
  (structure RaArch : RA_ARCH_PARAMS) 
  (structure RaUser : RA_USER_PARAMS 
(*    where I = RaArch.I -- bug 1205 *)
    where type I.operand = RaArch.I.operand
      and type I.instruction = RaArch.I.instruction 
     (* -- equivalent where type if where structure not working *)
  ) : RA =
struct
  structure F = RaArch.Liveness.F
  structure P = RaArch.InsnProps
  structure C = F.C
  structure SL = SortedList
  structure BM = TriangularBitMatrix

  fun error msg = MLRiscErrorMsg.impossible ("RegAllocator." ^ msg)
  fun assert(msg, true) = () | assert(msg, false) = error msg

		(*---------datatypes------------ *)    

  datatype mode = REGISTER_ALLOCATION | COPY_PROPAGATION

  datatype moveStatus = MOVE | COALESCED | CONSTRAINED | LOST | WORKLIST

  datatype move = 
    MV of {src : node,			(* source register of move *)
	   dst : node,			(* destination register of move *)
	   status : moveStatus ref	(* coalesced? *)
	  }

  and nodeStatus = REMOVED | PSEUDO | ALIASED of node | COLORED of int

  and node = 
    NODE of { number : int,		(* node number *)
	      movecnt: int ref,		(* # of moves this node is involved in *)
	      movelist: move list ref,	(* moves associated with this node *)
	      degree : int ref,		(* current degree *)
	      color : nodeStatus ref,	(* status *)
	      adj : node list ref	(* adjacency list *)
            }
  (* the valid transitions for a node are:
   * PSEUDO -> REMOVED			% during simplify
   * PSEUDO -> ALIASED(n)		% during coalescing
   * REMOVED -> COLORED(r)		% assigning a color
   *
   *  ... all others are illegal.
   *)

  fun newNode(num, col) = 
    NODE{number=num,
	 color=ref col,
	 degree=ref 0,
	 adj=ref [],
	 movecnt = ref 0,
	 movelist = ref []}

  fun nodeNumber(NODE{number, ...}) = number

  fun nodeMember(_, []) = false
    | nodeMember(node as NODE{number=x, ...}, NODE{number=y,...}::rest) = 
        x = y orelse nodeMember(node, rest)

  fun chase(NODE{color=ref(ALIASED r), ...}) = chase r
    | chase x = x 

  fun isMoveRelated(NODE{movecnt=ref 0, ...}) = false
    | isMoveRelated _ = true


		(*-------------------------------*)
  (* set of dedicated registers *)
  val defUse		= RaArch.defUse
  val dedicated         = SL.uniq RaUser.dedicated
  val isDedicated       = SL.member dedicated

  (* Note: This function maintains the order of members in rset
   * which is important when dealing with parallel copies.
   *)
  fun rmvDedicated rset = let
    fun f (x::xs) = if isDedicated x then f xs else x::f xs
      | f [] = []
  in f rset
  end

  (* register mapping functions *)
  fun uniqMap(f, l) = let
    fun map([], acc) = acc
      | map(x::xs, acc) = map(xs, SL.enter(f x, acc))
  in map(l, [])
  end

		(*---------printing------------ *)
  fun prList (l:int list,msg:string) = let
      fun pr [] = print "\n"
	| pr (x::xs) = (print (Int.toString x ^ " "); pr xs)
  in
	print msg; pr l
  end

  fun printBlocks(blks, regmap) = let
    fun prBlks([]) = print"\n"
      | prBlks(F.BBLOCK{blknum,insns,liveOut,liveIn,succ,pred,...}::blocks)=let
	  fun regset cellset = 
	    map (fn r => Intmap.map regmap r) (RaArch.regSet(cellset))
	  fun pr [] = prList(regset(!liveOut), "liveOut: ")
	    | pr (instr::rest) = 
	       (RaArch.AsmEmitter.emitInstr(instr,regmap); pr rest)
	  fun blkNum(F.BBLOCK{blknum, ...}) = blknum
	in
	  print("BLOCK" ^ Int.toString blknum ^ "\n");
	  prList(regset (!liveIn), "LiveIn :");
	  prList(map blkNum (!pred),"predecessors: ");
	  case !insns of [] => print "empty instruction sequence\n"
		       |  l  => pr(rev l)
	  (*esac*);
	  prList(map blkNum (!succ),"successors: ");
	  prBlks(blocks)
	end
      | prBlks(F.LABEL lab::blocks) = 
	  (print(Label.nameOf lab^":\n");
	   prBlks(blocks)) 
      | prBlks(F.ORDERED blks::blocks) = (prBlks blks; prBlks blocks)
      | prBlks(_::blocks) = prBlks(blocks)

    val saveStrm= !AsmStream.asmOutStream
  in
    AsmStream.asmOutStream:=TextIO.stdOut;
    prBlks blks;
    AsmStream.asmOutStream:=saveStrm
  end

  fun debug(msg, blocks, regmap) =			
    if false then
      (print ("------------------" ^ msg ^ " ----------------\n");
       printBlocks(blocks,regmap))
    else  () 

		(*------------------------------*)
  fun graphColoring(mode, blocks, cblocks, blockDU, prevSpills, 
						    nodes, regmap) = let
    datatype worklists = WKL of
      {simplifyWkl: node list,	(* nodes that can be simplified *)
       moveWkl : move list,	(* moves to be considered for coalescing *)
       freezeWkl : node list,	(* all n, s.t. degree(n)<K and moveRelated(n) *)
       spillWkl : node list,	(* all n, s.t. degree(n)>=K  *)
       stack : node list}	(* nodes removed from the graph *)

    val K = RaUser.nFreeRegs
    val numOfBlocks = Array.length cblocks
    val maxR   = RaArch.maxPseudoR()

    val getnode = Intmap.map nodes

    (* Info to undo a spill when an optimistic spill has occurred *)
    val spillFlag = ref false		
    val undoInfo : (node * moveStatus ref) list ref  = ref []

    (* lower triangular bitmatrix primitives *)
    (* NOTE: The average ratio of E/N is about 16 *)
    val bitMatrix = BM.new (RaArch.numRegs() * 20)
    val addBitMatrix = BM.add bitMatrix
    local 
      val member = BM.member bitMatrix
    in
      fun memBitMatrix(NODE{number=x,...}, NODE{number=y,...}) = 
	member (if x<y then (x, y) else (y, x))
    end

	    (*--------interference graph construction--------*)

    (* add an edge to the interference graph.
     * note --- adjacency lists for machine registers are not maintained.
     *)
    fun addEdge(x as NODE{number=xn, ...}, y as NODE{number=yn, ...}) = let
      fun add(r as NODE{color=ref PSEUDO, adj, degree,...}, s) =
	    (adj := s :: !adj; 
	     degree := 1 + !degree)
	| add(NODE{color=ref(ALIASED _), ...}, _) = error "addEdge.add: ALIASED"
	| add(NODE{color=ref(REMOVED), ...}, _) = error "addEdge.add: REMOVED"
        | add _ = ()
    in
      if xn = yn then ()
      else if addBitMatrix(if xn < yn then (xn, yn) else (yn, xn)) then
	(add(x, y); add(y, x))
      else ()
    end

    (* Builds the interference graph and initialMove list *)
    fun mkInterferenceGraph() = let
      (* The movecnt field is used to (lazily) record members in the 
       * live set. Deleted members are removed during an 
       * addEdgeForallLive operation.
       *)
      fun delete(NODE{movecnt, ...}) = movecnt:=0
      fun insert((node as NODE{movecnt as ref 0, ...})::rest, live) = 
	    (movecnt:=1; insert(rest, node::live))
	| insert(_::rest, live) = insert(rest, live)
	| insert([], live) = live
      fun addEdgeForallLive([], live) = live
	| addEdgeForallLive(d::ds, live) = let
	    fun f ([], pruned) = pruned
	      | f ((n as NODE{movecnt as ref 1, ...})::rest, pruned) =
	          (addEdge(d, n); f(rest, n::pruned))
	      | f (_::rest, pruned) = f(rest, pruned)
	  in
	    addEdgeForallLive(ds, f(live, []))
	  end
      fun forallBlocks(~1, mvs) = mvs
	| forallBlocks(n, mvs) = let
	    val F.BBLOCK{insns, liveOut, ...} = Array.sub(cblocks, n)
	    val bdu = Array.sub(blockDU, n)
	    fun doBlock([], _, live, mvs) = 
	          (app (fn NODE{movecnt, ...} => movecnt := 0) live;
		   forallBlocks(n-1, mvs))
	      | doBlock(instr::rest, (def',use')::bdu, live', mvs) = let
	          val def = map chase def'
		  val use = map chase use'

		  (* move instructions are treated specially *)
		  (* There  is a subtle interaction between parallel
		      moves and interference graph construction. When we
		      have {d1, ... dn} <- {s1, ... sn} and liveOut we 
		      should make di interfere with:

			  liveOut U {d1, ... dn} U ({s1, ... sn} \ {si})

		      This is not currently done.
		   *)
		  fun zip(d::defs, u::uses, l) = 
		       zip(defs, uses, MV{src=u, dst=d, status=ref WORKLIST}::l)
		    | zip(_, _, l) = l
		  val moves = 
		    if P.moveInstr instr then 
		      if length def <> length use then mvs else zip(def,use,mvs)
		    else mvs

		  val live = 
		    if length def > 1 then
		      addEdgeForallLive(def, insert(def, live'))
		    else addEdgeForallLive(def, live')
	        in 
		  app delete def;
		  doBlock(rest, bdu, insert(use,live), moves)
		end  
	    val lout = map getnode (rmvDedicated(RaArch.regSet(!liveOut)))
	  in
	    doBlock(!insns, bdu, insert(lout, []), mvs)
	  end
      (* Filter moves that already have an interference.
       * Also initialize the movelist and movecnt fields at this time.
       *)
      fun filter [] = []
	| filter (MV{src=NODE{color=ref(COLORED _), ...}, 
		     dst=NODE{color=ref(COLORED _), ...}, ...}::rest) = 
	    filter rest
	| filter ((mv as MV{src, dst, ...})::rest) = 
	  if memBitMatrix(src, dst) then filter rest
	  else let 
	      fun info(u as NODE{color=ref PSEUDO, movecnt, movelist,...}) =
		   (movelist := mv :: !movelist;   movecnt := 1 + !movecnt)
		| info _ = ()
	    in info src;  info dst;  mv::filter rest
	    end
    in filter(forallBlocks(numOfBlocks-1, []))
    end (* mkInterferenceGraph *)


		    (*--------build worklists----------*)

    (* make initial worklists. Note: register aliasing may have
     * occurred due to previous rounds of graph-coloring; therefore
     * nodes may already be colored or aliased.
     *)
    fun mkInitialWorkLists initialMoves = let
      fun iter([], simpWkl, fzWkl, spillWkl) =
	    {simplifyWkl = simpWkl,
	     freezeWkl   = fzWkl,
	     spillWkl    = spillWkl,
	     moveWkl     = initialMoves,
	     stack       = []}
	| iter((_, node)::rest, simpWkl, fzWkl, spillWkl) = 
	   (case node
	    of NODE{color=ref PSEUDO, degree, ...} =>
		if !degree >= K then
		  iter(rest, simpWkl, fzWkl, node::spillWkl)
		else if isMoveRelated(node) then
		   iter(rest, simpWkl, node::fzWkl, spillWkl)
		else 
		   iter(rest, node::simpWkl, fzWkl, spillWkl)
	     | _ => 
		iter(rest, simpWkl, fzWkl, spillWkl)
           (*esac*))
    in iter(Intmap.intMapToList nodes, [], [], [])
    end

    fun liveness blocks = let
      fun regmap i = let
	val node = getnode i 
      in
	case node
	 of NODE{color= ref (COLORED r), ...} => r
	  | NODE{color=ref PSEUDO, ...} => nodeNumber node
	  | NODE{color=ref(ALIASED r), ...} => nodeNumber(chase node)
	  | _ => error "liveness.regmap"
      end handle _ => i			(* XXX *)
    in RaArch.Liveness.liveness(blocks, regmap)
    end

    val _ = liveness blocks
    val initialMoves = mkInterferenceGraph()
    val initialWkls = mkInitialWorkLists initialMoves

    (* debugging *)
    fun dumpGraph() = let
      fun prAdj(nodes, n)= prList(map (nodeNumber o chase) nodes, n)
    in
      Intmap.app 
        (fn (n, NODE{adj, ...}) =>
	    prAdj (!adj, Int.toString(n) ^ " <--> "))
	nodes
    end

    val _ = debug("before register allocation", blocks, regmap);

		    (*---------simplify-----------*)

    (* activate moves associated with a node and its neighbors *)
    fun enableMoves(node as NODE{adj, ...}, moveWkl) = let
      fun addMvWkl([], wkl) = wkl
	| addMvWkl((mv as MV{status, ...})::rest, wkl) =
	   (case !status
	     of MOVE => 
	         (status := WORKLIST; addMvWkl(rest, mv::wkl))
	      | _ => addMvWkl(rest, wkl)
	   (*esac*))

      fun add([], wkl) = wkl
	| add((node as NODE{movelist, color=ref PSEUDO,...})::ns, wkl) = 
	   if isMoveRelated node then
	     add(ns, addMvWkl(!movelist, wkl))
	   else
	     add(ns, wkl)
	| add(_::ns, wkl) = wkl
    in
      add(node:: (!adj), moveWkl)
    end

    (* decrement the degree associated with a node returning a potentially
     * new set of worklists --- simplifyWkl, freezeWkl, and moveWkl.
     *)
    fun decrementDegree(node as (NODE{degree as ref d, ...}), 
			simpWkl, fzWkl, mvWkl) = 
      (degree := d - 1;
       if d = K then let
	   val moveWkl = enableMoves(node, mvWkl)
	 in
	   if isMoveRelated(node) then
	     (simpWkl, node::fzWkl, moveWkl)
	   else
	     (node::simpWkl, fzWkl, moveWkl)
	 end
       else
	 (simpWkl, fzWkl, mvWkl))


    (* for every node removed from the simplify worklist, decrement the
     * degree of all of its neighbors, potentially adding the neighbor
     * to the simplify worklist.
     *)
    fun simplify(WKL{simplifyWkl,freezeWkl,spillWkl,moveWkl,stack}) = let
      fun loop([], fzWkl, mvWkl, stack) = 
	    WKL{simplifyWkl=[], freezeWkl=fzWkl, moveWkl=mvWkl, 
		stack=stack, spillWkl=spillWkl}
	| loop((node as NODE{color as ref PSEUDO, adj, ...})::wkl, 
	       fzWkl, mvWkl, stack) = let
	    fun forallAdj([], simpWkl, fzWkl, mvWkl) = 
	          loop(simpWkl, fzWkl, mvWkl, node::stack)
	      | forallAdj((n as NODE{color as ref PSEUDO, ...})::rest, 
			  wkl, fzWkl, mvWkl) = let
	          val  (wkl, fzWkl, mvWkl) = decrementDegree(n, wkl, fzWkl, mvWkl)
	        in
		  forallAdj(rest, wkl, fzWkl, mvWkl)
		end
	      | forallAdj(_::rest, simpWkl, fzWkl, mvWkl) = 
		  forallAdj(rest, simpWkl, fzWkl, mvWkl)
	  in
	    color := REMOVED;
	    forallAdj(!adj, wkl, fzWkl, mvWkl)
	  end
	| loop(_::ns, fzWkl, mvWkl, stack) = loop(ns, fzWkl, mvWkl, stack)
    in	    
      loop(simplifyWkl, freezeWkl, moveWkl, stack)
    end

		    (*-----------coalesce-------------*)

    fun coalesce(WKL{moveWkl, simplifyWkl, freezeWkl, spillWkl, stack}) = let
      (* v is being replaced by u *)
      fun combine(v as NODE{color=cv, movecnt, movelist=mv, adj, ...}, 
		  u as NODE{color=cu, movelist=mu, ...}, 
		  mvWkl, simpWkl, fzWkl) = let
	(* merge moveList entries, taking the opportunity to prune the lists *)
	fun mergeMoveLists([], [], mvs) = mvs
	  | mergeMoveLists([], xmvs, mvs) = mergeMoveLists(xmvs, [], mvs)
	  | mergeMoveLists((mv as MV{status,...})::rest, other, mvs) = 
	     (case !status
	       of (MOVE | WORKLIST) =>
		     mergeMoveLists(rest, other, mv::mvs)
		| _ => mergeMoveLists(rest, other, mvs)
	     (*esac*))

	(* form combined node *)
	fun union([], mvWkl, simpWkl, fzWkl) = (mvWkl, simpWkl, fzWkl)
	  | union((t as NODE{color, ...})::rest, mvWkl, simpWkl, fzWkl) =
	    (case color
	      of ref (COLORED _) =>
	          (addEdge(t, u); union(rest, mvWkl, simpWkl, fzWkl))
	       | ref PSEUDO =>
		  ((* the order of addEdge and decrementDegree is important *)
		   addEdge (t, u);
		   let val (wkl, fzWkl, mvWkl) =
			          decrementDegree(t, simpWkl, fzWkl, mvWkl)
 	 	   in
		     union(rest, mvWkl, wkl, fzWkl)
		   end)
	       | _ => union(rest, mvWkl, simpWkl, fzWkl)
	     (*esac*))
      in
	cv := ALIASED u;
	movecnt := 0;
	case cu 
	 of ref PSEUDO => mu := mergeMoveLists(!mu, !mv, [])
          | _ => ()
	(*esac*);
	union(!adj, mvWkl, simpWkl, fzWkl)
      end (*combine*)

      (* If a node is no longer move-related as a result of coalescing,
       * and can become candidate for the  next round of simplification.
       *)
      fun addWkl(node as NODE{color=ref PSEUDO, 
			      movecnt as ref mc, 
			      degree, ...},  c, wkl) = let
	    val ncnt = mc - c
	  in
	    if  ncnt <> 0 then (movecnt := ncnt; wkl)
	    else if !degree >= K then wkl
	    else node::wkl
	  end  
	| addWkl(_, _, wkl) = wkl

      (* heuristic used to determine if a pseudo and machine register
       * can be coalesced.
       *)
      fun safe(r, NODE{adj, ...}) = let
	fun f [] = true
	  | f (NODE{color=ref (COLORED _), ...}::rest) = f rest
	  | f ((x as NODE{degree, ...})::rest) = 
	    (!degree < K orelse memBitMatrix(x, r)) andalso f rest
      in
	f(!adj)
      end

      (* return true if Briggs et.al. conservative heuristic applies  *)
      fun conservative(x as NODE{degree=ref dx, adj=ref xadj, ...},
		       y as NODE{degree=ref dy, adj=ref yadj, ...}) =
	dx + dy < K 
	orelse let 
	    (* movecnt is used as a temporary scratch to record high degree
	     * or colored nodes we have already visited
	     * ((movecnt = ~1) => visited)
	     *)
            fun g(_, _, 0) = false
	      | g([], [], _) = true
	      | g([], yadj, k) = g(yadj, [], k)
	      | g(NODE{color=ref REMOVED, ...}::vs, yadj, k) = g(vs, yadj, k)
	      | g(NODE{color=ref(ALIASED _), ...}::vs, yadj, k) = g(vs, yadj, k)
	      | g(NODE{movecnt=ref ~1, ...} ::vs, yadj, k) = g(vs, yadj, k)
	      | g(NODE{movecnt, color=ref(COLORED _), ...}::vs, yadj, k) = let
	          val m = !movecnt
		in movecnt := ~1;   g(vs, yadj, k-1) before movecnt := m
		end
	      | g(NODE{movecnt as ref m, 
		       degree, color=ref PSEUDO,...}::vs, yadj, k) = 
		  if !degree < K then g(vs, yadj, k)
		  else (movecnt := ~1; 
			g(vs, yadj, k-1) before movecnt := m)
	  in g(xadj, yadj, K)
	  end

      (* iterate over move worklist *)
      fun doMoveWkl((mv as MV{src,dst,status,...})::rest, wkl, fzWkl) = let
	    val (u as NODE{number=u', color as ref ucol, ...},
		 v as NODE{number=v', movecnt as ref vCnt, ...}) = 
	               case (chase src, chase dst)
                         of (x, y as NODE{color=ref (COLORED _),...}) => (y,x)
                          | (x,y) => (x,y)
            fun coalesceIt() =
	      (status := COALESCED;
	       if !spillFlag then undoInfo := (v, status) :: (!undoInfo)
	       else ())
	  in 
	    if u' = v' then
	      (coalesceIt ();
	       doMoveWkl(rest, addWkl(u, 2, wkl), fzWkl))
	    else 
	     (case v 
	       of NODE{color=ref(COLORED _),  ...} =>
		   (status := CONSTRAINED;
		    doMoveWkl(rest, wkl, fzWkl))
	        | _ =>			(* v is a pseudo register *)
		   if memBitMatrix (v, u) then
		     (status := CONSTRAINED;
		      doMoveWkl(rest, addWkl(v,1,addWkl(u,1,wkl)), fzWkl))
		   else 
		    (case ucol
		      of COLORED _ =>
			 (* coalescing a pseudo and machine register *)
		 	 if safe(u,v) then
			   (coalesceIt();
			    doMoveWkl(combine(v, u, rest, wkl, fzWkl)))
			 else
			   (status := MOVE;
			    doMoveWkl(rest, wkl, fzWkl))
		      | _ => 
			 (* coalescing pseudo and pseudo register *)
		         if conservative(u, v) then let
			     val (mvWkl, wkl, fzWkl) = 
			           combine(v, u, rest, wkl, fzWkl)
			   in
			     coalesceIt();
			     doMoveWkl(mvWkl, addWkl(u, 2-vCnt, wkl), fzWkl)
			   end
			 else 
			   (status := MOVE;
			    doMoveWkl(rest, wkl, fzWkl))
		     (*esac*))
	      (*esac*))
	  end
	| doMoveWkl([], wkl, fzWkl) =
	  (* Note. The wkl is not uniq, because decrementDegree may have
	   * added the same node multiple times. We will let simplify take
	   * care of this.
	   *)
	    WKL{simplifyWkl = wkl, freezeWkl = fzWkl, 
		moveWkl = [], spillWkl = spillWkl, stack = stack}
    in
      doMoveWkl(moveWkl, simplifyWkl, freezeWkl)
    end (* coalesce *)


		    (*-----------freeze------------*)

    (* When a move is frozen in place, the operands of the move may
     * be simplified. One of the operands is node (below).
     *)
    fun wklFromFrozen(NODE{number=node, movelist, movecnt, ...}) = let
      fun mkWkl(MV{status, src, dst, ...}) = let
	val s = chase src and  d = chase dst
	val y = if nodeNumber s = node then d else s
      in
	case !status
	of MOVE  => 
	  (status := LOST;
	   case y 
	     of NODE{color=ref(COLORED _), ...} => NONE
	      | NODE{movecnt=ref 1, degree, ...} =>
		 (movecnt := 0;
		  if !degree < K then SOME y
		  else NONE)
	      | NODE{movecnt,...} =>
		  (movecnt := !movecnt - 1; NONE)
	   (*esac*))
	 | WORKLIST => error "wklFromFrozen"
	 | _ => NONE
      end
    in
      movecnt:=0;
      List.mapPartial mkWkl (!movelist)
    end


    (* freeze a move in place 
     * Important: A node in the freezeWkl starts out with a degree < K.
     * However, because of coalescing, it may have its degree increased 
     * to > K; BUT is guaranteed never to be a spill candidate. We do not
     * want to select such nodes for freezing. There has to be some other
     * freeze candidate that will liberate such nodes.
     *)
    fun freeze(WKL{freezeWkl, simplifyWkl, spillWkl, moveWkl, stack}) = let
      fun find([], acc) = (NONE, acc)
	| find((n as NODE{color=ref PSEUDO, degree=ref d, ...})::ns, acc) =
	  if d >= K then find(ns, n::acc) else (SOME n, acc@ns)
	| find(_::ns, acc) = find(ns, acc)

      fun mkWorkLists(NONE, fzWkl) = 
	   WKL{freezeWkl=fzWkl, simplifyWkl=simplifyWkl, 
	       spillWkl=spillWkl, moveWkl=moveWkl, stack=stack}
	| mkWorkLists(SOME n, fzWkl) = 
	    WKL{freezeWkl=fzWkl, simplifyWkl=n::wklFromFrozen n,
		spillWkl=spillWkl, moveWkl=moveWkl, stack=stack}
    in
      mkWorkLists(find(freezeWkl,[]))
    end

	    (*----------select spill node--------------*)
   (* remainInfo: blocks where spill nodes are defined and used. *)
    type info  = int list Intmap.intmap
    val remainInfo : (info * info) option ref	= ref NONE

    fun cleanupSpillInfo() = remainInfo := NONE

    fun selectSpillNode(
	   WKL{simplifyWkl, spillWkl, stack, moveWkl, freezeWkl}) = let

      (* duCount: compute the def/use points of spilled nodes. *)
      fun duCount spillable = let
	val size = length spillable
	exception Info
	val defInfo : info = Intmap.new(size,Info)
	val useInfo : info = Intmap.new(size,Info)
	val addDef = Intmap.add defInfo 
	val addUse = Intmap.add useInfo
	fun getDefs n = (Intmap.map defInfo n) handle _ => []
	fun getUses n = (Intmap.map useInfo n) handle _ => []

	(* doblocks --- updates the defInfo and useInfo tables to indicate
	 *   the blocks where spillable live ranges are defined and used.
	 *)
	fun doblocks ~1 = ()
	  | doblocks blknum = let
	      val bdu = Array.sub(blockDU,blknum)
	      fun iter [] = ()
		| iter((def',use')::rest) = let
		    val def = uniqMap(nodeNumber o chase, def')
		    val use = uniqMap(nodeNumber o chase, use')
		    val d = SL.intersect(def,spillable)
		    val u = SL.intersect(use,spillable)
		  in
		    case (d,u)
		     of ([],[]) => ()
		      | _ => let
			  fun updateDef n =
				addDef(n, blknum::getDefs n)
			  fun updateUse n =
				addUse(n, blknum::getUses n)
			in app updateDef d; app updateUse u
			end
		    (*esac*);
		    iter rest
		  end
	    in
	      iter(bdu);
	      doblocks(blknum-1)
	    end

	(* If a node is live going out of an block terminated by 
	 * an escaping branch, it may be necessary to reload the
	 * the node just prior to taking the branch. We will therefore
	 * record this as a definition of the node.
	 *)
	fun doBBlocks n = let
	  val F.BBLOCK{blknum,liveIn,liveOut,succ,...} = Array.sub(cblocks,n)
	  val rNum = nodeNumber o chase o getnode
	  val liveout = uniqMap (rNum, rmvDedicated(RaArch.regSet(!liveOut)))
	in
	  case !succ
	  of [F.EXIT _] => 
	      (case SL.intersect(spillable,liveout) 
	       of [] => doBBlocks(n+1)
		| some =>
		   (app (fn n => addDef(n, blknum::getDefs n)) some;
		    doBBlocks (n+1))
	       (*esac*))
	   | _ => doBBlocks(n+1)
	 (*esac*)
	end (* doBBlocks *) 
      in
	doblocks (numOfBlocks - 1);
	doBBlocks 0 handle _ => ();
	(defInfo,useInfo)
      end (* duCount *)

      (* Since the spillWkl is not actively maintained, the set of
       * spillable nodes for which def/use info is needed is a subset
       * of spillWkl.
       *)
      fun remainingNodes() = let
	fun prune [] = []
	  | prune((n as NODE{color=ref PSEUDO, ...}) ::ns) =  
	      n::prune ns
	  | prune((n as NODE{color=ref(ALIASED _), ...})::ns) = 
	      prune(chase n::ns)
	  | prune(_::ns) = prune ns
      in
	case !remainInfo 
	 of SOME info => prune spillWkl
	  | NONE => let
	       (* first time spilling *)
	       val spillable = prune ( spillWkl)
	    in 
	      remainInfo := 
		 (case spillable 
		   of [] => NONE
		    | _ => SOME(duCount(SL.uniq(map nodeNumber spillable)))
		  (*esac*));
	      spillable
	    end
      end

     (** apply the chaitan hueristic to find the spill node **)
      fun chaitanHueristic(spillable) = let
	    val infinity = 1000000.0
	    val infinityi= 1000000
	    val SOME(dinfo,uinfo) = !remainInfo
	    val getdInfo = Intmap.map dinfo
	    val getuInfo = Intmap.map uinfo
	    fun coreDump [] = ()
	      | coreDump ((node as NODE{number, degree, adj, ...})::rest) = 
		  (print(concat
		      ["number =", Int.toString number,
		       " node =", Int.toString(nodeNumber (chase node)),
		       " degree = ", Int.toString (!degree),
		       " adj = "]);
		   prList(map (nodeNumber o chase) (!adj), "");
		   print "\n";
		   coreDump rest)
	    fun iter([],node,_) = 
		  if node <> ~1 then getnode node 
		  else (coreDump spillable; error "chaitanHueristic.iter")
	      | iter((node as NODE{number, degree, ...})::rest,cnode,cmin) = let
		 (* An exeception will be raised if the node is defined
		  * but not used. This is not a suitable node to spill.
		  *)
		  val cost = ((length(getdInfo number) +
			     (length(getuInfo number) handle _ => infinityi)))
		  val hueristic = real cost / real (!degree)
		in
		  if hueristic < cmin andalso not(SL.member prevSpills number)
		  then iter(rest, number, hueristic)
		  else iter(rest, cnode, cmin)
		end
	  in iter(spillable, ~1, infinity)
          end
    in
     case mode
     of COPY_PROPAGATION =>
         WKL{spillWkl=[], simplifyWkl=[], stack=[], moveWkl=[], freezeWkl=[]}
      | REGISTER_ALLOCATION => 
	(case remainingNodes() 
	 of [] =>
	     WKL{spillWkl=[], simplifyWkl=simplifyWkl, 
		 stack=stack, moveWkl=moveWkl, freezeWkl=freezeWkl}
	  | spillWkl => let
	      val spillNode = chaitanHueristic(spillWkl)
	      val simpWkl = 
		if isMoveRelated spillNode then spillNode::wklFromFrozen(spillNode)
		else [spillNode]
	    in
	      spillFlag:=true;
	      WKL{simplifyWkl=simpWkl,
		  spillWkl = spillWkl,
		  freezeWkl = freezeWkl,
		  stack = stack,
		  moveWkl = moveWkl}
	    end
	(*esac*))

    end (* selectSpillNode *)


	       (*---------rerun algorithm-------------*)

   (** rerun(spillList) - an unsuccessful round of coloring as taken
    **   place with nodes in spillList having been spilled. The
    **   flowgraph must be updated and the entire process repeated. 
    **)
    fun rerun spillList = let
      val SOME(dInfo,uInfo) = !remainInfo

      fun coalesceSpillLoc () = let
	fun grow([], set, remain) = (set, remain)
	  | grow(x::xs, set, remain) = let
	     fun test(s::rest) = memBitMatrix(x, s) orelse test rest
	       | test [] = false
	    in 
	      if test set then grow(xs, set, x::remain) 
	      else grow(xs, x::set, remain)
	    end
	fun loop([]) = []
	  | loop(x::xs) = let
	      val (set, remain) = grow(xs, [x], [])
	    in set::loop remain
	    end
      in loop(spillList)
      end

(*
      val _ = 
	 app (fn set => prList(map nodeNumber set, 
			       "coalesced " ^ Int.toString(length set) ^ ": "))
	     (coalesceSpillLoc())
*)

      (* blocks where spill code is required for node n *)
      fun affectedBlocks node = let
	val n = nodeNumber node
      in SL.merge(SL.uniq(Intmap.map dInfo n), 
		  SL.uniq(Intmap.map uInfo n) handle _ => [])
      end

      fun allBlocksAffected () = let
	fun merge([], L) = L
	  | merge(x::xs, L) = merge(xs, SL.enter(x, L))
      in List.foldl merge [] (map affectedBlocks spillList)
      end

      (* Insert spill code into the affected blocks *)
      fun doBlocks([], _, prevSpills) = prevSpills
	| doBlocks(blknum::rest, node, pSpills) = let
	    val F.BBLOCK{insns, liveOut, ...} = Array.sub(cblocks, blknum)
	    val bdu = Array.sub(blockDU, blknum)
	    val liveOut = 
	      map (chase o getnode) (rmvDedicated(RaArch.regSet(!liveOut)))
	      
	    fun newdu instr = let
	      val (d',u') = defUse instr
	      fun rmv [] = []
		| rmv (r::rs) = let
		    val node = 
		      getnode r handle _ => let
			  val n = newNode(r, PSEUDO)
			in Intmap.add nodes (r, n); n
			end
		  in chase node::rmv rs  
		  end
	      fun rmv' set = rmv(rmvDedicated set)
	    in (rmv' d', rmv' u')
	    end (* newdu *)

	    val spillReg = nodeNumber node

	    (* note: the instruction list start out in reverse order. *)
	    fun doInstrs(instr::rest, (du as (d,u))::bDU, newI, newBDU,
			 prevSpills) = 
	      let
		val defs=map chase d
		val uses=map chase u

		fun mergeProh(proh,pSpills) = SL.merge(SL.uniq proh, pSpills)

		fun newReloadCopy(rds, rss) = let
		  fun f(rd::rds, rs::rss, rds', rss') = 
		      if rs = spillReg then(([rd], [rs]), (rds@rds', rss@rss'))
		      else f(rds, rss, rd::rds', rs::rss')
		    | f([], [], _, _) = error "newReloadCopy.f"
		in f(map nodeNumber rds, map nodeNumber rss, [], [])
		end

		(* insert reload code for copies. *)
		fun doReloadCopy(du, instr, newI, newBDU, prevSpills) = 
		  if nodeMember(node, #2 du) then 
		    (case du 
		     of ([d], [u]) => let
			 val {code, proh} = RaUser.reload{instr=instr, reg=spillReg}
			 val prevSpills = mergeProh(proh, prevSpills)
			 val newI = code @ newI
			 val newBDU = (map newdu code) @ newBDU
		       in doInstrs(rest, bDU, newI, newBDU, prevSpills)
		       end
		     | (defs, uses) => let
			 val (mv, cpy) = newReloadCopy(defs, uses)
			 val cpyInstr = RaUser.copyInstr(cpy)
			 val duCpy = newdu cpyInstr
			 val {code, proh} = 
			   RaUser.reload{instr=RaUser.copyInstr(mv), reg=spillReg}
			 val prohibited = mergeProh(proh, prevSpills)
			 val newI = code @ newI
			 val newBDU = (map newdu code) @ newBDU
		       in doReloadCopy(duCpy, cpyInstr, newI, newBDU, prohibited)
		       end
		    (*esac*))
		  else
		    doInstrs(rest, bDU, instr::newI, du::newBDU, prevSpills)


		(* insert reload code *)
		fun reload(du as (d,u), instr, newI, newBDU, prevSpills) = 
		  if P.moveInstr(instr) then 
		    doReloadCopy(du, instr, newI, newBDU, prevSpills)
		  else if nodeMember(node, u) then let
		      val {code, proh} = RaUser.reload{instr=instr, reg=spillReg}
		      val newI = code @ newI
		      val newBDU = map newdu code @ newBDU
		      val prevSpills = mergeProh(proh, prevSpills)
		    in doInstrs(rest, bDU, newI, newBDU, prevSpills)
		    end
	          else
		    doInstrs(rest, bDU, instr::newI, du::newBDU, prevSpills)

		fun newSpillCopy(rds, rss) = let
		  fun f(rd::rds, rs::rss, rds', rss') = 
		      if  rd = spillReg then (([rd], [rs]), (rds@rds', rss@rss'))
		      else f(rds, rss, rd::rds', rs::rss')
		    | f([], [], _, _) = error "newSpillCopy"
                in f(map nodeNumber rds, map nodeNumber rss, [], [])
		end

		fun spillCopy() = 
		  (case (defs, uses) 
		   of ([], []) => 
		       doInstrs(rest, bDU, instr::newI, du::newBDU, prevSpills)
		    | ([d], [u]) => let
		      val {code, instr=NONE, proh} = 
			    RaUser.spill{instr=instr, reg=spillReg}
		      val prevSpills = mergeProh(proh, prevSpills)
		      val newI = code @ newI
		      val newBDU = (map newdu code) @ newBDU
		    in
		      doInstrs(rest, bDU, newI, newBDU, prevSpills)
		    end
		  | _ => let
		      val (mv, cpy) = newSpillCopy(defs, uses)
		      val cpyInstr = RaUser.copyInstr(cpy)
		      val duCpy = newdu cpyInstr
		      val {code, instr=NONE, proh} = 
			    RaUser.spill{instr=RaUser.copyInstr mv, reg=spillReg}
		      val newI = code @ (cpyInstr :: newI)
		      val newBDU = (map newdu code) @ (duCpy :: newBDU)
		      val prevSpills = mergeProh(proh, prevSpills)
		    in
		      doInstrs(rest, bDU, newI, newBDU, prevSpills)
		    end
		 (*esac*))
	      in
		(* insert spill code? *)
		if nodeMember(node, defs) then 
		  if P.moveInstr instr then spillCopy() 
		  else let
		      val {code, instr, proh} = 
			RaUser.spill{instr=instr, reg=spillReg}
		      val prevSpills = mergeProh(proh, prevSpills)
		      val newI = code @ newI
		      val newBDU = map newdu code @ newBDU
		    in
		      case instr 
		      of NONE => doInstrs(rest, bDU, newI, newBDU, prevSpills)
		       | SOME instr => let
                           val du = newdu instr
			 in reload(du, instr, newI, newBDU, prevSpills)
			 end
		    end
		else
		  reload((defs,uses), instr, newI, newBDU, prevSpills)
	      end
	      | doInstrs([], [], newI, newBDU, prevSpills) = 
	          (rev newI, rev newBDU, prevSpills)

	   (* special action if the last instruction is an escaping
	    * branch and the node is live across the branch.
	    * We discover if the node needs to be spilled or reloaded.
	    *)
	    fun blockEnd(instrs as instr::rest, bDU as du::bdu) = let
		  fun escapes [] = false
		    | escapes (P.ESCAPES::_) = true
		    | escapes (_::targets) = escapes targets
		in
		  if nodeMember(node, liveOut) then
		      (case P.instrKind instr
		       of P.IK_JUMP =>
			   if escapes(P.branchTargets instr) then let
			       val {code,...} = 
				 RaUser.reload{instr=instr, reg=spillReg}
			       val reloadDU = map newdu code
			     in
			       (rev code@rest, rev reloadDU@bdu)
			     end
			   else (instrs, bDU)
			| _ => (instrs, bDU)
		      (*esac*))
		  else (instrs, bDU)
		end
	      | blockEnd([],[]) = ([], [])

	    val (newInstrs, newBdu, pSpills) = 
		   doInstrs(!insns, bdu, [], [], pSpills)
	    val (newInstrs, newBdu) = blockEnd(newInstrs, newBdu)
	  in
	    insns := newInstrs;
	    Array.update(blockDU, blknum, newBdu);
	    doBlocks(rest, node, pSpills)
	  end (* doBlocks *)

      (* The optimistic coloring selection may come up with a node
       * that has already been spilled. Must be careful not to spill
       * it twice.
       *)
      fun glue([], prevSpills) = prevSpills
	| glue((node as NODE{number, ...})::rest, prevSpills) =
	   if SL.member prevSpills number then glue(rest, prevSpills)
	   else glue(rest, doBlocks(affectedBlocks node, node, prevSpills))

      (* redoAlgorithm
       *	-- rerun graph coloring but note that spilling may 
       * 	have introduced new registers.
       *)
      fun redoAlgorithm(prevSpills) = let
	val spills = SL.merge(SL.uniq(map nodeNumber spillList), prevSpills)
	fun init(_, NODE{color=ref PSEUDO, degree, adj,  
					   movecnt, movelist, ...}) =
	      (degree:=0; adj := []; movecnt:=0; movelist:=[])
	  | init _ = ()
      in 
	Intmap.app init nodes;
	graphColoring(mode, blocks, cblocks, blockDU, spills, nodes, regmap)
      end
    in
       redoAlgorithm(glue(spillList, prevSpills))
    end (* rerun *)


		    (*-----------select-------------*)
    (* spilling has occurred, and we retain coalesces upto to first
     * potential (chaitin) spill. Any move that was coalesced after 
     * the spillFlag was set, is undone.
     *)
    fun undoCoalesced (NODE{number, color, ...}, status) = 
      (status := MOVE;
       if number < RaArch.firstPseudoR then () else color := PSEUDO)

    (* assigns colors  *)
    fun assignColors(WKL{stack,  ...}) = let 
      (* Briggs's optimistic spilling heuristic *)
      fun optimistic([], spills) = spills
	| optimistic((node as NODE{color, adj, ...}) ::ns, spills) = let
	    fun neighbors [] = []
	      | neighbors(r::rs) = 
	        (case chase r
		  of NODE{color=ref (COLORED col), number, ...} => 
		       col::neighbors rs
		   | _ => neighbors rs
		 (*esac*))
	    val neighs = neighbors(!adj)
	    fun getcolor () = RaUser.getreg{pref=[], proh=neighbors(!adj)}
	  in
	    let val col = getcolor()
	    in
	      color := COLORED col;
	      optimistic(ns, spills)
	    end
	      handle _ => (optimistic(ns, node::spills))
          end

      fun finishRA () = let
	val enter = Intmap.add regmap
      in
	Intmap.app 
	  (fn (i, node) =>
	     case chase node
	     of NODE{color=ref(COLORED col), ...} => enter(i,col)
	      | _ => error "finishRA"
	     (*esac*))
	  nodes
      end

      fun finishCP() = let
	val enter = Intmap.add regmap
      in
	Intmap.app
	  (fn (i, node as NODE{color as ref (ALIASED _), ...}) => 
	        (case (chase node)
		 of NODE{color=ref(COLORED col), ...} => enter(i, col)
	          | NODE{color=ref PSEUDO, number, ...} => enter(i, number)
		  | NODE{color=ref REMOVED, number, ...} => enter(i,number)
		  | _ => error "finishP"
		 (*esac*))
            | _ => ())
          nodes
      end
    in
      case mode
      of COPY_PROPAGATION => finishCP()
       | REGISTER_ALLOCATION => 
	 (case optimistic(stack, [])
	  of [] => finishRA()		
	   | spills  =>			
	       (app (fn NODE{color, ...} => color := PSEUDO) stack;
		app undoCoalesced (!undoInfo);
		rerun spills) 
	 (*esac*))
    end (* assignColors *)


		    (*---------main------------*)
    (* iterate (WKL{count,simplifyWkl,freezeWkl,spillWkl,moveWkl,stack})
     * Note: freezeWkl or spillWkl are maintained lazily.
     *)
    fun iterate(wkls as WKL{simplifyWkl= _::_, ...}) = iterate(simplify wkls)
      | iterate(wkls as WKL{moveWkl= _::_, ...}) = iterate(coalesce wkls)
      | iterate(wkls as WKL{freezeWkl= _::_, ...}) = iterate(freeze wkls)
      | iterate(wkls as WKL{spillWkl= _::_, ...}) = iterate(selectSpillNode wkls)
      | iterate wkls = assignColors wkls
  in
    iterate (WKL initialWkls)
  end (* graphColoring *)

  fun ra mode (cluster as (F.CLUSTER{blocks, regmap, ...})) = 
    if RaArch.numRegs() = 0 then cluster
    else let 
	exception Nodes
	val nodes : node Intmap.intmap = Intmap.new(32, Nodes)
	fun mkNode i = 
	  newNode(i, if i < RaArch.firstPseudoR then COLORED(i) else PSEUDO)

	val nCBlks = 
	  List.foldl
	    (fn (F.BBLOCK _, acc) => acc+1 | (_, acc) => acc) 0 blocks
	val blockDU = Array.array(nCBlks, ([]: (node list * node list) list))
	val cblocks = Array.array(nCBlks, F.LABEL(Label.newLabel""))

       fun getnode n = 
	  Intmap.map nodes n 
	    handle Nodes => 
              let val node = mkNode n
	      in Intmap.add nodes (n, node); 
                 node
	      end

	fun blockDefUse((blk as F.BBLOCK{insns,liveOut,succ, ...})::blks, 
								   n) = let
	      fun insnDefUse insn = let 
		val (d,u) = defUse insn
		fun rmv [] = []
		  | rmv (l as [x]) = 
		      if isDedicated x then [] else [getnode x]
		  | rmv set = map getnode (rmvDedicated set)
	      in (rmv d, rmv u)
	      end
	    in
	      Unsafe.Array.update(cblocks, n, blk);
	      Unsafe.Array.update(blockDU, n, map insnDefUse (!insns));
              case !succ
              of [F.EXIT _] => 
		 app (fn i => (getnode i; ()))
		     (rmvDedicated(RaArch.regSet(!liveOut)))
               | _  => ();
	      blockDefUse(blks, n+1)
            end
	  | blockDefUse(_::blks, n) = blockDefUse(blks, n)
	  | blockDefUse([], _) = ()

	(* if copy propagation was done prior to register allocation
	 * then some nodes may already be aliased. 
	 *)
	fun updtAliases() = let
	  val alias = Intmap.map regmap  
	  fun fixup(num, NODE{color, ...}) = 
	    if num < RaArch.firstPseudoR then () 
	    else let
	        val reg = alias num
	      in if reg=num then () else color := ALIASED(getnode reg)
	      end  handle _ => ()
	in Intmap.app fixup nodes
	end
      in
	blockDefUse(blocks, 0);
	updtAliases(); 
	graphColoring(mode, blocks, cblocks, blockDU, [], nodes, regmap);
	debug("after register allocation", blocks, regmap);
	cluster
      end 
end (* functor *)



(*
 * $Log: ra.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:35  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.17  1997/09/29 20:58:41  george
 *   Escaping blocks are now characterised by succ pointing to the EXIT block
 *
# Revision 1.16  1997/09/17  17:15:07  george
#   successor and predessor lists are now basic block lists instead of int lists
#
# Revision 1.15  1997/09/12  10:13:00  george
#   fixed sutble bug with graph construction and parallel moves
#
# Revision 1.14  1997/09/04  15:19:51  george
#   Made the hash table size for the bitmatrix approximately equal to the
#   number of edges assuming E/N is approx K.
#
# Revision 1.13  1997/07/20  17:31:38  george
#   bug fixes involving uses of SortedList
#
# Revision 1.12  1997/07/19  13:23:32  george
#   Fixed a bug in which nodes are not created if a register is live
#   coming into the cluster and live on exit, but never used.
#
# Revision 1.11  1997/07/18  00:30:20  george
#   fixed bug in copy propagation
#
# Revision 1.10  1997/07/17  18:06:34  george
#   fixed bug in writing out regmap during copy propagation
#
# Revision 1.9  1997/07/17  12:32:17  george
#   I no longer assume that the pseudo registers are going to form a
#   dense enumeration. Removed all uses of arrays and replaced them
#   with integer maps. This turns out to be somewhat convenient when
#   new registers are generated during spilling.
#
# Revision 1.8  1997/07/15  15:45:42  dbm
#   Change in where structure syntax.
#
# Revision 1.7  1997/07/02  13:23:57  george
#   Implemented a mode in which just copy propagation without register
#   allocation is done. The copy-propagation continues until the first
#   pessimistic spill is encountered.
#
# Revision 1.6  1997/06/30  19:35:51  jhr
#   Removed System structure; added Unsafe structure.
#
# Revision 1.5  1997/06/10  13:52:06  george
#   Fixed a bug in spilling of parallel copy instructions
#
# Revision 1.4  1997/05/22  03:26:05  dbm
#   Added comment.  Can't use "where structure" yet because of bug 1205.
#
# Revision 1.3  1997/05/20  12:09:29  dbm
#   SML '97 sharing, where structure.
#
# Revision 1.2  1997/04/19  18:51:09  george
#   Version 109.27
#
# Revision 1.1.1.1  1997/04/19  18:14:21  george
#   Version 109.27
#
 *)
