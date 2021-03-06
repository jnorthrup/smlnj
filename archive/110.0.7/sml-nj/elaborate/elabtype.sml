(* elabtype.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

(* elabtype.sml *)

structure ElabType : ELABTYPE =
struct

local structure EM = ErrorMsg
      structure S  = Symbol
      structure SP = SymPath
      structure IP = InvPath
      structure SE = StaticEnv
      structure L  = Lookup
      structure B  = Bindings
      structure T  = Types
      structure TU = TypesUtil
      structure BT = BasicTypes
      structure EU = ElabUtil
      structure TS = TyvarSet
      open Symbol Absyn Ast PrintUtil Types TypesUtil VarCon
in

val debugging = Control.CG.etdebugging (* ref false *)
val say = Control.Print.say
fun debugmsg (msg: string) =
    if !debugging then (say msg; say "\n") else ()

fun bug msg = ErrorMsg.impossible("ElabType: "^msg)

(**** TYPES ****)

val --> = BT.-->
infix -->

fun elabTyv(tyv:Ast.tyvar,error,region:region)  =
    case tyv
     of Tyv vt => mkTyvar(mkUBOUND(vt))
      | MarkTyv(tyv,region) => elabTyv(tyv,error,region)

fun elabTyvList (tyvars,error,region) =
  let val tvs = map (fn tyv => elabTyv(tyv,error,region)) tyvars
      val names = map (fn (ref(UBOUND{name,...})) => name
                        | _ => bug "elabTyvList") tvs
   in EU.checkUniq((error region),"duplicate type variable name",names);
      tvs
  end

fun elabType(ast:Ast.ty,env:SE.staticEnv,error,region:region)
            : (Types.ty * TS.tyvarset) =
     case ast
      of VarTy vt => 
	   let val tyv = elabTyv(vt,error,region)
	    in (VARty tyv, TS.singleton tyv)
	   end
       | ConTy (co,ts) => 
	   let val co1 = 
		   if (S.name (hd co)) = "->"
		   then BT.arrowTycon
		   else L.lookArTyc(env,SP.SPATH co,length ts,error region)
	       val (lts1,lvt1) = elabTypeList(ts,env,error,region)
	    in (mkCONty (co1,lts1),lvt1)
	   end
       | RecordTy lbs => 
	   let val (lbs1,lvt1) = elabTLabel(lbs,env,error,region)
	    in (BT.recordTy(EU.sortRecord(lbs1,error region)),lvt1)
	   end
       | TupleTy ts =>
	   let val (lts1,lvt1) = elabTypeList(ts,env,error,region)
	    in (BT.tupleTy lts1,lvt1)
	   end
       | MarkTy (ty,region) => elabType(ty,env,error,region)

and elabTLabel(labs,env,error,region:region) =
    foldr 
      (fn ((lb2,t2),(lts2,lvt2)) => 
	  let val (t3,lvt3) = elabType(t2,env,error,region)
	   in ((lb2,t3) :: lts2, TS.union(lvt3,lvt2,error region))
	  end)
      ([],TS.empty) labs

and elabTypeList(ts,env,error,region:region) =
    foldr 
      (fn (t2,(lts2,lvt2)) => 
	  let val (t3,lvt3) = elabType(t2,env,error,region)
	   in (t3 :: lts2, TS.union(lvt3,lvt2,error region))
	  end)
      ([],TS.empty) ts


(**** DATACON DECLARATIONS ****)
exception ISREC

fun elabDB((args,name,def,region),env,rpath:IP.path,error) =
   let val rhs = mkCONty(L.lookArTyc (env,SP.SPATH[name],length args,
                                      error region),
		         map VARty args)

       fun checkrec(_,NONE) = ()
         | checkrec(_,SOME typ) = 
	     let fun findname(VarTy _) = ()
		   | findname(ConTy([co],ts)) = 
                       if co = name then (raise ISREC) 
		       else app findname ts
		   | findname(ConTy(_,ts)) = app findname ts
		   | findname(RecordTy lbs) = app (fn (_,t) => findname t) lbs
		   | findname(TupleTy ts) = app findname ts
		   | findname(MarkTy(t,_)) = findname t

	      in findname(typ)
	     end

	fun elabConstr (name,SOME ty) =
	      let val (t,tv) = elabType(ty,env,error,region)
	       in ((name,false,(t --> rhs)),tv)
	      end
	  | elabConstr (name,NONE) = ((name,true,rhs),TS.empty)

	val arity = length args
	val isrec = (app checkrec def; false) handle ISREC => true
	val (dcl,tvs) = 
	      foldr
		(fn (d,(dcl1,tvs1)) =>
		   let val (dc2,tv2) = elabConstr d
		    in (dc2::dcl1,TS.union(tv2,tvs1,error region))
		   end)
		([],TS.empty) def
	val _ = EU.checkBoundTyvars(tvs,args,error region)
	val _ = TU.bindTyvars args
	val sdcl = EU.sort3 dcl
	val (reps, sign) = ConRep.infer isrec sdcl
	fun bindDcons ((sym,const,typ),rep) =
	      let val _ = TU.compressTy typ
		  val typ = 
		      if arity > 0
		      then POLYty {sign=mkPolySign arity,
				   tyfun=TYFUN{arity=arity,body=typ}}
		      else typ
	       in DATACON{name=sym, const=const, rep=rep,
                          sign=sign, typ=typ}
	      end
	fun bindDconslist ((r1 as (name,_,_))::l1,r2::l2) =
	      let val dcon = bindDcons (r1,r2)
		  val (dcl,e2) = bindDconslist (l1,l2)
	       in (dcon::dcl,Env.bind(name,B.CONbind dcon,e2))
	      end
	  | bindDconslist ([],[]) = ([],SE.empty)
	  | bindDconslist _ = bug "elabDB.bindDconslist"

     in if length sdcl < length dcl  (* duplicate constructor names *)
	then let fun member(x:string,[]) = false
		   | member(x,y::r) = (x = y) orelse member(x,r)
		 fun dups([],l) = l
		   | dups(x::r,l) =
		       if member(x,r) andalso not(member(x,l))
		       then dups(r,x::l)
		       else dups(r,l)
		 fun add_commas [] = []
		   | add_commas (y as [_]) = y
		   | add_commas (s::r) = s :: "," :: add_commas(r)
		 val duplicates = dups(map (fn (n,_,_) => S.name n) dcl,[])
	      in error region EM.COMPLAIN
		   (concat["datatype ", S.name name,
			    " has duplicate constructor name(s): ",
			    concat(add_commas(duplicates))])
		   EM.nullErrorBody
	     end
	else ();
	bindDconslist(sdcl, reps)
    end


(**** TYPE DECLARATIONS ****)

fun elabTBlist(tbl:Ast.tb list,notwith:bool,env0,rpath,region,
	       {mkStamp,error,...}: EU.compInfo)
      : T.tycon list * S.symbol list * SE.staticEnv =
    let fun elabTB(tb: Ast.tb, env, region): (T.tycon * symbol) =
	    case tb
	      of Tb{tyc=name,def,tyvars} =>
		   let val tvs = elabTyvList(tyvars,error,region)
		       val (ty,tv) = elabType(def,env,error,region)
		       val arity = length tvs
		       val _ = EU.checkBoundTyvars(tv,tvs,error region)
		       val _ = TU.bindTyvars tvs
		       val _ = TU.compressTy ty
		       val tycon = 
			   DEFtyc{stamp=mkStamp(),
				  path=InvPath.extend(rpath,name),
				  strict=EU.calc_strictness(arity,ty),
				  tyfun=TYFUN{arity=arity, body=ty}}
		    in (tycon,name)
		   end
	      | MarkTb(tb',region') => elabTB(tb',env,region')
	fun loop(nil,tycons,names,env) = (rev tycons,rev names,env)
	  | loop(tb::rest,tycons,names,env) =
	      let val env' = if notwith then env0 else Env.atop(env,env0)
		  val (tycon,name) = elabTB(tb,env',region)
	       in loop(rest,tycon::tycons,name::names,
		       Env.bind(name,B.TYCbind tycon,env))
	      end
     in loop(tbl,nil,nil,SE.empty)
    end

fun elabTYPEdec(tbl: Ast.tb list,env,rpath,region,
		compInfo as {error,mkStamp,...}: EU.compInfo)
      : Absyn.dec * SE.staticEnv =
    let	val _ = debugmsg ">>elabTYPEdec"
	val (tycs,names,env') =
            elabTBlist(tbl,true,env,rpath,region,compInfo)
	val _ = debugmsg "--elabTYPEdec: elabTBlist done"
     in EU.checkUniq(error region, "duplicate type definition", names);
	debugmsg "<<elabTYPEdec";
        (TYPEdec tycs, env')
    end

fun elabDATATYPEdec({datatycs,withtycs},env0,sigContext,sigEntEnv,rpath,region,
		    compInfo as {mkStamp,error,...}: EU.compInfo) =
    let (* predefine datatypes *)
	val _ = debugmsg ">>elabDATATYPEdec"

	fun preprocess region (Db{tyc=name,rhs=Constrs def,tyvars}) = 
	    SOME
	     {tvs=elabTyvList(tyvars,error,region),
	      name=name,def=def,region=region, 
	      tyc=GENtyc{path=IP.extend(rpath,name),
			 arity=length tyvars,
			 stamp=mkStamp(),
			 eq=ref DATA,kind=TEMP}}
	  | preprocess region (Db{tyc=name,rhs=Repl syms,tyvars}) = 
	     (error region EM.COMPLAIN
	       ("datatype replication mixed with regular datatypes:" ^ S.name name)
	       EM.nullErrorBody;
	      NONE)
	  | preprocess _ (MarkDb(db',region')) = preprocess region' db'

        val dbs = List.mapPartial (preprocess region) datatycs
        val _ = debugmsg "--elabDATATYPEdec: preprocessing done"

        val envDTycs = (* staticEnv containing preliminary datatycs *)
	    foldl (fn ({name,tyc,...},env) => SE.bind(name, B.TYCbind tyc, env))
	          SE.empty dbs
        val _ = debugmsg "--elabDATATYPEdec: envDTycs defined"

	(* elaborate associated withtycs *)
	val (withtycs,withtycNames,envWTycs) = 
	    elabTBlist(withtycs,false,SE.atop(envDTycs,env0),
		       rpath,region,compInfo)
        val _ = debugmsg "--elabDATATYPEdec: withtycs elaborated"

	(* check for duplicate tycon names *)
        val _ = EU.checkUniq(error region,
			     "duplicate type names in type declaration",
			     map #name dbs @ withtycNames);
        val _ = debugmsg "--elabDATATYPEdec: uniqueness checked"
	
	(* staticEnv containing only new datatycs and withtycs *)
	val envTycs = SE.atop(envWTycs, envDTycs)
	(* staticEnv for evaluating the datacon types *)
	val fullEnv = SE.atop(envTycs,env0)
        val _ = debugmsg "--elabDATATYPEdec: envTycs, fullEnv defined"

        val prelimDtycs = map #tyc dbs

	fun transTyc (tyc as GENtyc{kind=TEMP,...}) =
	    let fun trans(tyc,i,x::rest) =
		      if eqTycon(tyc,x) then RECtyc i
		      else trans(tyc,i+1,rest)
		  | trans(tyc,_,nil) = tyc
	     in trans(tyc,0,prelimDtycs)
	    end
	  | transTyc tyc = tyc

	fun transType t = 
	    case TU.headReduceType t
	      of CONty(tyc, args) =>
		   CONty(transTyc tyc,map transType args)
	       | POLYty{sign,tyfun=TYFUN{arity,body}} =>
		   POLYty{sign=sign,
			  tyfun=TYFUN{arity=arity,body=transType body}}
	       | t => t

	(* elaborate the definition of a datatype *)
	fun elabRHS ({tvs,name,def,region,tyc}, (i,done)) = 
	    let val (datacons,_) = 
                      elabDB((tvs,name,def,region),fullEnv,rpath,error)
		fun mkDconDesc (DATACON{name,const,rep,sign,typ}) = 
		    {name=name, rep=rep,
		     domain=
		       if const then NONE
		       else case transType typ
			      of CONty(_,[dom,_]) => SOME dom
                               | POLYty{tyfun=TYFUN{body=CONty(_,[dom,_]),...},
					...} => SOME dom
			       | _ => bug "elabRHS"}
	     in (i+1,
		 {name=name,
		  dconNames=map (fn DATACON{name,...} => name) datacons,
		    (* duplicate names removed *)
		  dcons=datacons,
		  dconDescs=map mkDconDesc datacons,
		  tyc=tyc,
		  index=i} :: done)
	    end
 
        val (_,dbs') = foldl elabRHS (0,nil) dbs
	val dbs' = rev dbs'
        val _ = debugmsg "--elabDATATYPEdec: RHS elaborated"

        fun mkMember{name,dcons,dconDescs,tyc=GENtyc{stamp,arity,eq,...},
		     dconNames,index} =
	    let val DATACON{sign,...}::_ = dcons
		     (* extract common sign from first datacon *)
	     in {tycname=name,stamp=stamp,dcons=dconDescs,arity=arity,
                 eq=eq,sign=sign,lambdatyc=ref NONE}
	    end

        val members = map mkMember dbs'

        val _ = debugmsg "--elabDATATYPEdec: members defined"

        fun fixDtyc{name,index,tyc as GENtyc{path,arity,stamp,eq,kind},
		    dconNames,dcons,dconDescs} =
	    {old=tyc,
	     name=name,
	     new=GENtyc{path=path,arity=arity,stamp=stamp,
			eq=eq,kind=DATATYPE{index=index,members=Vector.fromList members,
                                            lambdatyc=ref NONE}}}

        val dtycmap = map fixDtyc dbs'  (* maps prelim to final datatycs *)
        val _ = debugmsg "--elabDATATYPEdec: fixDtycs done"

	val finalDtycs = map #new dtycmap
        val _ = debugmsg "--elabDATATYPEdec: finalDtycs defined"

        val _ = EqTypes.defineEqProps(finalDtycs,sigContext,sigEntEnv)
        val _ = debugmsg "--elabDATATYPEdec: defineEqProps done"


        fun applyMap m =
            let fun sameTyc(GENtyc{stamp=s1,...},GENtyc{stamp=s2,...}) 
                                     = Stamps.eq(s1,s2)
                  | sameTyc(tyc1 as DEFtyc _, tyc2 as DEFtyc _) 
                                     = equalTycon(tyc1, tyc2)  
                  | sameTyc _ = false

                fun f(CONty(tyc, args)) =
	              let fun look({old,new,name}::rest) = 
			      if sameTyc(old,tyc) then new else look rest
			    | look nil = tyc
		       in CONty(look m, map (applyMap m) args)
		      end
		  | f (POLYty{sign,tyfun=TYFUN{arity,body}}) =
		      POLYty{sign=sign,tyfun=TYFUN{arity=arity,body=f body}}
		  | f t = t
             in f
            end

        fun augTycmap (tyc as DEFtyc{tyfun=TYFUN{arity,body},stamp,
                                     strict,path}, tycmap) =
            {old=tyc,name=IP.last path,
	     new=DEFtyc{tyfun=TYFUN{arity=arity,body=applyMap tycmap body},
			strict=strict,stamp=stamp,path=path}}
	    :: tycmap

        (* use foldr to preserve the order of the withtycs [dbm] *)
        (* foldr is wrong! because withtycs will then be processed in the
           reverse order. Notice that tycons in later part of withtycs
           may refer to tycons in the earlier part of withtycs (ZHONG)
         *)
        val alltycmap = (* foldr *) foldl augTycmap dtycmap withtycs
        val _ = debugmsg "--elabDATATYPEdec: alltycmap defined"

        fun header(_, 0, z) = z
          | header(a::r, n, z) = if n > 0 then header(r, n-1, a::z)
                                 else bug "header1 in elabDATATYPEdec"
          | header([], _, _) = bug "header2 in elabDATATYPEdec"

	val finalWithtycs = map #new (header(alltycmap,length withtycs,[]))
        val _ = debugmsg "--elabDATATYPEdec: finalWithtycs defined"

        fun fixDcon (DATACON{name,const,rep,sign,typ}) = 
	    DATACON{name=name,const=const,rep=rep,sign=sign,
		    typ=applyMap alltycmap typ}

        val finalDcons = List.concat(map (map fixDcon) (map #dcons dbs'))
        val _ = debugmsg "--elabDATATYPEdec: finalDcons defined"

        val envDcons = foldl (fn (d as DATACON{name,...},e)=>
			         SE.bind(name,B.CONbind d, e))
	                     SE.empty 
	                     finalDcons
        
        val finalEnv = foldr (fn ({old,name,new},e) =>
			         SE.bind(name,B.TYCbind new,e)) 
	                     envDcons alltycmap

        val _ = debugmsg "--elabDATATYPEdec: envDcons, finalEnv defined"

     in EU.checkUniq
          (error region, "duplicate datacon names in datatype declaration",
	   List.concat(map #dconNames dbs'));
        debugmsg "<<elabDATATYPEdec";
	(finalDtycs,finalWithtycs,finalDcons,finalEnv)
    end (* fun elabDATATYPEdec0 *)

(*
fun elabDATATYPEdec({datatycs,withtycs},env0,sigContext,sigEntEnv,rpath,region,
		    compInfo as {error,...}: EU.compInfo) =
    case datatycs
      of ((Db{rhs=(Constrs _), ...}) :: _) => 
	   elabDATATYPEdec0({datatycs=datatycs,withtycs=withtycs},env0,
			    sigContext,sigEntEnv,rpath,region,compInfo)
       | (Db{tyc=name,rhs=Repl syms,tyvars=nil}::nil) =>
	  (case withtycs
	     of nil =>
		  let val tyc = L.lookTyc(env0, SP.SPATH syms, error region)
		      val dcons = extractDcons tyc
		      val envDcons =
			   foldl (fn (d as DATACON{name,...},e)=>
					    SE.bind(name,B.CONbind d, e))
			         SE.empty 
				 dcons
		      val env = SE.bind(name,B.TYCbind tyc,envDcons)
		   in ([tyc],[],dcons,env)
		  end 
	      | _ => (error region EM.COMPLAIN
		      "ill-formed datatype replication - withtype" EM.nullErrorBody;
		      ([],[],[],SE.empty)))
       | _ => (error region EM.COMPLAIN
	        "ill-formed datatype replication - arguments" EM.nullErrorBody;
	       ([],[],[],SE.empty))
*)

(*
val elabDATATYPEdec = 
  Stats.doPhase (Stats.makePhase "Compiler 032 7-elabDataTy") elabDATATYPEdec
*)
end (* local *)
end (* structure ElabType *)


(*
 * $Log: elabtype.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:45  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.9.2.1  1998/08/19 18:20:54  dbm
 * bug fixes for 110.9 [dbm]
 *
 * Revision 1.9  1997/11/07 05:41:45  dbm
 *   Fixed checking for multiple occurrences of a dataconstructor name
 *   across a family of mutually recursive datatype declarations to
 *   avoid redundant error messages.
 *
 * Revision 1.8  1997/11/04  23:30:00  dbm
 *   Removed redundant check for uniqueness of dataconstructor names.
 *
 * Revision 1.7  1997/09/05  04:41:00  dbm
 *   Changes in TyvarSet signature; TyvarSet not opened (bug 1244).
 *
 * Revision 1.6  1997/07/17  20:38:53  dbm
 *   Cleaned out unnecessary imports.
 *
 * Revision 1.5  1997/04/15  22:21:46  dbm
 *   Fix for bug 1191.  A single "sign" value was being used for a whole
 *   datatype family, instead of a separate sign per datatype, common to
 *   all the datacons of that datatype.
 *
 * Revision 1.4  1997/03/22  18:14:32  dbm
 * Change in treatment of UBOUND type variables for bug 905/952 fix.
 *
 * Revision 1.3  1997/03/17  18:49:47  dbm
 * Changes in datatype representation to support datatype replication.
 *
 * Revision 1.2  1997/02/26  15:36:39  dbm
 * Fix bug 1141.  Added entityEnv parameter to elabDATATYPEdec so it could be
 * passed on at the call of defineEqProps.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:35  george
 *   Version 109.24
 *
 *)
