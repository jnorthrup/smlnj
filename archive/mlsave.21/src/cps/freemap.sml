signature FREEMAP =
  sig
    val freetimer : System.Timer.time ref (* temporary, for debugging *)
    val freemap : ((CPS.lvar * CPS.lvar list) -> unit)
			-> (CPS.cexp -> CPS.lvar list)
    val freemapClose : CPS.cexp * (CPS.lvar -> bool)
			-> (CPS.lvar -> CPS.lvar list)
    val freemapSpill : (CPS.function * 'a) list * (CPS.lvar -> bool)
			-> (CPS.lvar -> CPS.lvar list)
  end

structure FreeMap : FREEMAP =
struct
open CPS SortedList

fun sublist test =
  let fun subl(a::r) = if test a then a::(subl r) else subl r
        | subl nil = nil
  in  subl
  end

fun freemap add =
let fun setvars (w,free) =
	    let val g = remove([w],free)
	     in add(w,g); g
	    end
    val rec freevars =
	 fn APP(v,args) => uniq(v::args)
	  | SWITCH(v,l) => fold merge (map freevars l) [v]
	  | RECORD(l,w,ce) => merge(uniq (map #1 l), setvars(w, freevars ce))
	  | SELECT(_,v,w,ce) => merge([v], setvars(w, freevars ce))
	  | OFFSET(_,v,w,ce) => merge([v], setvars(w, freevars ce))
	  | PRIMOP(_,args,ret,ce) =>
	     let fun f(w::wl) = setvars(w, f wl)
		   | f nil = fold merge (map freevars ce) nil
	     in  merge(uniq args,f(rev ret))
	     end
	  | FIX _ => ErrorMsg.impossible "FIX in Freemap.freemap"
in  fn ce => freevars ce
end

fun freemapClose(ce,constant) =
let exception Freemap
    val vars : lvar list Intmap.intmap = Intmap.new Freemap
    fun setvars(v,l) =
	let fun f nil = nil
	      | f (w::tl) =
		if constant w
		    then f tl else w::f tl
	    val truefree = f l
	in  Intmap.add vars (v,truefree); truefree
	end
    val rec freevars =
	 fn FIX(l,ce) =>
		let val functions = map #1 l
		    val freel = map (fn(v,args,body) =>
				       setvars(v,remove(uniq args,freevars body)))
				    l
		in  remove(uniq functions,fold merge freel (freevars ce))
		end
	  | APP(v,args) => uniq(v::args)
	  | SWITCH(v,l) => fold merge (map freevars l) [v]
	  | RECORD(l,w,ce) => merge(uniq (map #1 l),remove([w],freevars ce))
	  | SELECT(_,v,w,ce) => merge([v],remove([w],freevars ce))
	  | OFFSET(_,v,w,ce) => merge([v],remove([w],freevars ce))
	  | PRIMOP(_,args,ret,ce) =>
		merge(uniq args,
		      remove(uniq ret, 
			     fold merge (map freevars ce) nil))
in  freevars ce; Intmap.map vars
end

fun freemapSpill(carg,constant) =
let exception FreemapSpill
    val vars : lvar list Intmap.intmap = Intmap.new FreemapSpill
    fun setvars(v,l) =
	let val truefree = remove([v],sublist (not o constant) l)
	in  Intmap.add vars (v,truefree); truefree
	end
    val rec freevars =
	 fn FIX _ => ErrorMsg.impossible "FIX in cps/freemapSpill"
	  | APP(v,args) => uniq(v::args)
	  | RECORD(l,w,ce) => merge(uniq (map #1 l), setvars(w, freevars ce))
	  | SELECT(_,v,w,ce) => merge([v], setvars(w, freevars ce))
	  | OFFSET(_,v,w,ce) => merge([v], setvars(w, freevars ce))
	  | SWITCH(v,l) => fold merge (map freevars l) [v]
	  | PRIMOP(_,args,ret as w::_,ce) =>
		merge(uniq args,
		      setvars(w,remove(uniq ret,
				       fold merge (map freevars ce) nil)))
	  | PRIMOP(_,args,nil,ce) =>
		merge(uniq args,fold merge (map freevars ce) nil)
in  app (fn ((_,_,b),_) => freevars b) carg; Intmap.map vars
end

(* temporary, for debugging *)
val freetimer = ref(System.Timer.check_timer(System.Timer.start_timer()))
fun timeit f a =
  let val t = System.Timer.start_timer()
      val r = f a
  in  System.Stats.update(freetimer,System.Timer.check_timer t);
      r
  end
val freemap = timeit freemap
val freemapClose = timeit freemapClose
val freemapSpill = timeit freemapSpill


end (* structure FreeMap *)
