(* binsort.sml *)

structure BinSort = struct

datatype 'a tree = NIL
		 | NODE of	
		    {left : 'a tree ref,
		     right : 'a tree ref,
		     value : 'a ref}

fun mkSortTree (): '1a tree ref = ref NIL

fun insert (op > : '2a * '2a -> bool, tree: '2a tree ref) (v: '2a) : unit =
    let fun insert'(tr: '2a tree ref) =
	    case !tr  
	      of NIL =>
		   tr := NODE{left=ref NIL, right=ref NIL, value=ref v}
	       | NODE{left, right, value} =>
		   if !value > v
		     then insert'(left)
		   else if v > !value
		     then insert'(right)
		   else (* v = value *) value := v
     in insert'(tree)
    end

exception Finished

fun generator (tree: 'a tree ref) : unit -> 'a =
    let val ptr = tree
	fun leftmost () =
	    case !ptr
	      of NIL => raise Finished
	       | NODE{left=ref NIL,right,value} => (ptr := !right; !value)
	       | NODE{left=(lref as ref(ltr as NODE{right=lr,...})),...} =>
		   (lref := !lr; lr := !ptr; ptr := ltr; leftmost())
     in leftmost
    end

end (* BinSort *)
