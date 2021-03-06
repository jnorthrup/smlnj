(* mcprint.sml
 *
 * COPYRIGHT (c) 2018 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *)

(* pretty printing for (revised old) match compiler (MC) internal structures *)

(*
signature PPMC =
sig
  val debugMsg : bool ref -> string -> unit
  val debugPrint : bool ref
                   -> (string *
		       (PrettyPrint.stream -> 'a -> unit) *
		       'a)
                   -> unit
end (* signature PPMC *)
*)

structure MCPrint =
struct

local
   structure PP = PrettyPrint
   structure PU = PPUtil
   structure LV = LambdaVar
   structure V = VarCon
   structure AS = Absyn
   open MCCommon
   structure RS = RuleSet
   open PP
   open PPUtil
in

fun bug msg = ErrorMsg.impossible ("MCPrint: " ^ msg)
val debugging = MCControl.mcdebugging

fun debugMsg (msg: string) =
    if (!debugging)
    then with_default_pp
	  (fn ppstrm =>
	    (openHVBox ppstrm (PP.Rel 0);
	     PP.string ppstrm msg;
	     closeBox ppstrm;
	     newline ppstrm;
	     PP.flushStream ppstrm))
    else ()

fun debugPrint (msg: string, printfn: PP.stream -> unit) =
    if (!debugging)
    then with_default_pp
	  (fn ppstrm =>
	    (openHVBox ppstrm (PP.Rel 0);
	     PP.string ppstrm msg;
	     newline ppstrm;
	     PP.nbSpace ppstrm 2;
	     openHVBox ppstrm (PP.Rel 0);
	     printfn ppstrm;
	     closeBox ppstrm;
	     newline ppstrm;
	     closeBox ppstrm;
	     PP.flushStream ppstrm))
    else ()

fun ppCon ppstrm (con : con) : unit =
    PP.string ppstrm (conToString con)

(*
fun ppPath ppstrm path =
    PP.string ppstrm (pathToString path)
*)
fun ppList ppstrm ppfn elems =
    ppClosedSequence ppstrm
      {front = (fn strm => PP.string strm "["),
       back =  (fn strm => PP.string strm "]"),
       sep =  (fn strm => PP.string strm ", "),
       pr = ppfn,
       style = CONSISTENT}
      elems

fun ppOption ppstrm ppfn elemOp =
    case elemOp
      of NONE => PP.string ppstrm "<<>>"
       | SOME e => (PP.string ppstrm "<< "; ppfn ppstrm e; PP.string ppstrm " >>")

fun ppExp (exp, msg) =
      PP.with_default_pp
          (fn ppstrm =>
	      (PP.string ppstrm msg;
	       PPAbsyn.ppExp (StaticEnv.empty, NONE) ppstrm (exp, 20);
	       PP.newline ppstrm))

fun ppSign ppstrm sign =
    (case sign
      of Access.CSIG(n,m) =>
	 (PP.openHBox ppstrm;
	  PP.string ppstrm "CSIG(";
	  PP.string ppstrm (Int.toString n);
	  PP.string ppstrm ",";
	  PP.string ppstrm (Int.toString m);
	  PP.string ppstrm ")";
	  PP.closeBox ppstrm)
       | Access.CNIL => PP.string ppstrm "CNIL")

fun ppVarBindings ppstrm varbindings =
    let fun ppvar ppstrm (var,ruleno) =
            (PP.openHBox ppstrm;
	     PP.string ppstrm "(";
	     PP.string ppstrm (Symbol.name (V.varName var));
	     PP.string ppstrm ",";
	     PU.pps ppstrm (Int.toString ruleno);
	     PP.string ppstrm ")";
	     PP.closeBox ppstrm)
    in PU.ppSequence ppstrm
	   {sep = (fn ppstrm => PP.break ppstrm {nsp=1,offset=0}),
	    pr = ppvar,
	    style = PU.INCONSISTENT}
	   varbindings
    end

fun ppRuleset ppstrm ruleset =
    let val rulesList = RS.listItems ruleset
    in PP.openHBox ppstrm;
       PU.pps ppstrm "{";
       PU.ppSequence ppstrm
	 {sep = (fn ppstrm => PU.pps ppstrm ","),
	  pr = (fn ppstrm => fn r => PU.pps ppstrm (Int.toString r)),
	  style = PU.INCONSISTENT}
	 rulesList;
       PU.pps ppstrm "}";
       PP.closeBox ppstrm (* openHBox *)
    end


(* ppProtoAndor : ppstrm -> protoAndor -> unit *)
(* pretty printer for protoAndor nodes *)
fun ppProtoAndor ppstrm =
    let fun ppNode ppstrm (ANDs {bindings, children}) =
	    (PP.openHOVBox ppstrm (PP.Abs 0);
	     PP.openHBox ppstrm;
             PP.string ppstrm "ANDs";
	     PP.break ppstrm {nsp=1,offset=0};
	     ppVarBindings ppstrm bindings;
	     PP.closeBox ppstrm;
	     ppAndChildren ppstrm children;
	     PP.closeBox ppstrm)
	  | ppNode ppstrm (ORs {bindings, sign, cases}) =
	    (PP.openHOVBox ppstrm (PP.Abs 0);
             PP.openHBox ppstrm;
	     PP.string ppstrm "ORs";
	     PP.break ppstrm {nsp=1,offset=0};
	     ppVarBindings ppstrm bindings;
	     PP.break ppstrm {nsp=1,offset=0};
	     ppSign ppstrm sign;
	     PP.closeBox ppstrm;
	     ppProtoVariants ppstrm cases;
	     PP.closeBox ppstrm)
	  | ppNode ppstrm (VARs {bindings}) =
	    (PP.openHBox ppstrm;
	     PP.string ppstrm "VARs";
	     PP.break ppstrm {nsp=1,offset=0};
	     ppVarBindings ppstrm bindings;
	     PP.closeBox ppstrm)

	and ppAndChildren ppstrm nodes =
	    (PP.openVBox ppstrm (PP.Abs 3);
	     PU.ppvseq ppstrm 0 "" ppNode nodes;
	     PP.closeBox ppstrm)

	and ppProtoVariants ppstrm variants =
	    (PP.openVBox ppstrm (PP.Abs 3);
	     PU.ppvseq ppstrm 0 "" ppProtoVariant variants;
	     PP.closeBox ppstrm)

	and ppProtoVariant ppstrm (con, rules, subcase) =
	    (PP.openHBox ppstrm (* (PP.Abs 0) *);
	     PP.string ppstrm (conToString con);
	     PP.break ppstrm {nsp=1,offset=0};
	     ppRuleset ppstrm rules;
	     PP.break ppstrm {nsp=1,offset=0};
	     ppSubcase ppstrm subcase;
	     PP.closeBox ppstrm)

        and ppSubcase ppstrm subcase = 
	    (case subcase
	      of CONST => PP.string ppstrm "CONST"
	       | DCON node => ppNode ppstrm node
	       | VEC _ => PP.string ppstrm "VEC") (* incomplete *) 

    in ppNode ppstrm
    end  (* fun ppSimpleAndor *)

(* ppAndor : ppstrm -> andor -> unit *)
(*  pretty printer for AND-OR nodes
 *  could develop a "path" while printing the andor tree *)
fun ppAndor ppstrm =
    let fun ppNode ppstrm (AND {id, children, ...}) =
	    (PP.openHOVBox ppstrm (PP.Abs 0);
	     PP.openHBox ppstrm;
             PP.string ppstrm "AND";
	     PP.break ppstrm {nsp=1,offset=0};
	     PP.string ppstrm (Int.toString id);
(*	     PP.break ppstrm {nsp=1,offset=0};
	     ppPath ppstrm path;
*)
	     PP.closeBox ppstrm;
	     ppAndChildren ppstrm children;
	     PP.closeBox ppstrm)
	  | ppNode ppstrm (OR {id, sign, defaults, cases, ...}) =
	    (PP.openHOVBox ppstrm (PP.Abs 0);
             PP.openHBox ppstrm;
	     PP.string ppstrm "OR";
	     PP.break ppstrm {nsp=1,offset=0};
	     PP.string ppstrm (Int.toString id);
(*	     PP.break ppstrm {nsp=1,offset=0};
	     ppPath ppstrm path;
*)
	     PP.break ppstrm {nsp=1,offset=0};
	     ppRuleset ppstrm defaults;
	     PP.break ppstrm {nsp=1,offset=0};
	     ppSign ppstrm sign;
	     PP.closeBox ppstrm; (* openHBox *)
	     ppVariants ppstrm cases;
	     PP.closeBox ppstrm) (* openHOVBox *)
	  | ppNode ppstrm (VAR {id, ...}) =
	    (PP.openHBox ppstrm;
	     PP.string ppstrm "VAR";
	     PP.break ppstrm {nsp=1,offset=0};
	     PP.string ppstrm (Int.toString id);
(*	     PP.break ppstrm {nsp=1,offset=0};
	     ppPath ppstrm path;
*)
	     PP.closeBox ppstrm)

	and ppAndChildren ppstrm nodes =
	    (PP.openVBox ppstrm (PP.Abs 3);
	     PU.ppvseq ppstrm 0 "" ppNode nodes;
	     PP.closeBox ppstrm)

	and ppVariants ppstrm variants =
	    (PP.openVBox ppstrm (PP.Abs 3);
	     PU.ppvseq ppstrm 0 "" ppVariant variants;
	     PP.closeBox ppstrm)

	and ppVariant ppstrm (con, rules, subcase) =
	    (PP.openHBox ppstrm (* (PP.Abs 0) *);
	     PP.string ppstrm (conToString con);
	     PP.break ppstrm {nsp=1,offset=0};
	     ppSubcase ppstrm subcase;
	     PP.closeBox ppstrm)

        and ppSubcase ppstrm subcase = 
	    (case subcase
	      of CONST => PP.string ppstrm "CONST"
	       | DCON node => ppNode ppstrm node
	       | VEC _ => PP.string ppstrm "VEC") (* incomplete *) 

    in ppNode ppstrm
    end (* fun ppAndor *)

(* ppDecTree : ppstrm -> decTree -> unit *)
val ppDecTree =
    let fun ppDec ppstrm (CHOICE {andor, sign, cases, default}) =
            (PP.openHBox ppstrm;
	     PP.string ppstrm "CHOICE";
	     PP.break ppstrm {nsp=1,offset=0};
	     PP.string ppstrm (Int.toString (getId andor));
	     PP.break ppstrm {nsp=1,offset=0};
(*	     ppPath ppstrm (getPath andor);
	     PP.break ppstrm {nsp=1,offset=0};
*)
	     ppSign ppstrm sign;
	     PP.break ppstrm {nsp=1,offset=0};
	     ppChoices ppstrm (cases,default);
	     PP.closeBox ppstrm)
	  | ppDec ppstrm (RHS ruleno) =
	    (PP.openHBox ppstrm;
	     PP.string ppstrm "RHS";
	     PP.break ppstrm {nsp=1,offset=0};
	     PP.string ppstrm (Int.toString ruleno);
	     PP.closeBox ppstrm)
	  | ppDec ppstrm (FAIL) =
	    (PP.openHBox ppstrm;
	     PP.string ppstrm "FAIL";
	     PP.closeBox ppstrm)
	and ppChoices ppstrm (cases,default) =
            (PP.openVBox ppstrm (PP.Abs 3);
	     PU.ppvseq ppstrm 0 "" ppCase cases;
	     (case default
	        of SOME dectree =>
          	     (PP.cut ppstrm;
		      PP.openHOVBox ppstrm (PP.Abs 0);
	              PP.string ppstrm "*";
		      PP.break ppstrm {nsp=1,offset=0};
		      ppDec ppstrm dectree;
		      PP.closeBox ppstrm)
		 | NONE => ());
	     PP.closeBox ppstrm)
	and ppCase ppstrm (con, decTree) =
	    (PP.openHBox ppstrm;
	     PP.string ppstrm (conToString con);
	     PP.break ppstrm {nsp=1,offset=0};
	     ppDec ppstrm decTree;
	     PP.closeBox ppstrm)
    in ppDec
    end

fun ppPvarMapEntry ppstrm (lvar, alist) =
    let fun prBind ppstrm (r, id) =
	    (PP.openHBox ppstrm;
	       PP.string ppstrm "(";
	       PP.string ppstrm (Int.toString r);
	       PP.string ppstrm ",";
	       PP.string ppstrm (Int.toString id);
	       PP.string ppstrm ")";
	     PP.closeBox ppstrm)
     in PP.openHBox ppstrm;
	PP.string ppstrm (LV.toString lvar);
	PU.pps ppstrm " = {";
	PU.ppSequence ppstrm
	 {sep = (fn ppstrm => PU.pps ppstrm ","),
	  pr = prBind,
	  style = PU.INCONSISTENT}
	 alist;
	PU.pps ppstrm "}";
	PP.closeBox ppstrm (* openHBox *)
    end

fun ppPvarMap ppstrm pvarmap =
    let val contents = Andor.PVM.listItemsi pvarmap
    in case contents
	of nil => PP.string ppstrm "<< empty pvarmap >>"
	 | _ => 
	   (PP.openVBox ppstrm (PP.Abs 3);
	      PU.ppvseq ppstrm 0 "" ppPvarMapEntry contents;
	    PP.closeBox ppstrm)
    end

fun ppRule ppstrm (AS.RULE(pat, exp)) =
    (PP.openHBox ppstrm;
       PPAbsyn.ppPat StaticEnv.empty ppstrm (pat, 100);
       PP.string ppstrm " => ";
       PP.openHOVBox ppstrm (PP.Abs 3);
        PPAbsyn.ppExp (StaticEnv.empty, NONE) ppstrm (exp, 100);
       PP.closeBox ppstrm;  (* openHOVBox *)
     PP.closeBox ppstrm)  (* openHBox *)

fun ppMatch ppstrm match =
    (PP.openVBox ppstrm (PP.Abs 3);
       PU.ppvseq ppstrm 0 "" ppRule match;
     PP.closeBox ppstrm)

end (* top local *)
end (* structure MCPrint *)
