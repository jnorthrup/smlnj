(* Copyright 1996 by AT&T Bell Laboratories *)
(* eqtypes.sml *)

(*
 * This file probably should not belong here ! It relies on the module
 * semantics; and probably it should be moved to modules/ directory. (ZHONG)  
 *)

signature EQTYPES =
sig

  val eqAnalyze : Modules.Structure * (Stamps.stamp -> bool) 
                                    * ErrorMsg.complainer -> unit

  val defineEqProps : Types.tycon list * ExpandTycon.sigContext
                      * EntityEnv.entityEnv -> unit
  val checkEqTySig : Types.ty * Types.polysign -> bool
  val isEqTycon : Types.tycon -> bool
  val isEqType : Types.ty -> bool
  val debugging : bool ref

end (* signature EQTYPES *)


structure EqTypes : EQTYPES =
struct

(* functions to determine and check equality types *)
local structure EM = ErrorMsg
      structure IP = InvPath
      structure TU = TypesUtil
      structure M = Modules
      structure MU = ModuleUtil
      open Types Stamps TypesUtil

in 

(* debugging *)
fun bug msg = EM.impossible("EqTypes: "^msg)
val say = Control.Print.say
val debugging = ref false
fun debugmsg (msg: string) =
    if !debugging then (say msg; say "\n") else ()

fun all (f: 'a -> bool) [] = true
  | all f (x::r) = f x andalso all f r

(* join of eqprops *)
exception INCONSISTENT

fun join(UNDEF,YES) = YES
  | join(YES,UNDEF) = YES
  | join(UNDEF,NO) = NO
  | join(NO,UNDEF) = NO
  | join(UNDEF,IND) = IND
  | join(IND,UNDEF) = IND
  | join(UNDEF,DATA) = DATA
  | join(DATA,UNDEF) = DATA
  | join(UNDEF,UNDEF) = UNDEF
  | join(DATA,YES) = YES
  | join(YES,DATA) = YES
  | join(DATA,NO) = NO
  | join(NO,DATA) = NO
  | join(DATA,IND) = IND
  | join(IND,DATA) = IND
  | join(DATA,DATA) = DATA
  | join(IND,YES) = YES (* ? *)
  | join(YES,IND) = YES (* ? *)
  | join(IND,NO) = NO
  | join(NO,IND) = NO
  | join(IND,IND) = IND
  | join(YES,YES) = YES
  | join(NO,NO) = NO
  | join(OBJ,OBJ) = OBJ
  | join(ABS,e) = join(NO,e)
  | join(e,ABS) = join(e,NO)
  | join(e1,e2) = 
     (say(String.concat[TU.eqpropToString e1,",",TU.eqpropToString e2,"\n"]);
      raise INCONSISTENT)

fun objectTyc(GENtyc{eq=ref OBJ,...}) = true
  | objectTyc _ = false

(* calculating eqtypes in toplevel signatures *)

exception NOT_EQ
exception UnboundStamp

(* 
 * eqAnalyze is called in just one place, in Instantiate, to compute the 
 * actual eqprops of types in an instantiated signature.  It has to propagate 
 * equality properties to respect type equivalences induced by sharing 
 * constraints. 
 *)

fun eqAnalyze(str,localStamp : Stamps.stamp -> bool,err : EM.complainer) =
let val tycons: tycon list stampMap = newMap UnboundStamp
    val depend: stamp list stampMap = newMap UnboundStamp
    val dependr: stamp list stampMap = newMap UnboundStamp
    val eqprop: eqprop stampMap = newMap UnboundStamp
    val dependsInd = ref false
    val tycStampsRef : stamp list ref = ref nil

    fun applyMap' x = applyMap x handle UnboundStamp => []
    fun applyMap'' x = applyMap x handle UnboundStamp => UNDEF

    val err = fn s => err EM.COMPLAIN s EM.nullErrorBody

    fun checkdcons(datatycStamp: stamp,
		   evalty: ty -> ty,
		   dcons: dconDesc list,
		   members) : (eqprop * stamp list) =
	let val depend = ref([]: stamp list)
	    val dependsInd = ref false
	    fun member(stamp,[]) = false
	      | member(st,st'::rest) = Stamps.eq(st,st') orelse member(st,rest)
	    fun eqtyc(tyc as GENtyc{stamp,eq,...}) =
		(case !eq
		   of YES => ()
		    | OBJ => ()
		    | (NO | ABS) => raise NOT_EQ
		    | IND => dependsInd := true
		    | (DATA | UNDEF) =>
			if member(stamp,!depend) 
			    orelse Stamps.eq(stamp,datatycStamp) then ()
			else depend := stamp :: !depend)
	      | eqtyc(RECORDtyc _) = ()
	      | eqtyc _ = bug "eqAnalyze.eqtyc"
	    and eqty(VARty(ref(INSTANTIATED ty))) 
                  = eqty ty  (* shouldn't happen *)
	      | eqty(ty as CONty(tyc,args)) =
		 (case tyc
		   of GENtyc{eq=ref OBJ,...} => ()
		    | tyc' as GENtyc _ => (eqtyc tyc'; app eqty args)
		    | DEFtyc{tyfun,...} => eqty(headReduceType ty)
		    | RECtyc i =>
		       let val {stamp,tycname,dcons,...}: dtmember =  
                                  Vector.sub(members,i)
		        in if member(stamp,!depend) 
			      orelse Stamps.eq(stamp,datatycStamp)
			   then ()
			   else depend := stamp :: !depend
		       end
		    | _ => app eqty args)
	      | eqty _ = ()
	    fun eqdcon{domain=SOME ty',name,rep} = eqty ty'
	      | eqdcon _ = ()
	 in app eqdcon dcons;
	    case (!depend,!dependsInd)
	      of ([],false) => (YES,[])
	       | (d,false) => (DATA,d)
	       | (_,true) => (IND,[])
	end
	handle NOT_EQ => (NO,[])

    fun addstr(str as M.STR{sign,rlzn={entities,...},...}) =
	let fun addtyc (tyc as (GENtyc{stamp, eq, kind, path, ...})) =
		 if localStamp stamp  (* local spec *)
		 then ((updateMap tycons (stamp,tyc::applyMap'(tycons,stamp));
                        tycStampsRef := stamp :: !tycStampsRef;
                        case kind
                         of DATATYPE{index,members,...} =>
                             let val dcons = #dcons(Vector.sub(members,index))
                                 val eqOrig = !eq
                                 val (eqpCalc,deps) =
                                   case eqOrig
                                    of DATA => 
                                       checkdcons(stamp,MU.transType entities,
                                                  dcons,members)
                                     | e => (e,[])
                                            (* ASSERT: e = YES or NO *)
                                 val eq' = join(join(eqOrig,
                                                     applyMap''(eqprop,stamp)),
                                                eqpCalc)
                              in eq := eq';
                                 updateMap eqprop (stamp,eq');
                                 app (fn s => updateMap dependr
                                     (s, stamp :: applyMap'(dependr,s))) deps;
                                 updateMap depend
                                   (stamp, deps @ applyMap'(depend,stamp))
                             end
                          | (FLEXTYC _ | ABSTRACT _ | PRIMITIVE _) =>
                              let val eq' = join(applyMap''(eqprop,stamp), !eq)
                               in eq := eq';
                                  updateMap eqprop (stamp,eq')
                              end
                          | _ => bug "eqAnalyze.scan.tscan")
                       handle INCONSISTENT => 
                                       err "inconsistent equality properties")
                 else () (* external -- assume eqprop already defined *)
              | addtyc _ = ()
	 in if localStamp(MU.getStrStamp str) then
                (List.app (fn s => addstr s) (MU.getStrs str);
                 List.app (fn t => addtyc t) (MU.getTycs str))
        (* BUG? - why can we get away with ignoring functor elements??? *)
            else ()
	end
      | addstr _ = ()   (* must be external or error structure *)

    fun propagate (eqp,depset,earlier) =
	let fun prop stamp' =
	      app (fn s =>
		       let val eqpold = applyMap''(eqprop,s)
                           val eqpnew = join(eqp,eqpold)
		        in if eqpold <> eqpnew
			   then (updateMap eqprop (s,eqp);
			         if earlier s then prop s else ())
			   else ()
		       end handle INCONSISTENT =>
	                     err "inconsistent equality properties B")
                  (depset(stamp')) 
	 in prop
	end

    (* propagate the NO eqprop forward and the YES eqprop backward *)
    fun propagate_YES_NO(stamp) =
      let fun earlier s = Stamps.cmp(s,stamp) = LESS
       in case applyMap''(eqprop,stamp)
	   of YES => 
               propagate (YES,(fn s => applyMap'(depend,s)),earlier) stamp
	    | NO => propagate (NO,(fn s => applyMap'(dependr,s)),earlier) stamp
            | _ => ()
      end

    (* propagate the IND eqprop *)
    fun propagate_IND(stamp) =
      let fun depset s = applyMap'(dependr,s)
	  fun earlier s = Stamps.cmp(s,stamp) = LESS
       in case applyMap''(eqprop,stamp)
	   of UNDEF => (updateMap eqprop (stamp,IND);
		        propagate (IND,depset,earlier) stamp)
	    | IND => propagate (IND,depset,earlier) stamp
	    | _ => ()
      end

    (* phase 0: scan signature strenv, joining eqprops of shared tycons *)
    val _ = addstr str
    val tycStamps = 
      Sort.sort (fn xy => Stamps.cmp xy = GREATER) (!tycStampsRef)
 in 
    (* phase 1: propagate YES backwards and NO forward *)
    app propagate_YES_NO tycStamps;

    (* phase 2: convert UNDEF to IND and propagate INDs *)
    app propagate_IND tycStamps;  (* convert UNDEFs to INDs and propagate *)

    (* phase 3: convert DATA to YES; reset stored eqprops from eqprop map *)
    app (fn s =>
          let val eqp = case applyMap''(eqprop,s)
			  of DATA => YES
			   | e => e
           in app (fn tyc as GENtyc{eq,...} => eq := eqp) (applyMap(tycons,s)) 
          end)
    tycStamps
end

exception CHECKEQ


(* WARNING - defineEqTycon uses eq field ref as a tycon identifier.  
   Since defineEqTycon is called only within elabDATATYPEdec, this
   should be ok.*)

val unitTy = BasicTypes.unitTy

fun member(_,[]) = false
  | member(i:int, j::rest) = i=j orelse member(i,rest)

fun namesToString ([]: Symbol.symbol list) = "[]"
  | namesToString (x::xs) =
    String.concat("[" :: (Symbol.name x) ::
		  foldl (fn (y,l) => ","::(Symbol.name y)::l) ["]"] xs)

fun defineEqProps (datatycs,sigContext,sigEntEnv) = 
    let val names = map TU.tycName datatycs
	val _ = debugmsg (">>defineEqProps: "^ namesToString names)
	val n = List.length datatycs
	val GENtyc{kind=DATATYPE{members,...},...}::_ = datatycs
	val eqs = map (fn GENtyc{eq,...} => eq) datatycs
	fun getEq i = !(List.nth(eqs,i))
handle Subscript => (say "$getEq "; say(Int.toString i); say " from ";
		     say(Int.toString(length eqs)); say "\n";
		     raise Subscript)
	fun setEq(i,eqp) =
	    (debugmsg (String.concat["setEq: ",Int.toString i," ",
				     TU.eqpropToString eqp]);
	     (List.nth(eqs,i) := eqp)
	     handle Subscript =>
	      (say (String.concat["$setEq ",(Int.toString i)," from ",
				  (Int.toString(length eqs)),"\n"]);
	       raise Subscript))
	val visited = ref([]: int list)

     fun checkTyc (tyc0 as GENtyc{eq as ref DATA,kind=DATATYPE{index,...},path,
			     ...}) =
       let val _ = debugmsg (">>checkTyc: "^Symbol.name(IP.last path)^" "^
				  Int.toString index)
	 fun eqtyc(GENtyc{eq=ref DATA,kind=DATATYPE{index,...},path,...}) =
	      (debugmsg ("eqtyc[GENtyc(DATA)]: " ^ Symbol.name(IP.last path) ^
				 " " ^ Int.toString index);
		       (* ASSERT: argument tycon is a member of datatycs *)
		       checkDomains index)
	   | eqtyc(GENtyc{eq=ref UNDEF,path,...}) =
	      (debugmsg ("eqtyc[GENtyc(UNDEF)]: " ^ Symbol.name(IP.last path));
		       IND)
	  | eqtyc(GENtyc{eq=ref eqp,path,...}) =
		  (debugmsg ("eqtyc[GENtyc(_)]: " ^ Symbol.name(IP.last path) ^
				 " " ^ TU.eqpropToString eqp);
		       eqp)
	  | eqtyc(RECtyc i) = 
		      (debugmsg ("eqtyc[RECtyc]: " ^ Int.toString i);
		       checkDomains i)
	  | eqtyc(RECORDtyc _) = YES
	  | eqtyc(ERRORtyc) = IND
	  | eqtyc(PATHtyc _) = bug "eqtyc - PATHtyc"
	  | eqtyc(DEFtyc _) = bug "eqtyc - DEFtyc"

	and checkDomains i =
	    if member(i,!visited) then getEq i
	    else let val _ = visited := i :: !visited
		     val {tycname,stamp,dcons,...} : dtmember
                           = Vector.sub(members,i)
                           handle Subscript => 
               (say (String.concat["$getting member ",Int.toString i," from ",
					Int.toString(Vector.length members),"\n"]);
		     raise Subscript)
			     val _ = debugmsg("checkDomains: visiting "
					      ^ Symbol.name tycname ^ " "
					      ^ Int.toString i)
			     val domains = 
				   map (fn {domain=SOME ty,name,rep} => ty
					 | {domain=NONE,name,rep} => unitTy)
				       dcons
			     val eqp = eqtylist(domains)
			  in setEq(i,eqp);
			     debugmsg ("checkDomains: setting "^Int.toString i^
				       " to "^TU.eqpropToString eqp);
			     eqp
			 end

	and eqty(VARty(ref(INSTANTIATED ty))) =   (* shouldn't happen *)
		      eqty ty
		  | eqty(CONty(tyc,args)) =
		      (case ExpandTycon.expandTycon(tyc,sigContext,sigEntEnv)
			 of DEFtyc{tyfun,...} =>
			     (* shouldn't happen - type abbrevs in domains
			      * should have been expanded *)
			     eqty(applyTyfun(tyfun,args))
			  | tyc => 
			     (case eqtyc tyc
				of (NO | ABS) => NO
				 | OBJ => YES
				 | YES => eqtylist(args)
				 | DATA =>
				  (case eqtylist(args) of YES => DATA | e => e)
				 | IND => IND
				 | UNDEF => 
				    bug ("defineEqTycon.eqty: UNDEF - " ^
					 Symbol.name(TU.tycName tyc))))
		  | eqty _ = YES

		and eqtylist(tys) =
		    let fun loop([],eqp) = eqp
			  | loop(ty::rest,eqp) =
			      case eqty ty
				of (NO | ABS) => NO  (* return NO immediately;
					      no further checking *)
				 | YES => loop(rest,eqp)
				 | IND => loop(rest,IND)
				 | DATA => 
				     (case eqp
					of IND => loop(rest,IND)
					 | _ => loop(rest,DATA))
				 | _ => bug "defineEqTycon.eqtylist"
		     in loop(tys,YES)
		    end

	     in case eqtyc tyc0
		  of YES => app (fn i =>
			          case getEq i
				   of DATA => setEq(i,YES)
				    | _ => ()) (!visited)
		   | DATA => app (fn i =>
			           case getEq i
				    of DATA => setEq(i,YES)
				     | _ => ()) (!visited)
		   | NO => app (fn i =>
			          if i > index
   			          then case getEq i
				        of IND => setEq(i,DATA)
				         | _ => ()
		                  else ()) (!visited)
		(* have to be reanalyzed, throwing away information ??? *)
		   | IND => ()
		   | _ => bug "defineEqTycon";
		(* ASSERT: eqprop of tyc0 is YES, NO, or IND *)
	     case !eq
	      of (YES | NO | IND) => ()
	      | DATA => bug ("checkTyc[=>DATA]: "^Symbol.name(IP.last path))
	      | UNDEF => bug ("checkTyc[=>other]: "^Symbol.name(IP.last path))
	    end
	  | checkTyc _ = ()
     in List.app checkTyc datatycs
    end

fun isEqType ty =
    let fun eqty(VARty(ref(INSTANTIATED ty))) = eqty ty
	  | eqty(VARty(ref(OPEN {eq,...}))) =
	      if eq then ()
	      else raise CHECKEQ
	  | eqty(CONty(DEFtyc{tyfun,...}, args)) = eqty(applyTyfun(tyfun,args))
	  | eqty(CONty(GENtyc{eq,...}, args)) =
	      (case !eq
		 of OBJ => ()
		  | YES => app eqty args
		  | (NO | ABS | IND) => raise CHECKEQ
		  | _ => bug "isEqType")
	  | eqty(CONty(RECORDtyc _, args)) = app eqty args
	  | eqty _ = ()
     in eqty ty; true
    end
    handle CHECKEQ => false

fun checkEqTySig(ty, sign: polysign) =
    let fun eqty(VARty(ref(INSTANTIATED ty))) = eqty ty
	  | eqty(CONty(DEFtyc{tyfun,...}, args)) =
	      eqty(applyTyfun(tyfun,args))
	  | eqty(CONty(GENtyc{eq,...}, args)) =
	      (case !eq
		 of OBJ => ()
		  | YES => app eqty args
		  | (NO | ABS | IND) => raise CHECKEQ
		  | _ => bug "checkEqTySig")
	  | eqty(IBOUND n) = 
	      let val eq = List.nth(sign,n)
	       in if eq then () else raise CHECKEQ
	      end
	  | eqty _ = ()
     in eqty ty;
	true
    end
    handle CHECKEQ => false

fun replicate(0,x) = nil | replicate(i,x) = x::replicate(i-1,x)

fun isEqTycon(GENtyc{eq,...}) =
      (case !eq
	 of YES => true
	  | OBJ => true
	  | _ => false)
  | isEqTycon(DEFtyc{tyfun as TYFUN{arity,...},...}) =
      isEqType(applyTyfun(tyfun,replicate(arity,BasicTypes.intTy)))
  | isEqTycon _ = bug "isEqTycon"

end (* local *)
end (* structure EqTypes *)


(*
 * $Log: eqtypes.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:36  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/03/17 18:45:14  dbm
 * Changes in datatype representation to support datatype replication.
 *
 * Revision 1.2  1997/02/26  15:29:40  dbm
 * Fix for bug 1141.  Added entityEnv parameter to defineEqProps.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:09  george
 *   Version 109.24
 *
 *)
