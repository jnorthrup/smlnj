functor CPSopt(val maxfree : int) :
	sig val reduce : (CPS.const Intmap.intmap) -> CPS.cexp -> CPS.cexp
        end =
struct

 open Access CPS SortedList

 fun map1 f (a,b) = (f a, b)
 fun member(i : int, a::b) = i=a orelse member(i,b)
   | member(i,[]) = false
 fun choose([],[]) = []
   | choose(a::r, true::b) = a::choose(r,b)
   | choose(a::r, false::b) = choose(r,b)
 fun sum f = let fun h [] = 0 
		   | h (a::r) = f a + h r
	     in h
	     end

 val debug = false
 fun debugprint s = if debug then print(s:string) else ()
 fun debugflush() = if debug then flush_out std_out else ()

fun reduce ctab cexp =
let
 val clicked = ref 0
 fun click (s:string) = (debugprint s; inc clicked)

 fun eta cexp =
  let exception M2
      val m : lvar Intmap.intmap = Intmap.new(32, M2)
      val name = Intmap.map m
      fun rename v = rename(name v) handle M2 => v
      val newname = Intmap.add m
      val rec eta = 
	fn RECORD(vl,w,e) => RECORD(map (map1 rename) vl, w, eta e)
	 | SELECT(i,v,w,e) => SELECT(i, rename v, w, eta e)
	 | APP(f,vl) => APP(rename f, map rename vl)
	 | SWITCH(v,el) => SWITCH(v, map eta el)
	 | PRIMOP(i,vl,wl,el) => PRIMOP(i, map rename vl, wl, map eta el)
	 | FIX(l,e) =>
	     let fun h((ff as (f,vl,APP(v,wl)))::r) = 
		     if wl=vl andalso not (member(v, f::vl))
		       then (click "e"; newname(f,rename v); h r)
		       else ff :: h r
		   | h(ff :: r) = ff :: h r
		   | h [] = []
	      in case h l of
		  [] => eta e
		| l' => FIX(map (fn(f,vl,e)=>(f,vl,eta e)) l', eta e)
	     end
  in eta cexp
  end

 val rec invEta = 
	fn RECORD(vl,w,e) => RECORD(vl, w, invEta e)
	 | SELECT(i,v,w,e) => SELECT(i, v, w, invEta e)
	 | e as APP(f,vl) => e
	 | SWITCH(v,el) => SWITCH(v, map invEta el)
	 | PRIMOP(i,vl,wl,el) => PRIMOP(i, vl, wl, map invEta el)
	 | FIX(l,e) =>
	     let fun h((f,vl,body)::r) = 
		     let val vl' = map dupLvar vl 
			 and f' = dupLvar f
		      in (f,vl',APP(f',vl'))::(f',vl, invEta body) :: h r
		     end
		   | h [] = []
	      in FIX(h l, invEta e)
	     end

 val hoist = Hoist.hoist click
fun contract last cexp =
 let val mkconst = Intmap.add ctab
     datatype cv = CO of const | VA of lvar
     fun ctable v = CO(Intmap.map ctab v) handle Ctable => VA v
     fun isconst v = case ctable v of CO _ => true | VA _ => false
     datatype arity = BOT | COUNT of int | TOP | KEEP of bool list
     datatype info = FNinfo of {arity: arity ref,
			        args: lvar list,
			        body : cexp,
				reduce_ok : bool ref}
		   | RECinfo of (lvar * accesspath) list
		   | SELinfo of (int * lvar)
		   | MISCinfo

     exception Escapemap
     val m : {info: info, used : int ref, escape : bool ref} Intmap.intmap =
		     Intmap.new(128, Escapemap)
     val get = Intmap.map m
     val enter = Intmap.add m
     fun use v = inc(#used(get v)) handle Escapemap => ()
     fun used v = !(#used(get v)) > 0 handle Escapemap => true
     fun escape v = let val {escape,used,...} = get v
		    in escape := true; inc used
		    end
		    handle Escapemap => ()
     fun argcnt(v,c) =
	 (case get v
	  of {info=FNinfo{arity as ref BOT,...},...} => arity := c
	   | {info=FNinfo{arity,...},...} => if c = !arity then () else arity := TOP
	  | _ => ())
	  handle Escapemap => ()
     fun onearg v = argcnt(v, TOP)
     fun selectonly r = not (!(#escape(get r))) handle Escapemap => false
     fun enterREC(w,vl) = enter(w,{info=RECinfo vl, escape=ref false, used = ref 0})
     fun enterSEL(w,x) = enter(w,{info=SELinfo x, escape=ref false, used = ref 0})
     fun enterMISC w = enter(w,{info=MISCinfo, escape=ref false, used = ref 0})
     fun enterFN (f,vl,cexp) =
		(enter(f,{escape=ref false,used=ref 0,
		 	 info=FNinfo{arity=ref BOT, args=vl, body=cexp,
			 reduce_ok=ref true}});
		 app enterMISC vl)

     fun checkreduce(f,_,body) = 
	    case get f
	     of {escape=ref true,info=FNinfo{reduce_ok,...},...} =>
		    (reduce_ok := false;
		     (case (body,last) 
		       of (APP(g,_),false) => ((case get g
			     of {info=FNinfo{reduce_ok,...},...} => 
				    reduce_ok := false
			      | _ => ()) handle Escapemap => ())
		        | _ => ()))
	      | {used=ref i,info=FNinfo{reduce_ok,...},...} => 
			if i>1 then reduce_ok := false else ()		    

    fun checkcount(f,v::_,_) =
	(case get f
	  of {info=FNinfo{arity as ref(COUNT _),...},escape,...} =>
	     if !escape orelse not (selectonly v) then arity := TOP else ()
	   | _ => ())
      | checkcount _ = ()
      
    fun checkdrop (z as (f,vl,_)) =
	(checkcount z;
	 case get f
	  of {info=FNinfo{arity as ref TOP,...},escape,...} =>
	     let val usedargs = map used vl
	      in if not (!escape) andalso exists not usedargs
		   then arity := KEEP usedargs
		   else ()
	     end
	   | _ => ())

     exception ConstFold

     val rec pass1 = 
      fn RECORD(vl,w,e) =>
         (enterREC(w,vl); app (escape o #1) vl; pass1 e)
       | SELECT (i,v,w,e) => (enterSEL(w,(i,v)); use v; pass1 e)
       | APP(f,vl) => 
	 ((case get(hd vl) of
	     {info=RECinfo(wl as _::_::_), ...} => 
		    let val len = length wl
		     in if len + length vl < maxfree-1
			    then argcnt(f,COUNT(length wl))
			    else onearg f
		    end
	   | _ => onearg f) handle Escapemap => onearg f
			         | Hd => onearg f;
	  use f; app escape vl)
       | FIX(l, e) => (app enterFN l;
		       app (pass1 o #3) l;
		       pass1 e;
		       app checkreduce l;
		       app checkdrop l)
       | SWITCH(v,el) => (use v; app pass1 el)
       | PRIMOP(_,vl,wl,el) =>
	 (app escape vl; app enterMISC wl; app pass1 el)
       | OFFSET _ => ErrorMsg.impossible "OFFSET in cpsopt"

     exception Beta
     val m2 : lvar Intmap.intmap = Intmap.new(32, Beta)
     fun ren v = ren(Intmap.map m2 v) handle Beta => v
     val newname = Intmap.add m2
     fun newnames(v::vl, w::wl) = (newname (v,w); newnames(vl,wl))
       | newnames([],[]) = ()
       | newnames _ = ErrorMsg.impossible "8372 in cpsopt"
     fun extract ((v,OFFp 0),(f,l)) = (f,v::l)
       | extract ((v,SELp(i,p)),x) = let val w = mkLvar()
					 val (f',l') = extract((w,p),x)
				     in ((fn e=>SELECT(i,v,w,f' e)),l')
				     end
       | extract _ = ErrorMsg.impossible "8320 in cpsopt"
     fun selectop (i,v) =
	 let val v' = ren v
	 in (case get v' of
	       {info=RECinfo vl,...} =>
	            let val (x,p) = nth(vl,i) in click "a"; (ren x, p) end
	     | _ => raise Escapemap)
	    handle Escapemap => (v', SELp(i, OFFp 0))
	 end

     fun pathopt (v,p) = 
	 let val v' = ren v
	 in (case get v' of
	       {info=SELinfo iw,used=cnt as ref 1,...} =>
	            let val (x,p0) = selectop iw
		    in click "b"; (x,combinepaths(p0,p))
		    end
	     | _ => (v',p))
	    handle Escapemap => (v',p)
	 end

     val one = let val x = mkLvar() in mkconst(x, INTconst 1); x end
     
     val rec reduce = fn cexp => g NONE cexp
     and g = fn hdlr =>
     let val rec g' =
       fn RECORD (vl,w,e) => if selectonly w
			     then (click "c"; g' e)
			     else RECORD(map pathopt vl, w, g' e)
        | SELECT(i,v,w,e) =>
	  if not(used w)
          then (click "d"; g' e)
	  else let fun f(v',OFFp 0) = (newname(w,v'); g' e)
		     | f(v',SELp(i,OFFp 0)) = SELECT(i,v',w, g' e)
		     | f(v',SELp(i,p)) = 
		       let val w' = mkLvar() in SELECT(i,v',w', f(w',p)) end
		     | f _ = ErrorMsg.impossible "38383 in cpsopt"
	       in f(selectop(i,v))
	       end
	| OFFSET _ => ErrorMsg.impossible "OFFSET in cpsopt"
	| APP(f,vl) =>
	  (((case get(ren f) of
	      {info=FNinfo{args,body,reduce_ok=ref true,...},...} =>
		(newnames(args, map ren vl); g' body)
             |{info=FNinfo{arity= ref(COUNT j), args=a::al, body,...},...} =>
		      let val {info=RECinfo wl,...} = get(hd vl)
		          val wl' = map (map1 ren) wl
		          val (ff,l) = fold extract wl' 
					    (fn x=>x, map ren (tl vl))
		       in ff(APP(ren f, l))
		      end
             |{info=FNinfo{arity= ref(KEEP l),...},...} =>
		    APP(ren f, map ren (choose(vl,l)))
	     | _ => APP(ren f, map ren vl))
	(* do KEEPARGS later *)
	   handle Escapemap => APP(ren f, map ren vl)))
	| FIX(l,e) =>
	  let fun h((f,vl,body)::r) = 
		 (case get f
		   of {used=ref 0, ...} => (click "j"; h r)
		   | {info=FNinfo{reduce_ok=ref true,...},...} => 
					    (click "k"; h r)
		   | {info=FNinfo{arity= ref(COUNT j), args=v::vl',...},...} =>
	       	          let fun vars (0,a) = a
				| vars (i,a) = vars(i-1,mkLvar()::a)
			      val newargs = vars (j,[])
			   in click "i";
			      enterREC(v, map (fn x =>(x,OFFp 0)) newargs);
			      use v;
			      (f, newargs @ vl', reduce body) :: h r
			  end
		   | {info=FNinfo{arity= ref(KEEP l),...},...} =>
			  (click "q"; (f, choose(vl,l), reduce body) :: h r)
		   | _ => (f, vl, reduce body) :: h r)
		| h [] = []
	   in case h l of [] => g' e | l' => FIX(l', g' e)
	  end
        | SWITCH(v,el) => 
		(case ctable (ren v)
		  of CO(INTconst i) => (click "*l*"; g' (nth(el,i)))
		   | VA v' => SWITCH(v', map g' el)
		   | _ => ErrorMsg.impossible "3121 in cpsopt")
	| PRIMOP(P.gethdlr,vl,wl as [w],[e]) =>
	  (case hdlr of
	     NONE => if used w then PRIMOP(P.gethdlr,vl,wl,[g (SOME w) e])
		     else (click "m"; g' e)
	   | SOME w' => (click "m"; newname(w,w'); g' e))
	| PRIMOP(P.sethdlr,[v],wl,[e]) =>
	  let val v' = ren v
	      val e' = g (SOME v') e
	  in case hdlr of
	       NONE => PRIMOP(P.sethdlr,[v'],wl,[e'])
	     | SOME v'' => if v'=v'' then (click "n"; e')
			   else PRIMOP(P.sethdlr,[v'],wl,[e'])
	  end
	| PRIMOP(i, vl, wl, el as [e1,e2]) => 
	      if e1 = e2
	      then (click "*Z*"; g' e1)
	      else let val vl' = map ren vl
	           in g' (primops(i,map ctable vl', wl, el))
	              handle ConstFold => PRIMOP(i, vl', wl, map g' el)
	           end
        | PRIMOP(i, vl, wl as [w], el as [e]) =>
	  if not(used w) andalso Prim.pure i
	    then (click "*o*"; g' e)
	    else let val vl' = map ren vl
	          in g' (primops(i,map ctable vl', wl, el))
	             handle ConstFold => PRIMOP(i, vl', wl, map g' el)
	         end
        | PRIMOP(i,vl,wl,el) =>
		 let val vl' = map ren vl
	          in g' (primops(i,map ctable vl', wl, el))
	             handle ConstFold => PRIMOP(i, vl', wl, map g' el)
	         end
      in g'
     end

     and primops =
	fn (P.boxed, CO(INTconst _)::_,_,_::b::_) => (click "A"; b)
	 | (P.boxed, CO(STRINGconst s)::_,_,a::b::_) =>
			    (click "A"; if size s = 1 then b else a)
	 | (P.boxed, VA v :: _,_,a::_) => 
            ((case get v of
		  {info=RECinfo _, ...} => (click "A"; a)
	      | _ => raise ConstFold)
	     handle Escapemap => raise ConstFold)
         | (P.<, [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
	              (click "B"; if Integer.<(i,j) then a else b)
         | (P.<=, [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
		   (click "C"; if Integer.<=(i,j) then a else b)
	 | (P.> , [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
	           (click "D"; if Integer.>(i,j) then a else b)
         | (P.>=, [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
	           (click "E"; if Integer.>=(i,j) then a else b)
         | (P.ieql, [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
		     (click "F"; if i=j then a else b)
         | (P.ineq, [CO(INTconst i),CO(INTconst j)],_,[a,b]) =>
		     (click "G"; if i=j then b else a)
         | (P.*, [CO(INTconst 1), VA(v)],[w],[c]) =>
		      (click "H"; newname(w,v); c)
	 | (P.*, [VA(v), CO(INTconst 1)],[w],[c]) =>
		      (click "H"; newname(w,v); c)
	 | (P.*, [CO(INTconst 0), _],[w],[c]) =>
		   (click "H"; mkconst(w,INTconst 0); c)
	 | (P.*, [_, CO(INTconst 0)],[w],[c]) =>
		      (click "H"; mkconst(w,INTconst 0); c)
	 | (P.*, [CO(INTconst i),CO(INTconst j)], [w], [c]) =>
		   (let val x = i*j
		    in x+x; mkconst(w,INTconst x); click "H"; c
		    end handle Overflow => raise ConstFold)
	 | (P.div, [VA(v), CO(INTconst 1)],[w],[c]) =>
		      (click "I"; newname(w,v); c)
	 | (P.div, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
		   (let val x = i div j
		    in click "I"; mkconst(w,INTconst x); c
		    end handle Div => raise ConstFold)
         | (P.+, [CO(INTconst 0), VA(v)],[w],[c]) =>
		   (click "J"; newname(w,v); c)
	 | (P.+, [VA(v), CO(INTconst 0)],[w],[c]) =>
		   (click "J"; newname(w,v); c)
	 | (P.+, [CO(INTconst i),CO(INTconst j)], [w], [c]) =>
		   (let val x = i+j
		    in x+x; mkconst(w,INTconst x); click "J"; c
		    end handle Overflow => raise ConstFold)
         | (P.-, [VA(v), CO(INTconst 0)],[w],[c]) =>
		      (click "K";newname(w,v); c)
	 | (P.-, [CO(INTconst i),CO(INTconst j)], [w], [c]) =>
		  (let val x = i-j
		   in x+x; mkconst(w,INTconst x); click "K"; c
		   end handle Overflow => raise ConstFold)
	 | (P.rshift, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
			   (click "L"; mkconst(w,INTconst(Bits.rshift(i,j))); c)
	 | (P.rshift, [CO(INTconst 0), VA v],[w],[c]) =>
			   (click "L"; mkconst(w,INTconst 0); c)
	 | (P.rshift, [VA v, CO(INTconst 0)],[w],[c]) =>
			   (click "L"; newname(w,v); c)
         | (P.slength, [CO(INTconst _)],[w],[c]) =>
			 (click "M"; mkconst(w, INTconst 1); c)
	 | (P.slength, [CO(STRINGconst s)], [w],[c]) =>
			 (click "M"; mkconst(w, INTconst(size s)); c)
         | (P.ordof, [CO(STRINGconst s), CO(INTconst i)],[w],[c]) =>
			 (click "N"; mkconst(w, INTconst (ordof(s,i))); c)
         | (P.~, [CO(INTconst i)], [w], [c]) =>
		     (let val x = ~i
		      in x+x; mkconst(w,INTconst x); click "O"; c
		      end handle Overflow => raise ConstFold)
	 | (P.lshift, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
			   (let val x = Bits.lshift(i,j)
			    in x+x; mkconst(w,INTconst x); click "P"; c
			    end handle Overflow => raise ConstFold)
	 | (P.lshift, [CO(INTconst 0), VA v],[w],[c]) =>
			   (click "P"; mkconst(w,INTconst 0); c)
	 | (P.lshift, [VA v, CO(INTconst 0)],[w],[c]) =>
			   (click "P"; newname(w,v); c)
	 | (P.orb, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
			(click "Q"; mkconst(w,INTconst(Bits.orb(i,j))); c)
	 | (P.orb, [CO(INTconst 0),VA v],[w],[c]) =>
			(click "Q"; newname(w,v); c)
	 | (P.orb, [VA v, CO(INTconst 0)],[w],[c]) =>
			(click "Q"; newname(w,v); c)
	 | (P.xorb, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
			 (click "R"; mkconst(w,INTconst(Bits.xorb(i,j))); c)
	 | (P.xorb, [CO(INTconst 0),VA v],[w],[c]) =>
			(click "R"; newname(w,v); c)
	 | (P.xorb, [VA v, CO(INTconst 0)],[w],[c]) =>
			(click "R"; newname(w,v); c)
	 | (P.notb, [CO(INTconst i)], [w], [c]) =>
			 (mkconst(w,INTconst(Bits.notb i)); click "S"; c)
	 | (P.andb, [CO(INTconst i),CO(INTconst j)],[w],[c]) =>
			 (click "T"; mkconst(w,INTconst(Bits.andb(i,j))); c)
	 | (P.andb, [CO(INTconst 0),VA v],[w],[c]) =>
			(click "T"; mkconst(w,INTconst 0); c)
	 | (P.andb, [VA v, CO(INTconst 0)],[w],[c]) =>
			(click "T"; mkconst(w,INTconst 0); c)
         | _ => raise ConstFold

    val _ = (debugprint "\nContract: "; debugflush())
  in (pass1 cexp; reduce cexp)
  end

fun expand(cexp,bodysize) =
   let
     datatype info = Fun of {escape: int ref, call: int ref, size: int ref,
		         args: lvar list, body: cexp}
	           | Arg of {escape: int ref, savings: int ref,
		             record: (int * lvar) list ref}
	           | Sel of {savings: int ref}
		   | Rec of {escape: int ref, size: int,
			     vars: (lvar * accesspath) list}

     exception Expand
     val m : info Intmap.intmap = Intmap.new(128,Expand)
     val get = Intmap.map m
     fun call(v,args) = (case get v
	            of Fun{call,...} => inc call
		     | Arg{savings,...} => savings := !savings+1
		     | Sel{savings} => savings := !savings+1
		     | Rec _ => ()  (* impossible *)
	 	  ) handle Expand => ()
     fun escape v = (case get v
	            of Fun{escape,...} => inc escape
		     | Arg{escape,...} => inc escape
		     | Sel _ => ()
		     | Rec{escape,...} => inc escape
		  ) handle Expand => ()
     fun escapeargs v = (case get v
	                 of Fun{escape,...} => inc escape
		       | Arg{escape,savings, ...} =>
			     (inc escape; savings := !savings + 1)
		       | Sel{savings} => savings := !savings + 1
		       | Rec{escape,...} => inc escape)
			 handle Expand => ()
     fun setsize(f,n) = case get f of Fun{size,...} => (size := n; n)
     fun enter (f,vl,e) = (Intmap.add m(f,Fun{escape=ref 0, call=ref 0, size=ref 0,
					      args=vl, body=e});
			   app (fn v => Intmap.add m (v,
					Arg{escape=ref 0,savings=ref 0,
					    record=ref []})) vl)
     fun noterec(w, vl, size) = Intmap.add m (w,Rec{size=size,escape=ref 0,vars=vl})
     fun notesel(i,v,w) = (Intmap.add m (w, Sel{savings=ref 0});
		     (case get v of
                        Arg{savings,record,...} => (inc savings;
						    record := (i,w)::(!record))
                      | _ => ()) handle Expand => ())
     fun save(v,k) = (case get v
		       of Arg{savings,...} => savings := !savings + k
		        | Sel{savings} => savings := !savings + k
		        | _ => ()
		     ) handle Expand => ()
     fun nsave(v,k) = (case get v
		       of Arg{savings,...} => savings := k
		        | Sel{savings} => savings := k
		        | _ => ()
		     ) handle Expand => ()
     fun savesofar v = (case get v 
		       of Arg{savings,...} => !savings
		        | Sel{savings} => !savings
		        | _ => 0
		     ) handle Expand => 0
     val rec prim = fn (_,vl,wl,el) =>
	 let fun vbl v = (Intmap.map ctab v; 0)
			  handle Ctable =>
			    ((case get v of
                                Rec _ => 0
			      | _ => 1) handle Expand => 1)
	     val nonconst = sum vbl vl
	     val len = length el
	     val sl = map savesofar vl
	     val branches = sum pass1 el
	     val zl = map savesofar vl
	     val overhead = length vl + length wl
	     val potential = overhead + (branches*(len-1)) div len
	     val savings = case nonconst of
		             1 => potential
			   | 2 => potential div 4
			   | _ => 0
	     fun app3 f = let fun loop (a::b,c::d,e::r) = (f(a,c,e); loop(b,d,r))
				| loop _ = ()
			  in loop
			  end
	 in app3(fn (v,s,z)=> nsave(v,s + savings + (z-s) div len)) (vl,sl,zl);
	    overhead+branches
	 end

     and pass1 = 
      fn RECORD(vl,w,e) =>
	  (app (escape o #1) vl; noterec(w,vl,length vl); 2 + length vl + pass1 e)
       | SELECT (i,v,w,e) => (notesel(i,v,w); 1 + pass1 e)
       | APP(f,vl) => (call(f,length vl); app escapeargs vl; 1 + length vl)
       | FIX(l, e) => 
	    (app enter l; 
             sum (fn (f,_,e) => setsize(f, pass1 e)) l + length l + pass1 e)
       | SWITCH(v,el) => let val len = length el
			     val jumps = 4 + len
		             val branches = sum pass1 el
			  in save(v, (branches*(len-1)) div len + jumps);
			     jumps+branches
			 end
       | PRIMOP(args as (P.boxed,_,_,_)) => prim args
       | PRIMOP(args as (P.<,_,_,_)) => prim args
       | PRIMOP(args as (P.<=,_,_,_)) => prim args
       | PRIMOP(args as (P.>,_,_,_)) => prim args
       | PRIMOP(args as (P.>=,_,_,_)) => prim args
       | PRIMOP(args as (P.ieql,_,_,_)) => prim args
       | PRIMOP(args as (P.ineq,_,_,_)) => prim args
       | PRIMOP(args as (P.*,_,_,_)) => prim args
       | PRIMOP(args as (P.div,_,_,_)) => prim args
       | PRIMOP(args as (P.+,_,_,_)) => prim args
       | PRIMOP(args as (P.-,_,_,_)) => prim args
       | PRIMOP(args as (P.rshift,_,_,_)) => prim args
       | PRIMOP(args as (P.slength,_,_,_)) => prim args
       | PRIMOP(args as (P.ordof,_,_,_)) => prim args
       | PRIMOP(args as (P.~,_,_,_)) => prim args
       | PRIMOP(args as (P.lshift,_,_,_)) => prim args
       | PRIMOP(args as (P.orb,_,_,_)) => prim args
       | PRIMOP(args as (P.xorb,_,_,_)) => prim args
       | PRIMOP(args as (P.notb,_,_,_)) => prim args
       | PRIMOP(args as (P.andb,_,_,_)) => prim args
       | PRIMOP(_,vl,wl,el) =>
	 (app escape vl; length vl + length wl + sum pass1 el)

     fun substitute(args,wl,e) =
      let exception Alpha
          val vm : lvar Intmap.intmap = Intmap.new(16, Alpha)
          fun use v = Intmap.map vm v handle Alpha => v
          fun def v = let val w = dupLvar v 
		      in Intmap.add vm (v,w); w
		      end
	  fun bind(a::args,w::wl) = (Intmap.add vm (w,a); bind(args,wl))
	    | bind _ = ()
          val rec g =
         fn RECORD(vl,w,ce) => RECORD(map (map1 use) vl, def w, g ce)
          | SELECT(i,v,w,ce) => SELECT(i, use v, def w, g ce)
          | APP(v,vl) => APP(use v, map use vl)
          | FIX(l,ce) => 
	    let fun h1(f,vl,e) = (f,def f, vl, e)
		fun h2(f,f',vl,e) =
		    let val vl' = map def vl
			val e'= g e
		    in (f', vl', e')
		    end
	     in FIX(map h2(map h1 l), g ce)
	    end
          | SWITCH(v,l) => SWITCH(use v, map g l)
          | PRIMOP(i,vl,wl,ce) => PRIMOP(i, map use vl, map def wl, map g ce)
      val cexp = (bind(args,wl); g e)
      in debugprint(makestring(pass1 cexp)); debugprint " "; cexp
      end
		
     fun beta(n, d, e) = case e
      of RECORD(vl,w,ce) => RECORD(vl, w, beta(n,d+2+length vl, ce))
       | SELECT(i,v,w,ce) => SELECT(i, v, w, beta(n,d+1, ce))
       | APP(v,vl) => 
	   ((case get v
	     of Fun{escape,call,size,args,body} =>
		let val size = !size
		    fun whatsave(acc, v::vl, a::al) =
			if acc>=size
			then acc
			else
			(case get a of
			   Arg{escape=ref esc,savings=ref save,record=ref rl} =>
                           let val (this,nvl,nal) =
			       if (Intmap.map ctab v; true) handle Ctable => false
			       then (save,vl,al)
			       else (case get v of
			               Fun{escape=ref 1,...} =>
                                         (if esc>0 then save else 6+save,vl,al)
				     | Fun _ => (save,vl,al)
				     | Rec{escape=ref ex,vars,size} =>
				       let fun loop([],nvl,nal) = 
					       (if ex>1 orelse esc>0
					        then save
						else save+size+2,nvl,nal)
					     | loop((i,w)::rl,nvl,nal) =
					       (case nth(vars,i) of
					          (v,OFFp 0) =>
						         loop(rl,v::nvl,w::nal)
						| _ => loop(rl,nvl,nal))
				       in loop(rl,vl,al)
				       end
                                     | _ => (0,vl,al)) handle Expand => (0,vl,al)
			   in whatsave(acc + this - (acc*this) div size, nvl,nal)
			   end
			 | Sel{savings=ref save} =>
                           let val this =
			       if (Intmap.map ctab v; true) handle Ctable => false
			       then save
			       else (case get v of
				       Fun _ => save
				     | Rec _ => save
                                     | _ => 0) handle Expand => 0
			   in whatsave(acc + this - (acc*this) div size, vl,al)
			   end)
		      | whatsave(acc, nil,nil) = acc
		  val predicted = (size-whatsave(0,vl,args))-(1+length vl)
                  val depth = 1
		  val max = 5
		  val increase = (bodysize*(depth - n)) div depth
	     in if (predicted <= increase
		    orelse (case vl of
			      [_] => !call = 2 andalso
				     2*predicted - (size+1) <= increase
			    | _ => false))
		    andalso (n <= max orelse (debugprint "n>";
			   		      debugprint(makestring max);
					      debugprint "\n"; false))
		then (click ""; beta(n+1, d+1, substitute(vl,args,body)))
		else e
	    end
	    | _ => e) handle Expand => e)
       | FIX(l,ce) => let fun h(f,vl,e) = 
			     case get f
			      of Fun{escape=ref 0,...} => (f,vl, beta(n,0,e))
			       | _ => (f,vl,e)
		       in FIX(if n<1 then map h l else l, 
			      beta(n,d+length l, ce))
		      end
       | SWITCH(v,l) => SWITCH(v, map (fn e => beta(n,d+2,e)) l)
       | PRIMOP(i,vl,wl,ce) => PRIMOP(i, vl, wl, map (fn e => beta(n,d+2,e)) ce)

    in debugprint("\nExpand ("); debugprint(makestring(pass1 cexp));
       debugprint("): "); debugflush();
       beta(0,0,cexp)
   end

  val bodysize = !System.Control.CG.bodysize
  val reducemore = !System.Control.CG.reducemore
  val rounds = !System.Control.CG.rounds

  val cexp = (debugprint "Eta:"; debugflush(); eta cexp)
  val cexp = if rounds>0 
	       then(debugprint "\nInvEta:"; debugflush(); invEta cexp)
               else cexp

  fun contracter last cexp =
	 let val cexp = (clicked := 0; contract last cexp)
	  in if !clicked <= !System.Control.CG.reducemore
		      then cexp else contracter last cexp
	 end

  fun cycle(0,cexp,size) = contract true cexp
    | cycle(k,cexp,size) = 
	let val cexp = if !System.Control.CG.hoist 
			then (debugprint "\nHoist: "; hoist cexp) else cexp
	    val _ = clicked := 0
	    val cexp = expand(cexp,size)
	    val cl = !clicked before clicked := 0
        in if cl <= reducemore
	   then contract true cexp
	   else cycle(k-1, contract false cexp, size-(bodysize div rounds))
	end
in if rounds>0 then cycle(rounds,contracter false cexp, bodysize)
   else contracter true cexp
   before (debugprint "\n"; debugflush())
end
end
