(* Copyright 1989 by AT&T Bell Laboratories *)
signature OPT =
sig
  structure L : LAMBDA sharing L=Lambda
  structure A : ACCESS sharing A=Access
  val reduce : L.lexp -> L.lexp
  val hoist : L.lexp -> L.lexp
  val closestr : (int -> string) * L.lexp * int list -> L.lexp
  val bareCloseTop:
    {lambda: L.lexp, looker: int, extras: int list, keepFree: int list} -> L.lexp
	(* bareCloseTop is a more general form of closetop. It is passed an already
	   existing looker lvar, and also a keepFree list of lvars which it must
	   keep free (they'll be abstracted later). *)

  val closetop : L.lexp * int list -> L.lexp
end

structure Opt : OPT =
struct

structure A : ACCESS = Access
structure L : LAMBDA = Lambda
structure CGoptions = System.Control.CG

open A Basics L

fun root [v] = v | root (_::p) = root p
  | root _ = ErrorMsg.impossible "root [] in codegen/opt";

exception Freevars

fun mapfree lookfree =
   let val m = Intmap.new(32, Freevars) : lexp Intmap.intmap
      val add = Intmap.add m
      fun look v = Intmap.map m v
		   handle Freevars =>
                     let val x = lookfree v in add(v,x); x end
      fun copycon (DATAcon(DATACON{rep=(VARIABLE(Access.PATH p)),const,name,typ,sign})) =
	    let fun f [v] = let val VAR w = look v in [w] end
	          | f (i::r) = i::(f r) 
	     in DATAcon(DATACON{rep=(VARIABLE (Access.PATH(f p))),const=const,
			    name=name,typ=typ,sign=sign})
	    end
        | copycon c = c
      fun newvar v = let val w = dupLvar v in add(v,VAR w); w end	    
      val rec f =
	 fn VAR v => look v
          | FN(v,b) => FN(newvar v, f b)
	  | FIX(vl,el,b) => FIX(map newvar vl, map f el, f b)
	  | APP(a,b) => APP(f a, f b)
	  | SELECT(i,a) => SELECT(i, f a)
	  | RECORD l => RECORD(map f l)
	  | SWITCH(a, l, SOME d) => 
			SWITCH(f a, map(fn(c,x)=>(copycon c, f x))l, SOME(f d))
	  | SWITCH(a, l, NONE) => 
			SWITCH(f a,map(fn(c,x)=>(copycon c, f x))l,NONE)
	  | HANDLE(a,b) => HANDLE(f a, f b)
	  | RAISE x => RAISE(f x)
	  | e as INT _ => e
	  | e as STRING _ => e
	  | e as REAL _ => e
	  | e as PRIM _ => e
    in f
   end

val alphaConvert = mapfree VAR

val simple = fn VAR _ => true
	      | RECORD [] => true
	      | INT _ => true
	      | STRING s => size s = 1
	      | _ => false

fun all f = not o (exists (not o f))

val rec pure =
	   fn VAR _ => true
	    | APP(FN(_,a),b) => pure a andalso pure b
	    | FIX(vl,el,b) => pure b
	    | APP(PRIM P.callcc, FN(_,b)) => pure b
	    | APP(PRIM i, z) => Prim.pure i andalso pure z
	    | FN _ => true
	    | INT _ => true
	    | REAL _ => true
	    | PRIM _ => true
	    | STRING _ => true
	    | SELECT(_, x) => pure x
	    | RECORD l => all pure l
	    | SWITCH(a, l, NONE) => pure a andalso all (pure o #2) l
	    | SWITCH(a, l, SOME d) => pure a andalso pure d andalso
				      all (pure o #2) l
	    | _ => false

exception BadSwitch

fun testint i = fn INTcon j => i=j
		 | DATAcon(DATACON{rep=(CONSTANT j),...}) => i=j
		 | STRINGcon j => size j = 1 andalso i = ord j
		 | DATAcon(DATACON{rep=(TRANSU),...}) => true
	         | _ => false
val testboxed   = fn DATAcon(DATACON{rep=(TRANSB),...}) => true
		   | DATAcon(DATACON{rep=(TRANSPARENT),...}) => true
		   | DATAcon(DATACON{rep=(TAGGED j),...}) => raise BadSwitch
		   | DATAcon(DATACON{rep=(VARIABLE j),...}) => raise BadSwitch
		   | _ => false
fun testtag i = fn DATAcon(DATACON{rep=(TRANSB),...}) => true
		 | DATAcon(DATACON{rep=(TRANSPARENT),...}) => true
		 | DATAcon(DATACON{rep=(TAGGED j),...}) => i=j
		 | _ => false
fun teststring s = fn STRINGcon j => s=j
		    | _ => false

fun switch(SWITCH(e,l,d)) =
	let val _ = if not(!System.Control.CG.misc1) then raise BadSwitch else()
	    val test = case e
		    of INT i => testint i
		     | STRING s => if size s = 1 then testint(ord s)
					else teststring s
		     | RECORD[_,INT i] => testtag i
		     | RECORD [] => testint 0
		     | RECORD _ => testboxed
		     | FN _ => testboxed
		     | FIX _ => testboxed
		     | REAL _ => testboxed
		     | _ => raise BadSwitch
	    fun f ((c,x)::r) = if test c then x else f r
              | f [] = case d
			  of SOME z => z
			   | NONE => ErrorMsg.impossible "no default"
         in f l
        end

fun reduce exp =
      let val clicked = ref false
	  fun click() = clicked := true
	  exception Reducemap
	  val t = Intmap.new(32, Reducemap) : lexp Intmap.intmap
	  val set = Intmap.add t
	  val set = fn x as (v, VAR w) => (sameName(v,w); set x)
	             | x => set x
	  val unset = Intmap.rem t
	  val imap = Intmap.map t
          val s = Intset.new()
	  val mark = Intset.add s
	  val marked = Intset.mem s
	  fun mapvar v = (imap v handle Reducemap => VAR v)
	  fun makp [v] = ((case imap v of VAR w => makp[w]
				        | _ => (mark v; [v]))
			  handle Reducemap => (mark v; [v]))
	    | makp (i::p) = i :: makp p
	  val rec makcon =
		fn (DATAcon(DATACON{rep=(VARIABLE(PATH p)),
					    name,const,typ,sign}), e) =>
		          (DATAcon(DATACON{rep=(VARIABLE(PATH(makp p))),
			       name=name,const=const,typ=typ,sign=sign}),
			   mak e)
		  | (c,e) => (c, mak e)
	  and mak =
	     fn FN(v,b as APP(l,VAR w)) =>
		 if v=w andalso pure l 
			andalso  !System.Control.CG.misc2
		  then let val body = mak l
		       in  if marked v then FN(v,mak(APP(body,VAR v)))
			   else (click(); body)
		       end
		  else FN(v, mak b)
	      | APP(FN(v, sw as SWITCH(VAR v',l,d)), e) =>
		if v=v' then
		let val e' = mak e
		    val _ = set(v,e')
	         in let val sw' = mak(switch(SWITCH(e',l,d)))
		        val _ = unset v
		     in if marked v orelse not (pure e')
				 then APP(FN(v,sw'),e') else (click(); sw')
		    end
		    handle BadSwitch =>
		    let val l' = map makcon l
		        val d' = case d of NONE => NONE | SOME a => SOME(mak a)
		        val _ = unset v
		     in if marked v then APP(FN (v, SWITCH(VAR v, l', d')), e')
				    else (click(); SWITCH(e', l', d'))
		    end
	        end
		else    let val arg = mak e
			    val body = (set(v, arg); mak sw before unset v)
			in  if marked v orelse not(pure arg)
				then APP(FN(v,body),arg)
				else (click(); body)
			end
	      | APP(FN(v,e'),e) =>
			let val arg = mak e
			    val body = (set(v, arg); mak e' before unset v)
			in  if marked v orelse not(pure arg)
				then APP(FN(v,body),arg)
				else (click(); body)
			end
	      | FIX([],[],b) => (click(); mak b)
	      | FIX(vl,el,b) => FIX(vl,map (fn FN(v,e) => FN(v,mak e)) el,mak b)
	      | e as VAR v => (let val e' = imap v
			       in  if simple e' then (click(); mak e')
					        else (mark v; e)
			       end handle Reducemap => (mark v; e))
	      | e as SELECT(i, VAR v) =>
			      ((case imap v
			        of RECORD l =>
				   let val e' = nth(l,i)
				   in  if simple e' then (click(); e')
						    else (mark v; e)
				   end
				 | ew as VAR w => mak(SELECT(i,ew))
				 | _ => (mark v; e))
			        handle Reducemap => (mark v; e))
	      | FN (w,b) => FN(w,mak b)
	      | APP (f,a) => APP(mak f, mak a)
	      | SWITCH(e,l,d) => 
		((case e
		  of VAR v => mak(switch(SWITCH(imap v
				handle Reducemap => raise BadSwitch
				  , l, d)))
		   | _ => raise BadSwitch
		) handle BadSwitch =>
		let val e' = mak e
		 in mak(switch(SWITCH(e', l, d)))
		   handle BadSwitch => SWITCH(e', map makcon l,
				  case d of NONE => NONE 
					  | SOME a => SOME(mak a))
		end)
	      | RECORD l => RECORD(map mak l)
	      | SELECT (i,e) => SELECT(i,mak e)
	      | HANDLE (a,h) => HANDLE(mak a, mak h)
	      | RAISE e => RAISE(mak e)
	      | e as INT _ => e
	      | e as REAL _ => e
	      | e as STRING _ => e
	      | e as PRIM _ => e
	 val exp' = mak exp
      in  if !clicked then reduce exp' else exp'
      end

(* minimal hoist function:  does not move bindings around, evaluation order
   is unchanged. *)
fun hoist (FN(v,b)) = FN(v,hoist b)
  | hoist (APP(FN(v,b),f as FN _)) = hoist(FIX([v],[f],b))
  | hoist (APP(l,r)) = APP(hoist l,hoist r)
  | hoist (FIX(vl,bl,FIX(vs,bs,b))) = hoist(FIX(vl@vs,bl@bs,b))
  | hoist (FIX(vl,bl,APP(FN(v,b),f as FN _))) = hoist(FIX(v::vl,f::bl,b))
  | hoist (FIX(vl,bl,b)) = FIX(vl,map hoist bl, hoist b)
  | hoist (SWITCH(e,l,d)) = 
	SWITCH(hoist e, map (fn (c,e) => (c, hoist e)) l,
	       case d of NONE => NONE 
		       | SOME a => SOME(hoist a))
  | hoist (RECORD l) = RECORD(map hoist l)
  | hoist (SELECT (i,e)) = SELECT(i,hoist e)
  | hoist (RAISE e) = RAISE(hoist e)
  | hoist (HANDLE (a,h)) = HANDLE(hoist a, hoist h)
  | hoist x = x

fun freevars e =
    let val t = Intset.new()
	val set = Intset.add t
	val unset = Intset.rem t
	val done = Intset.mem t
	val free : int list ref = ref []
	val rec mak =
	 fn VAR w => if done w then () else (set w; free := w :: !free)
	  | FN (w,b) => (set w; mak b; unset w)
	  | FIX (vl,el,b) => (app set vl; app mak (b::el); app unset vl)
	  | APP (f,a) => (mak f; mak a)
	  | SWITCH(e,l,d) => 
	      (mak e;
	       app (fn (DATAcon(DATACON{rep=(VARIABLE(PATH p)),...}),e) =>
			 (mak(VAR(root p)); mak e)
		     | (c,e) => mak e)
		   l;
	       case d of NONE => () | SOME a => mak a)
	  | RECORD l => app mak l
	  | SELECT (i,e) => mak e
	  | HANDLE (a,h) => (mak a; mak h)
	  | RAISE e => mak e
	  | INT _ => ()
	  | REAL _ => ()
	  | STRING _ => ()
	  | PRIM _ => ()
    in  mak e; !free
    end

local val save = (!saveLvarNames before saveLvarNames := true)
in
val boot_zero = namedLvar(Symbol.symbol "boot_zero") (* receives unit *)
val boot_one = namedLvar(Symbol.symbol "boot_one")   (* traverses free list *)
val boot_two = namedLvar(Symbol.symbol "boot_two")   (* final bogus arg *)

val (lookLvar, indexerLvar) =
        (saveLvarNames := save;
	 (namedLvar(Symbol.symbol "lookup"),
	  namedLvar(Symbol.symbol "indexer"))
	)
end

fun closestr(lookup: int->string, e:lexp, extras : int list) : lexp =
    let val fv = extras @ freevars e
	val names = map lookup fv
    in  if !System.Control.debugging
	  then app (fn s => (print s; print " ")) names
	  else ();
	FN(dupLvar boot_zero,
	   RECORD
	     [fold (fn (v,f) =>
		      let val w = dupLvar boot_one
		       in FN(w,APP(FN(v,APP(f,SELECT(1,(VAR w)))),
				   SELECT(0,(VAR w))))
		      end)
		   fv
		   (FN(dupLvar boot_two,e)),
	      fold (fn (s,f) => RECORD[STRING s, f])
		   names
		   (RECORD [])])
    end

fun remove(v :: vs: int list, from: int list) =
      let
	fun removeV(x :: xs) = if x=v then xs else x :: removeV xs
	  | removeV [] = []
      in
	remove(vs, removeV from)
      end
  | remove([], from) = from

fun bareCloseTop{lambda, looker, extras, keepFree} =
  let
    val fv = SortedList.uniq(extras @ freevars lambda)	(* Free vars plus extras *)
    val fv' = remove(keepFree, fv)	(* The ones we actually abstract *)
  in
    FN(looker,
       fold (fn (v, f) => APP(FN(v, f), APP(VAR looker, INT v)))
	    fv' lambda
      )
  end

fun closetop(e: lexp, extras: int list): lexp =
  bareCloseTop{lambda=e, looker=dupLvar lookLvar, extras=extras, keepFree=[]}

end (* structure Opt *)
