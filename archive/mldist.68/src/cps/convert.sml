(* Copyright 1989 by AT&T Bell Laboratories *)
(* notes:
     OFFSET should not be generated by this module
*)

structure Convert : sig val convert: Lambda.lexp -> CPS.function end = 
struct

open CPS Access

val OFFp0 = OFFp 0

fun sublist test =
  let fun subl(a::r) = if test a then a::(subl r) else subl r
        | subl x = x
  in  subl
  end

local open Lambda 
in
  fun translatepath [v] = VAR v
    | translatepath (x::p) = SELECT(x,translatepath p)
    | translatepath nil = ErrorMsg.impossible "convert.translatepath nil"

  fun isboxedRep(CONSTANT _) = false
    | isboxedRep(TRANSU) = false
    | isboxedRep(_) = true

  fun isboxed (DATAcon(_,rep)) = isboxedRep rep
    | isboxed (REALcon _) = true
    | isboxed (STRINGcon s) = (size s <> 1)
    | isboxed _ = false
end

fun mk f = f (mkLvar())

val sortcases = Sort.sort (fn ((i:int,_),(j,_)) => i>j)

val calling =
    fn P.boxed => (1,0,2)
     | P.unboxed => (1,0,2)
     | P.< => (2,0,2)
     | P.<= => (2,0,2)
     | P.> => (2,0,2)
     | P.>= => (2,0,2)
     | P.lessu => (2,0,2)
     | P.gequ => (2,0,2)
     | P.ieql => (2,0,2)
     | P.ineq => (2,0,2)
     | P.feql => (2,0,2)
     | P.fge => (2,0,2)
     | P.fgt => (2,0,2)
     | P.fle => (2,0,2)
     | P.flt => (2,0,2)
     | P.fneq => (2,0,2)
     | P.gethdlr => (0,1,1)
     | P.* => (2,1,1)
     | P.+ => (2,1,1)
     | P.- => (2,1,1)
     | P.div => (2,1,1)
     | P.orb => (2,1,1)
     | P.andb => (2,1,1)
     | P.xorb => (2,1,1)
     | P.rshift => (2,1,1)
     | P.lshift => (2,1,1)
     | P.fadd => (2,1,1)
     | P.fdiv => (2,1,1)
     | P.fmul => (2,1,1)
     | P.fsub => (2,1,1)
     | P.subscript => (2,1,1)
     | P.subscriptf => (2,1,1)
     | P.ordof => (2,1,1)
     | P.! => (1,1,1)
     | P.alength => (1,1,1)
     | P.makeref => (1,1,1)
     | P.delay => (2,1,1)
     | P.slength => (1,1,1)
     | P.~ => (1,1,1)
     | P.notb => (1,1,1)
     | P.sethdlr => (1,0,1)
     | P.:= => (2,0,1)
     | P.unboxedassign => (2,0,1)
     | P.store => (3,0,1)
     | P.updatef => (3,0,1)
     | P.unboxedupdate => (3,0,1)
     | P.update => (3,0,1)
     | P.floor => (1,1,1)
     | P.round => (1,1,1)
     | P.real => (1,1,1)
     | _ => ErrorMsg.impossible "calling with bad primop"

  fun nthcdr(l, 0) = l 
    | nthcdr(a::r, n) = nthcdr(r, n-1)
    | nthcdr _ = ErrorMsg.impossible "nthcdr in convert"

  fun count test =
    let fun subl acc (a::r) = subl(if test a then 1+acc else acc) r
          | subl acc nil = acc
    in subl 0
    end

fun convert lexp =
let
    local open Intmap
	  exception Rename
	  val m : value intmap = new(32, Rename)
	  val rename = map m
     in fun ren v = rename v handle Rename => VAR v
	val newname = add m
    end

    fun switch1(e : value, cases : (int*cexp) list, d : lvar, (lo,hi)) =
      let val delta = 2
	  fun collapse (l as (li,ui,ni,xi)::(lj,uj,nj,xj)::r ) =
			if ((ni+nj) * delta > ui-lj) 
			    then collapse((lj,ui,ni+nj,xj)::r)
			    else l
	    | collapse l = l
	  fun f (z, x as (i,_)::r) = f(collapse((i,i,1,x)::z), r)
	    | f (z, nil) = z
	  fun tackon (stuff as (l,u,n,x)::r) = 
		    if n*delta > u-l andalso n>4 andalso hi>u
			then tackon((l,u+1,n+1,x@[(u+1,APP(VAR d, nil))])::r)
			else stuff
	  fun separate((z as (l,u,n,x))::r) =
		if n<4 andalso n>1 
		    then let val ix as (i,_) = nth(x, (n-1))
			  in (i,i,1,[ix])::separate((l,l,n-1,x)::r)
			 end
		    else z :: separate r
	    | separate nil = nil
	  val chunks = rev (separate (tackon (f (nil,cases))))
	  fun g(1,(l,h,1,(i,b)::_)::_,(lo,hi)) = 
		if lo=i andalso hi=i then b
		    else PRIMOP(P.ineq,[e, INT i], nil, [APP(VAR d, nil), b])
	    | g(1,(l,h,n,x)::_,(lo,hi)) =
		let fun f(0,_,_) = nil
		      | f(n,i,l as (j,b)::r) =
			   if i+lo = j then b::f(n-1,i+1,r)
				       else (APP(VAR d, nil))::f(n,i+1,l)
		    val list = f(n,0,x)
		    val body = if lo=0 then SWITCH(e, list)
			       else mk(fn e' =>
				      PRIMOP(P.-,[e, INT lo], [e'], 
					       [SWITCH(VAR e', list)]))
		    val a = if (lo<l)
			     then PRIMOP(P.<,[e, INT l], nil, [APP(VAR d,nil), body])
			     else body
		    val b = if (hi > h)
			     then PRIMOP(P.>,[e, INT h], nil, [APP(VAR d,nil), a])
			     else a
		 in b
		end
	    | g(n,cases,(lo,hi)) =
	       let val n2 = n div 2
		   val c2 as (l,_,_,_)::r = nthcdr(cases, n2)
		in PRIMOP(P.<,[e, INT l],nil, [g(n2,cases,(lo,l-1)),
					        g(n-n2,c2,(l,hi))])
	       end
       in g (length chunks, chunks, (lo, hi))
      end

    fun switch(e: value, l, d, inrange) =
     let val len = List.length l
	 val d' = case d of SOME d' => d' | NONE => mkLvar()
	 fun ifelse nil = APP(VAR d',nil)
	   | ifelse ((i,b)::r) = 
			PRIMOP(P.ineq,[INT i, e], nil, [ifelse r, b])
	 fun ifelseN [(i,b)] = b
	   | ifelseN ((i,b)::r) = 
		    PRIMOP(P.ineq,[INT i, e], nil, [ifelseN r, b])
	   | ifelseN _ = ErrorMsg.impossible "convert.224"  
	 val l = sortcases l
	in case (len<4, inrange)
	  of (true, NONE) => ifelse l
	   | (true, SOME n) =>  if n+1=len then ifelseN l else ifelse l
	   | (false, NONE) =>
		 let fun last [x] = x | last (_::r) = last r
		     val (hi,_) = last l and (low,_)::r = l
		  in  PRIMOP(P.>,[INT low, e], nil, [APP(VAR d',[]), 
			 PRIMOP(P.<,[INT hi, e], nil, [APP(VAR d',[]),
			      switch1(e, l, d', (low,hi))])])
		 end
	   | (false, SOME n) => switch1(e, l, d', (0,n))
      end

    val unevaled =  INT(System.Tags.desc_unevaled_susp div 2)
    val evaled = INT(System.Tags.desc_evaled_susp div 2)

    fun convlist (el,c) =
      let fun f(le::r, vl) = conv(le, fn v => f(r,v::vl))
	    | f(nil, vl) = c (rev vl)
       in f (el,nil)
      end

     and getargs(1,a,g) = conv(a, fn z => g[z])
       | getargs(n,Lambda.RECORD l,g) = convlist(l,g)
       | getargs(n, a, g) = 
		conv(a,  fn v =>
		     let fun f (j,wl) = if j=n
			      then g(rev wl)
			      else mk(fn w => SELECT(j,v,w,f(j+1,VAR w :: wl)))
		      in f(0,nil)
		     end)

    and conv (le, c : value -> cexp) = case le
     of Lambda.APP(Lambda.PRIM P.callcc, f) => let
          val h = mkLvar() and k = mkLvar() and x = mkLvar()
          val k' = mkLvar() and x' = mkLvar()
          in
          (* k is the callcc return cont, k' is the argument cont. *)
            FIX([(k, [x], c (VAR x))],
              PRIMOP(P.gethdlr, [], [h],
                [FIX(
                  [(k', [x'], PRIMOP(P.sethdlr, [VAR h], [], [APP(VAR k, [VAR x'
])]))],
                  conv (f, fn vf => APP(vf, [VAR k', VAR k])))]))
          end
      | Lambda.APP(Lambda.PRIM P.capture, f) => let
        val k = mkLvar() and x = mkLvar()
        in
          FIX([(k, [x], c (VAR x))],
            conv (f, fn vf => APP(vf, [VAR k, VAR k])))
        end
      | Lambda.APP(Lambda.PRIM P.throw, v) => let
	  val f = mkLvar() and f'' = mkLvar() and x = mkLvar()
	  in
	    conv(v,
	      fn k => FIX(
		  [(f, [x, f''], APP(k, [VAR x]))],
		  c (VAR f)))
	  end
   | Lambda.APP(Lambda.PRIM P.cast, x) => conv(x,c)
   | Lambda.APP(Lambda.PRIM P.force, k) => 
      let val c0=mkLvar() and c0v=mkLvar() and w=mkLvar() and x=mkLvar()
	  and y=mkLvar() and c1=mkLvar() and c1v=mkLvar()
       in conv(k, fn v =>
	  FIX([(c0,[c0v],c(VAR c0v))],
	   PRIMOP(P.boxed,[v],[],[PRIMOP(P.subscript,[v,INT(~1)],[w],[
		 PRIMOP(P.ieql,[VAR w, evaled],[],
			       [PRIMOP(P.!,[v],[x],[APP(VAR c0, [VAR x])]),
		  PRIMOP(P.ineq,[VAR w, unevaled],[],[APP(VAR c0,[v]),
		     FIX([(c1,[c1v],
			      PRIMOP(P.:=,[v, VAR c1v],[],[
			       PRIMOP(P.update,[v, INT ~1, evaled],[],[
				APP(VAR c0, [VAR c1v])])]))],
			PRIMOP(P.!,[v],[y],[APP(VAR y, [INT 0, VAR c1])]))])])]),
		 APP(VAR c0, [v])])))
      end
(*   | Lambda.APP(Lambda.PRIM P.delay, a) =>
	if !System.Control.reopen
	  then Reopen.delayConvert(convert a)
          else getargs(n,a,fn vl => mk(fn w => PRIMOP(i,vl,[w],[c(VAR w)])))
*)   | Lambda.APP(Lambda.PRIM i, a) =>
     (case calling i of
        (n,1,1) => getargs(n,a,fn vl => mk(fn w => PRIMOP(i,vl,[w],[c(VAR w)])))
      | (n,0,1) => getargs(n,a,fn vl => PRIMOP(i,vl,[],[c (INT 0)]))
      | (n,0,2) => getargs(n,a,fn vl =>
           let val cv = mkLvar() and v = mkLvar()
	   in FIX([(cv,[v],c(VAR v))],
		  PRIMOP(i,vl,[],[APP(VAR cv, [INT 1]),APP(VAR cv, [INT 0])]))
	   end))
   | Lambda.PRIM i => mk(fn v => conv(Lambda.FN(v,Lambda.APP(le,Lambda.VAR v)),c))
   | Lambda.VAR v => c (ren v)
   | Lambda.APP(Lambda.FN(v,e),a) =>
     conv(a, fn w => (newname(v,w);
		      case w of VAR w' => Access.sameName(v,w') | _ => ();
		      conv(e, c)))
   | Lambda.FN (v,e) => let val f = mkLvar() and w = mkLvar()
			in FIX([(f,[v,w],
				 conv(e, fn z => APP(VAR w,[z])))], c(VAR f))
			end
   | Lambda.APP (f,a) =>
     let val fc = mkLvar() and x = mkLvar()
     in FIX([(fc,[x],c(VAR x))],
	    conv(f,fn vf => conv(a,fn va => APP(vf,[va, VAR fc]))))
     end
   | Lambda.FIX (fl, el, body) =>
     let fun g(f::fl, Lambda.FN(v,b)::el) =
	     mk(fn w =>(f,[v,w], conv(b, fn z => APP(VAR w, [z])))) :: g(fl,el)
           | g(nil,nil) = nil
     in FIX(g(fl,el), conv(body,c))
     end
   | Lambda.INT i => ((i+i; c(INT i))
      handle Overflow =>
	     let open Lambda
	     in conv(APP(PRIM P.+, RECORD[INT(i div 2), INT(i - i div 2)]),c)
	     end)
   | Lambda.REAL i => c(REAL i)
   | Lambda.STRING i => (case size i
			  of 1 => c(INT(ord i))
			   | _ => c(STRING i))
   | Lambda.RECORD nil => c (INT 0)
   | Lambda.RECORD l => convlist(l,fn vl => mk(fn x => 
			RECORD(map (fn v => (v, OFFp0)) vl, x, c(VAR x))))
   | Lambda.SELECT(i, e) => mk(fn w => conv(e, fn v => 
				SELECT(i, v, w, c(VAR w))))
   | Lambda.CON((_,CONSTANT i),e) => conv(Lambda.INT i, c)
   | Lambda.CON((_,TAGGED i),e) => conv(Lambda.RECORD[e, Lambda.INT i], c)
   | Lambda.CON((_,TRANSPARENT),e) => conv(e,c)
   | Lambda.CON((_,TRANSB),e) => conv(e,c)
   | Lambda.CON((_,TRANSU),e) => conv(e,c)
   | Lambda.CON((_,VARIABLE(PATH p)),e) =>
                  let fun g [v] = (ren v, OFFp0)
		        | g (i::r) = let val (v,p) = g r in (v, SELp(i,p)) end
		   in mk(fn x => conv(e, fn v => 
				      RECORD([(v,OFFp0),g p],x, c(VAR x))))
		  end
   | Lambda.CON((_,VARIABLEc(PATH p)),e) => 
                  let fun g [v] = Lambda.VAR v
		        | g (i::r) = Lambda.SELECT(i, g r)
                   in conv(g p, c)
		  end
   | Lambda.DECON((_,TAGGED i),e) => conv(Lambda.SELECT(0,e), c)
   | Lambda.DECON((_,TRANSPARENT),e) => conv(e,c)
   | Lambda.DECON((_,TRANSB),e) => conv(e,c)
   | Lambda.DECON((_,TRANSU),e) => conv(e,c)
   | Lambda.DECON((_,VARIABLE(PATH p)),e) => conv(Lambda.SELECT(0,e), c)
   | Lambda.SWITCH(e,_,l as (Lambda.DATAcon(_,Access.VARIABLE _), _)::_, SOME d) => exnswitch(e,l,d,c)
   | Lambda.SWITCH(e,_,l as (Lambda.DATAcon(_,Access.VARIABLEc _), _)::_, SOME d) => exnswitch(e,l,d,c)
   | Lambda.SWITCH(e,_,l as (Lambda.REALcon _, _)::_, SOME d) =>
     let val cf = mkLvar() and vf = mkLvar()
     in FIX([(cf, [vf], c(VAR vf))],
         conv(e, fn w =>
	  let fun g((Lambda.REALcon rval, x)::r) =
		  PRIMOP(P.fneq, [w, REAL rval],[], 
				 [g r, conv(x,fn z => APP(VAR cf, [z]))])
	        | g nil = conv(d, fn z => APP(VAR cf, [z]))
	        | g _ = ErrorMsg.impossible "convert.81"
	  in g l
	  end))
     end
   | Lambda.SWITCH(e,_,l as (Lambda.INTcon _, _)::_, SOME d) =>
     let val cf = mkLvar() and vf = mkLvar() and df = mkLvar()
     in FIX([(cf, [vf], c(VAR vf)), 
	     (df, [], conv(d, fn z => APP(VAR cf, [z])))],
         conv(e, fn w =>
	  let fun g (Lambda.INTcon j, a) = (j,conv(a, fn z => APP(VAR cf,[z])))
	  in switch(w, map g l, SOME df, NONE)
	  end))
     end
   | Lambda.SWITCH(e,_,l as (Lambda.STRINGcon _, _)::_, SOME d) =>
     let val cf=mkLvar() and vf=mkLvar() and df=mkLvar() and vd=mkLvar()
	 val cont = fn z => APP(VAR cf, [z])
	 fun isboxed (Lambda.STRINGcon s, _) = size s <> 1
	 val b = sublist isboxed l
	 val u = sublist (not o isboxed) l
	 fun g(Lambda.STRINGcon j, e) = (ord j, conv(e,cont))
	 val z = map g u
	 val [p1,p2] = !CoreInfo.stringequalPath
     in FIX([(cf, [vf], c(VAR vf)), (df, [], conv(d, cont))],
	conv(e, fn w =>
	let val genu = switch(w, z, SOME df, NONE)
	    fun genb [] = APP(VAR df, [])
	      | genb cases = 
		let val len1 = mkLvar()
		    fun g((Lambda.STRINGcon s, x)::r) =
		      let val ssize = size s
			  val k=mkLvar() and seq=mkLvar() and pair=mkLvar()
			  and c2=mkLvar() and ans=mkLvar()
		      in FIX((k,[], g r)::
		             (if ssize=0 then []
			     else [(c2,[ans],PRIMOP(P.ieql,[VAR ans, INT 0],[],
				              [APP(VAR k,[]), conv(x,cont)]))]),
 			     PRIMOP(P.ineq,[INT ssize, VAR len1],[],
 			       [APP(VAR k, []),
 				if ssize=0 then conv(x,cont)
 				else SELECT(p1,ren p2,seq,
				      RECORD([(w, OFFp0),(STRING s, OFFp0)],
				       pair, APP(VAR seq,[VAR pair, VAR c2])))]))
		      end
		      | g nil = APP(VAR df, [])
		in PRIMOP(P.slength,[w],[len1], [g cases])
		end
	in PRIMOP(P.boxed,[w],[],[genb b, genu])
        end))
     end
   | Lambda.SWITCH
     (x as (Lambda.APP(Lambda.PRIM i, args),
	_,
        [(Lambda.DATAcon(_,Access.CONSTANT c1),e1),
	 (Lambda.DATAcon(_,Access.CONSTANT c2),e2)],
	 NONE)) =>
     let fun g(n,a,b) =
	 let val cf = mkLvar() and v = mkLvar()
	     val cont = (fn w => APP(VAR cf, [w]))
	 in FIX([(cf,[v],c(VAR v))],
	     getargs(n,args,fn vl => PRIMOP(i,vl,[],[conv(a,cont),conv(b,cont)])))
	 end
     in case (calling i, c1, c2) of
	  ((n,0,2), 1, 0) => g(n,e1,e2)
	| ((n,0,2), 0, 1) => g(n,e2,e1)
	| _ => genswitch(x,c)
     end
   | Lambda.SWITCH x => genswitch(x,c)
   | Lambda.RAISE(e) =>
     conv(e,fn w => mk(fn h => PRIMOP(P.gethdlr,[],[h],[APP(VAR h,[w])])))
   | Lambda.HANDLE(a,b) =>
     let val h = mkLvar() and vb = mkLvar() and vc = mkLvar()
	 and x = mkLvar() and v = mkLvar ()
     in FIX([(vc,[x],c(VAR x))],
         PRIMOP(P.gethdlr,[],[h],
	  [FIX([(vb,[v],PRIMOP(P.sethdlr,[VAR h],[],
				[conv(b,fn f => APP(f,[VAR v, VAR vc]))]))],
	    PRIMOP(P.sethdlr,[VAR vb],[],
	     [conv(a, fn va => PRIMOP(P.sethdlr,[VAR h],[], 
					[APP(VAR vc, [va])]))]))]))
     end

  and exnswitch(e,l,d,c) =
     let val cf = mkLvar() and vf = mkLvar()
     in FIX([(cf, [vf], c(VAR vf))],
         conv(Lambda.SELECT(1,e), fn w =>
	  let fun g((Lambda.DATAcon(_,Access.VARIABLEc(Access.PATH p)), x)::r)=
		    conv(translatepath(1::p), fn v =>
		    PRIMOP(P.ineq, [w,v], [], [g r, conv(x, fn z => 
							   APP(VAR cf,[z]))]))
	        | g((Lambda.DATAcon(_,Access.VARIABLE(Access.PATH p)), x)::r) =
		    conv(translatepath p, fn v =>
		    PRIMOP(P.ineq, [w,v], [], [g r, conv(x, fn z => APP(VAR cf,[z]))]))
	        | g nil = conv(d, fn z => APP(VAR cf,[z]))
	        | g _ = ErrorMsg.impossible "convert.21"
	  in g l
	  end))
     end

 and genswitch ((e, sign, l: (Lambda.con * Lambda.lexp) list, d),c) =
     let val cf = mkLvar() and cv = mkLvar() and df = mkLvar()
	 val cont = fn z => APP(VAR cf,[z])
	 val boxed = sublist (isboxed o #1) l
	 val unboxed = sublist (not o isboxed o #1) l
	 val w = mkLvar() and t = mkLvar()
         fun tag (Lambda.DATAcon(_,Access.CONSTANT i), e) = (i, conv(e,cont))
           | tag (Lambda.DATAcon(_,Access.TAGGED i), e) = (i, conv(e,cont))
	   | tag (c,e) = (0, conv(e,cont))
     in FIX((cf,[cv],c(VAR cv)) ::
	    (case d of NONE => [] | SOME d' => [(df,[],conv(d',cont))]),
        conv(e, fn w =>
	case (count isboxedRep sign, count (not o isboxedRep) sign)
	 of (0, n) => switch(w, map tag l, SOME df, SOME(n-1))
	  | (n, 0) => SELECT(1, w, t, switch(VAR t, map tag l, SOME df, SOME(n-1)))
	  | (1, nu) =>
	    PRIMOP(P.boxed, [w], [], 
		[switch((INT 0), map tag boxed, SOME df, SOME 0), 
		 switch(w, map tag unboxed, SOME df, SOME(nu-1))])
	  | (nb,nu) =>
	    PRIMOP(P.boxed, [w], [], 
		[SELECT(1,w,t, switch(VAR t, map tag boxed, SOME df, SOME(nb-1))), 
		 switch(w, map tag unboxed, SOME df, SOME(nu-1))])))
     end
 val v = mkLvar() and x = mkLvar() and f = mkLvar()
in (f, [v,x], conv(lexp, fn w => APP(w,[VAR v, VAR x])))
end

end

