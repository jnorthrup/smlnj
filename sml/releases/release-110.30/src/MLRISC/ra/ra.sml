(*
 * This is the new register allocator based on
 * the 'iterated register coalescing' scheme described 
 * in POPL'96, and TOPLAS v18 #3, pp 325-353. 
 *
 * Now with numerous extensions:
 *
 *   0. Dead copy elimination (optional)
 *   1. Priority based coalescing
 *   2. Priority based freezing
 *   3. Priority based spilling
 *   4. Biased selection (optional)
 *   5. Spill Coalescing (optional)
 *   6. Spill Propagation (optional)
 *   7. Spill Coloring (optional)
 *
 * For details, please see the paper from
 *
 *    http://cm.bell-labs.com/cm/cs/what/smlnj/compiler-notes/index.html
 *
 * The basic structure of this register allocator is as follows:
 *   1.  RAGraph.  This module enscapsulates the interference graph 
 *       datatype (adjacency list + interference graph + node table)
 *       and contains nothing architecture specific.
 *   2.  RACore.  This module implements the main part of the iterated
 *       coalescing algorithm, with frequency enhancements.
 *   3.  RA_FLOWGRAPH.  This register allocator is parameterized
 *       with respect to this signature.  This basically abstracts out
 *       the representation of the program flowgraph, and provide
 *       a few services to the main allocator, such as building the 
 *       interference graph, rewriting the flowgraph after spilling,
 *       and rebuilding the interference graph after spilling.  
 *       This module is responsible for caching any information necessary 
 *       to make spilling fast.
 *   4.  This functor.  This functor drives the entire process.
 *
 * -- Allen Leung (leunga@cs.nyu.edu)
 *)

functor RegisterAllocator
   (SpillHeuristics : RA_SPILL_HEURISTICS) 
   (Flowgraph : RA_FLOWGRAPH) : RA =
struct

   structure F      = Flowgraph
   structure I      = F.I
   structure C      = I.C
   structure Core   = RACore
   structure G      = Core.G

   type getreg = { pref  : C.cell list,
                   stamp : int,
                   proh  : int Array.array
                 } -> C.cell

   type mode = word

   type raClient =
   { cellkind     : C.cellkind,             (* kind of register *)
     spillProh    : (C.cell * C.cell) list, (* don't spill these *)
     memRegs      : (C.cell * C.cell) list, (* memory registers *)
     K            : int,                    (* number of colors *)
     dedicated    : bool Array.array,       (* dedicated registers *)
     getreg       : getreg,                 (* how to find a color *)
     copyInstr    : F.Spill.copyInstr,      (* how to make a copy *)
     spill        : F.Spill.spill,          (* spill callback *)
     spillSrc     : F.Spill.spillSrc,       (* spill callback *)
     spillCopyTmp : F.Spill.spillCopyTmp,   (* spill callback *)
     reload       : F.Spill.reload,         (* reload callback *)
     reloadDst    : F.Spill.reloadDst,      (* reload callback *)
     renameSrc    : F.Spill.renameSrc,      (* rename callback *)
     mode         : mode                    (* mode *)
   } 

   val debug = false

   val NO_OPTIMIZATION        = 0wx0
   val DEAD_COPY_ELIM         = Core.DEAD_COPY_ELIM
   val BIASED_SELECTION       = Core.BIASED_SELECTION
   val HAS_PARALLEL_COPIES    = Core.HAS_PARALLEL_COPIES
   val SPILL_COALESCING       = 0wx100
   val SPILL_COLORING         = 0wx200
   val SPILL_PROPAGATION      = 0wx400
   val COPY_PROPAGATION       = 0wx800

   fun isOn(flag, mask) = Word.andb(flag,mask) <> 0w0

   open G

   fun error msg = MLRiscErrorMsg.error("RegisterAllocator",msg)

   (*
    * Debugging flags + counters
    *)
   val cfg_before_ra     = MLRiscControl.getFlag "dump-cfg-before-ra"
   val cfg_after_ra      = MLRiscControl.getFlag "dump-cfg-after-ra"
   val cfg_after_spill   = MLRiscControl.getFlag "dump-cfg-after-spilling"
   val cfg_before_ras    = MLRiscControl.getFlag "dump-cfg-before-all-ra"
   val cfg_after_ras     = MLRiscControl.getFlag "dump-cfg-after-all-ra"
   val dump_graph        = MLRiscControl.getFlag "dump-interference-graph"
   val debug_spill       = MLRiscControl.getFlag "ra-debug-spilling"
   val ra_count          = MLRiscControl.getCounter "ra-count"
   val rebuild_count     = MLRiscControl.getCounter "ra-rebuild"

(*
   val count_dead        = MLRiscControl.getFlag "ra-count-dead-code"
   val dead              = MLRiscControl.getCounter "ra-dead-code"
 *)
   val debug_stream      = MLRiscControl.debug_stream

   (*
    * Optimization flags
    *)
(*
   val rematerialization = MLRiscControl.getFlag "ra-rematerialization"
 *)

   exception NodeTable

   (* This array is used for getreg.
    * We allocate it once. 
    *) 
   val proh = Array.array(C.firstPseudo, ~1)

   (*
    * Register allocator.  
    *    spillProh is a list of registers that are not candidates for spills.
    *)
   fun ra params flowgraph =
   let 
       (* Flowgraph methods *)
       val {build=buildMethod, spill=spillMethod, ...} = F.services flowgraph 

       (* global spill location counter *)
       (* Note: spillLoc cannot be zero as negative locations are
        * returned to the client to indicate spill locations.
	*)
       val spillLoc=ref 1

       (* How to dump the flowgraph *)
       fun dumpFlowgraph(flag, title) =
           if !flag then F.dumpFlowgraph(title, flowgraph,!debug_stream) else ()

       (* Main function *)
       fun regalloc{getreg, K, dedicated, copyInstr,
                    spill, spillSrc, spillCopyTmp, renameSrc,
                    reload, reloadDst, spillProh, cellkind, mode, 
                    memRegs} =
       let val numCell = C.numCell cellkind () 
       in  if numCell = 0
       then ()
       else
       let (* extract the regmap and blocks from the flowgraph *)
           val regmap = F.regmap flowgraph (* the register map *)
    
           (* the nodes table *)
           val nodes  = Intmap.new(numCell,NodeTable) 
           val mode   = if isOn(HAS_PARALLEL_COPIES, mode) then
                           Word.orb(Core.SAVE_COPY_TEMPS, mode) 
                        else mode
           (* create an empty interference graph *)
           val G      = G.newGraph{nodes=nodes, 
                                   K=K,
                                   dedicated=dedicated,
                                   numRegs=numCell,
                                   maxRegs=C.maxCell,
                                   regmap=regmap,
                                   showReg=C.toString cellkind,
                                   getreg=getreg,
                                   getpair=fn _ => error "getpair",
                                   firstPseudoR=C.firstPseudo,
                                   proh=proh,
                                   mode=Word.orb(Flowgraph.mode,
                                         Word.orb(mode,SpillHeuristics.mode)),
                                   spillLoc=spillLoc,
                                   memRegs=memRegs
                                  }
           val G.GRAPH{spilledRegs, pseudoCount, spillFlag, ...} = G
    
           val hasBeenSpilled = Intmap.mapWithDefault (spilledRegs,false)
    
           fun logGraph(header,G) = 
               if !dump_graph then
                   (TextIO.output(!debug_stream,
                        "-------------"^header^"-----------\n");
                    Core.dumpGraph G (!debug_stream) 
                   )
               else ()
    
           (*
            * Build the interference graph 
            *) 
           fun buildGraph(G) = 
           let val _ = if debug then print "build..." else ()
               val moves = buildMethod(G,cellkind)
               val worklists = 
                   (Core.initWorkLists G) {moves=moves} 
           in  (* if !count_dead then
                  Intmap.app (fn (_,NODE{uses=ref [],...}) => dead := !dead + 1
                               | _ => ()) nodes
               else (); *)
               logGraph("build",G);
               if debug then
               let val G.GRAPH{bitMatrix=ref(G.BM{elems, ...}), ...} = G
               in  print ("done: nodes="^Int.toString(Intmap.elems nodes)^ 
                          " edges="^Int.toString(!elems)^
                          " moves="^Int.toString(length moves)^
                          "\n")
               end else (); 
               worklists
           end
    
           (*
            * Potential spill phase
            *) 
           fun chooseVictim{spillWkl} =
           let fun dumpSpillCandidates(spillWkl) =
                   (print "Spill candidates:\n";
                    app (fn n => print(Core.show G n^" ")) spillWkl;
                    print "\n"
                   )
               (* Initialize if it is the first time we spill *)
               val _ = if !spillFlag then () else SpillHeuristics.init()
               (* Choose a node *)
               val {node,cost,spillWkl} =
                   SpillHeuristics.chooseSpillNode
                       {graph=G, hasBeenSpilled=hasBeenSpilled,
                        spillWkl=spillWkl}
                    handle SpillHeuristics.NoCandidate =>
                      (Core.dumpGraph G (!debug_stream);
                       dumpSpillCandidates(spillWkl);
                       error ("chooseVictim")
                      )
           in  if !debug_spill then
                  (case node of
                     NONE => ()
                   | SOME(best as NODE{defs,uses,...}) =>
                        print("Spilling node "^Core.show G best^
                              " cost="^Real.toString cost^
                              " defs="^Int.toString(length(!defs))^
                              " uses="^Int.toString(length(!uses))^"\n"
                             )
                  ) else ();
               {node=node,cost=cost,spillWkl=spillWkl}
           end 
              
           (*
            * Mark spill nodes
            *)
           fun markSpillNodes nodesToSpill =
           let val marker = SPILLED
               fun loop [] = ()
                 | loop(NODE{color, ...}::ns) = (color := marker; loop ns)
           in  loop nodesToSpill end

           (* Mark nodes that are immediately aliased to mem regs;
            * These are nodes that need also to be spilled
            *)
           fun markMemRegs [] = ()
             | markMemRegs(NODE{number=r, color as ref(ALIASED
                          (NODE{color=ref(col as MEMREG _), ...})), ...}::ns) =
                (color := col;
                 markMemRegs ns)
             | markMemRegs(_::ns) = markMemRegs ns
      
           (*
            * Actual spill phase.  
            *   Insert spill node and incrementally 
            *   update the interference graph. 
            *)
           fun actualSpills{spills} = 
           let val _ = if debug then print "spill..." else (); 
               val _ = if isOn(mode, 
                               SPILL_COALESCING+
                               SPILL_PROPAGATION+
                               SPILL_COLORING) then
                           markSpillNodes spills
                       else ()
               val _ = if isOn(mode,SPILL_PROPAGATION+SPILL_COALESCING) then   
                          Core.initMemMoves G 
                       else ()
               val _ = logGraph("actual spill",G);
               val {simplifyWkl,freezeWkl,moveWkl,spillWkl} =  
                    Core.initWorkLists G
                       {moves=spillMethod{graph=G, cellkind=cellkind,
                                          spill=spill, spillSrc=spillSrc,
                                          spillCopyTmp=spillCopyTmp,
                                          renameSrc=renameSrc,
                                          reload=reload, reloadDst=reloadDst,
                                          copyInstr=copyInstr, nodes=spills
                                         }
                       }
               val _ = dumpFlowgraph(cfg_after_spill,"after spilling")
           in  logGraph("rebuild",G);
               if debug then print "done\n" else ();
               rebuild_count := !rebuild_count + 1;
               (simplifyWkl, moveWkl, freezeWkl, spillWkl, [])
           end
           
           (*
            * Main loop of the algorithm
            *)
           fun main(G) =
           let 
                   
               (* Main loop *) 
               fun loop(simplifyWkl,moveWkl,freezeWkl,spillWkl,stack) =
               let val iteratedCoal = Core.iteratedCoalescing G
                   val potentialSpill = Core.potentialSpillNode G
                   (* simplify/coalesce/freeze/potential spill phases 
                    *    simplifyWkl -- non-move related nodes with low degree 
                    *    moveWkl     -- moves to be considered for coalescing
                    *    freezeWkl   -- move related nodes (with low degree)
                    *    spillWkl    -- potential spill nodes
                    *    stack       -- simplified nodes
                    *)
                   fun iterate(simplifyWkl,moveWkl,freezeWkl,spillWkl,stack) =
                   let (* perform iterated coalescing *)
                       val {stack} = iteratedCoal{simplifyWkl=simplifyWkl,
                                                  moveWkl=moveWkl,
                                                  freezeWkl=freezeWkl,
                                                  stack=stack}
                   in  case spillWkl of
                         [] => stack (* nothing to spill *)
                       |  _ => 
                         if !pseudoCount = 0 (* all nodes simplified *)
                         then stack 
                         else
                         let val {node,cost,spillWkl} = 
                                    chooseVictim{spillWkl=spillWkl}
                         in  case node of  
                               SOME node => (* spill node and continue *)
                               let val _ = if debug then print "-" else () 
                                   val {moveWkl,freezeWkl,stack} = 
                                       potentialSpill{node=node,
                                                      cost=cost,
                                                      stack=stack}
                               in  iterate([],moveWkl,freezeWkl,spillWkl,stack)
                               end 
                             | NONE => stack (* nothing to spill *)
                         end
                   end

                   val {spills} = 
                       if K = 0 then
                         {spills=spillWkl}
                       else 
                         let (* simplify the nodes *)
                             val stack = iterate
                                (simplifyWkl,moveWkl,freezeWkl,spillWkl,stack)
                             (* color the nodes *)
                         in  (Core.select G) {stack=stack} 
                         end
               in  (* check for actual spills *)
                   case spills of
                     [] => ()
                   | spills => 
                     (if isOn(mode,COPY_PROPAGATION) then ()
                      else loop(actualSpills{spills=spills})
                     )
               end
    
               val {simplifyWkl, moveWkl, freezeWkl, spillWkl} = buildGraph G
    
           in  loop(simplifyWkl, moveWkl, freezeWkl, spillWkl, [])
           end
    
           fun initSpillProh(from,to) = 
           let val markAsSpilled = Intmap.add spilledRegs
               fun loop r = 
                   if r <= to then (markAsSpilled(r,true); loop(r+1)) else ()
           in  loop from end
    
       in  dumpFlowgraph(cfg_before_ra,"before register allocation");
           app initSpillProh spillProh;
           main(G); (* main loop *)
           (* update the regmap *)
           logGraph("done",G);
           if isOn(mode,COPY_PROPAGATION) 
           then Core.finishCP G 
           else Core.finishRA G
           ;
           ra_count := !ra_count + 1;
           dumpFlowgraph(cfg_after_ra,"after register allocation");
           (* Clean up spilling *)
           SpillHeuristics.init() 
       end
       end

       fun regallocs [] = ()
         | regallocs(p::ps) = (regalloc p; regallocs ps)

   in  dumpFlowgraph(cfg_before_ras,"before register allocation");
       regallocs params;
       dumpFlowgraph(cfg_after_ras,"after register allocation");
       flowgraph
   end

end
