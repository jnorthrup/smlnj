(* decisiontree.sml *)
(* construction of a decision tree *)

(* decision tree construction (possibly a separate module)*)

(* the decision tree is simply a structure ordering OR nodes according to the combination
 * of the "best" (APQ.compare) ordering and the path suffix relation.
 *  -- OR nodes can have multiple occurrences in the decision tree (being duplicated in multiple
 *     branches under an earlier choice node.
 *  -- Note that the idea is to refer to the OR nodes from the original andor tree
 *     rather than creating new, redundant representations of these choices. *)

structure DecisionTree =
struct

local
    structure R = Rules  (* sets of rule numbers *)
    structure T = Types
    structure TU = TypesUtil
    structure L = Layers
    structure LS = Layers.Set
    structure Q = ORQueues
    structure APQ = Q.APQ
    open MCTypes
in

(* need to recover and traverse AND structure for selecting values to test. Can
 * recover from the original andor tree? *)

(* Terminology: a _trace_ is a list of andor paths recording the decision
 * points in a complete/maximal branch of a decision tree. Traces are needed
 * for (1) determining "scoping" of multiple versions of a variable produced by
 * OR patterns, and (2) as a source for producing match counterexamples for 
 * decision tree branches terminating with DMATCH. *)

val numberChars = 256  (* this should be a basic configuration parameter in Target? *)

(* NEED: typeVariants function *)

(* partial : andor -> bool *)
(* should this check for defaults? i.e. presence of a variable covering the node
 * and providing a default for missing keys? *)
fun partial (OR{info={typ,...}, variants, ...}) =
    let val numVariants = Variants.numItems variants
	val numTypeVariants = TU.typeVariants typ  (* "width" of the type of the OR node *)
     in numVariants < numTypeVariants
    end
(*    (case key
       of D (dcon,_) => length variants < TU.dataconWidth dcon  (* missing constructor keys *)
        | C _ => length variants < numberChars
        | _ => true)
*)
  | partial _ =  bug "partial"

(* decistionTree: andor -> decTree * int Vector.vector *)
(* translates an andor tree into a decision tree and also returns a vector of use counts for
 * the rules.  If uses(r) > 1 then the rhs of rule r needs to be abstracted for reuse.
 * If uses(r) = 0, then rule r is redundant, i.e. the match has redundant rules. *)
fun decisionTree (andor, numRules) =
let val initialLayers = getLive andor
          (* this should be normally be all rule-layers, developed by makeAndor *)
    val ruleCounts = Array.tabulate (numRules, (fn i => 0))
    fun incrementRuleCount r =
	Array.update(ruleCounts, r, Array.sub(ruleCounts,r) + 1)
    val initialOrNodes = Q.accessible andor

    (* makeDecisionTree : APQ.queue * LS.set * trace -> decTree *)
    (* orNodes is a priority queue (APQ.queue) of OR nodes
     * -- oldlive is a ruleset containing rules that are live on this branch,
     *    i.e. have survived earlier decisions on this branch
     * -- oldPath is the path of the parent decision, which is the path of its OR node,
     *    candidate OR nodes must be compatible with this path
     * -- variantDecTrees processes each variant of the selected OR node.
     * -- keys all have type choiceKey, making it easier to iterate over variants
     * -- if survivors is empty, returns RAISEMATCH.
     * CLAIM: The orNodes queue argument will always be internally compatible. *)
    fun makeDecisionTree(orNodes: APQ.queue, survivors: LS.set, dtrace) =
	(case LS.minItem survivors
	  of NONE => DMATCH (rev dtrace)  (* no relevent OR tests at this point *)
	   | SOME minSurvivor => 
	     (case Q.selectBestRelevant(orNodes, minSurvivor)
	       of SOME (node as OR{info = {path,...}, live, variants, ...},
			candidates) =>
		  (* best relevant OR node, remainder is queue of remaining OR nodes *)
		  let (* val _ =
			 (print "makeDecisionTree: \n";
			  print "  thisPath: "; MCPrint.tppPath thisPath;
			  print "  survivors: "; MCPrint.tppRules survivors;
			  print "  path: "; MCPrint.tppPath path) *)
		      (* andorToDecTrees: andor -> decisionTree
		       * the andor of each variant is a child of the parent OR node *)
		      fun andorToDecTree andor =
			  let val variantPath = getPath andor
			      val variantLive = getLive andor
			      val variantSurvivors = LS.intersect(variantLive, survivors)
			      val variantCandidates = APQ.merge(candidates, Q.accessible andor)
				   (* add newly accessible OR nodes only under this variant,
				    * OR nodes under other variants will be incompatible *)
			   in makeDecisionTree(variantCandidates, variantSurvivors,
					       variantPath::dtrace)
			  end
		      val decvariants = Variants.map andorToDecTree variants
		      val defaultOp =
			  if partial node
			  then let val defaultSurvivors = LS.intersect(survivors, live)
			       in (* if LS.isEmpty defaultSurvivors
				     then (print "Default: no survivors\n";
					   print "survivors: "; MCPrint.tppLayers survivors;
					   print "live: "; MCPrint.tppLayers live)
				     else (); *)
				  SOME(makeDecisionTree(candidates, defaultSurvivors, path::dtrace))
				  (* BUG? path added to dtrace does not reflect default _choice_.
				   * Could this cause wrong svar choice in MCCode.genRHS? *)
			       end
			  else NONE  (* no default clause *)
		      in CHOICE{node = node, choices = decvariants, default = defaultOp}
		  end

		| NONE =>
		  (* no relevant OR nodes; pick minimum rule *)
		    (incrementRuleCount (L.toRule minSurvivor);
		     DLEAF (minSurvivor, rev dtrace))

		| _ => bug "makeDecisionTree"))
	    (* end makeDecisionTree *)

    (* What to do when there are no relevant OR nodes in the queue? In this case,
     * the match will be degenerate (only one irrefutable pattern, in rule 0)? 
     * In this case, return DLEAF 0, which code will translate to rhs0 
     * (the right-hand-side of rule 0), prefaced with required pattern destruction 
     * code. *)

 in (makeDecisionTree(initialOrNodes, initialLayers, nil), Array.vector ruleCounts)
end  (* function decistionTree *)

end (* local *)
end (* structure DecisionTree *)
