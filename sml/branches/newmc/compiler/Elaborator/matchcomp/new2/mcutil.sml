(* Elaborate/matchcomp/mcutil.sml *)

structure MCUtil =
struct

local
  structure S = Symbol
  structure AS = Absyn
  structure AU = AbsynUtil
  structure T = Types
  structure BT = BasicTypes
  structure V = VarCon
  structure MC = MCCommon
  open AS MC

  fun bug (msg: string) = ErrorMsg.impossible ("VMCexp: "^msg)

in

(* intToIntLiteral : int -> Types.ty IntConst.t *)
fun intToIntLiteral (n: int) =
    {ival = IntInf.fromInt n, ty = BasicTypes.intTy} : Types.ty IntConst.t

fun numLitToString ({ival,...} : AS.num_lit) = IntInf.toString ival

type caseVariant = MC.con * V.var option * AS.exp

(* mkVarExp : V.var -> AS.exp *)
fun mkVarExp var =
    VARexp(ref var, nil)

(* mkNumExp : int -> AS.exp *)
fun mkNumExp (n: int) =
    NUMexp(Int.toString n, intToIntLiteral n)

(* mkLetVar : V.var * AS.exp * ASexp -> AS.exp *)
(* "let var = defexp in body" *)
fun mkLetVar (var: V.var, definiens, body) =
    LETexp(VALdec [VB{pat = VARpat var,
		      exp = definiens,
		      typ = V.varType var,
		      boundtvs = nil,
		      tyvars = ref nil}],
	   body)

(* conToPat : MC.con * V.var option -> AS.pat *)
(* varOp is SOME var if con is DATAcon (dcon,_) where dcon is a nonconstant datacon *)
fun conToPat (con, varOp) =
    (case con
      of (DATAcon (dcon,tvs)) =>
	   (case varOp
	     of NONE => CONpat(dcon, tvs)  (* => dcon is constant *)
	      | SOME var => APPpat(dcon, tvs, VARpat var))
       | INTcon num => NUMpat (numLitToString num, num)
       | WORDcon num => NUMpat (numLitToString num, num)
       | STRINGcon s => STRINGpat s
(* characters have been converted to ints?
       | C c =>  (* character constant patterns mapped to int patterns *)
	 let val c_ord = Char.ord c
	     val src = Int.toString c_ord
	  in NUMpat (src, {ival = IntInf.fromInt c_ord, ty = BT.intTy})
	 end
*)
       | _ => bug "conToPat") (* does not apply to VLENcon  *)

(* mkLetr : V.var list * V.var * AS.exp -> AS.exp *)
(* "let (sv1,...,svn) = sv0 in body"; destructure a record/tuple *)
fun mkLetr (vars, defvar, body) =
    let (* defvar: variable bound to the record/tuple *)
	fun wrapLets (nil, _) = body
	  | wrapLets (var::rest, n) =
	      mkLetVar (var, AS.RSELECTexp (defvar, n), wrapLets (rest, n+1))
    in wrapLets (vars, 0)  (* selection index 0 based *)
    end

(* mkLetv : SV.svar list * SV.svar * mcexp -> mcexp *)
(* "let #[sv1,...,svn] = sv0 in body"; destructure a vector *)
(* Vector selection represented by VSELECTexp. *)
fun mkLetv (vars, defvar, body) =
    let fun wrapLets (nil, _) = body
	  | wrapLets (var::rest, n) =
	      mkLetVar (var, AS.VSELECTexp (defvar, n), wrapLets (rest, n+1))
    in wrapLets (vars, 0)
    end

(* mkSwitch : V.var * caseVariant list * AS.exp option -> AS.exp *)
(* The default is now incorporated into the SWITCHexp. It will always be SOME
 * if the patterns in rules are not exhaustive. *)
fun mkSwitch (var: V.var, cases, defaultOp) =
    (case cases  (* distinguish vector switch special case by key = V _ *)
       of nil => bug "Switch: empty cases"
        | ((MC.VLENcon _, _, _) :: _) => (* vector length switch *)
	    (* "let val len = Vector.length svar in <<switch over int values of len>>"
             * where "len" is a fresh internal variable -- this is generated in
             * the VSWITCHexp case of Translate.mkExp0 to avoid the problem of
	     * accessing the vector length primop in absyn. *)
	    let fun docase (MC.VLENcon (n,_), _, rhsexp) =
		      AS.RULE (AS.NUMpat("", intToIntLiteral n), rhsexp)
		  | docase _ = bug "Switch:vector case: con not VLENcon"
	     in AS.VSWITCHexp (var, map docase cases, Option.valOf defaultOp)
	    end
	|  _ =>  (* the general case, dispatching on the key *)
	    let fun docase (con, svarOp, rhsexp) = RULE(conToPat(con,svarOp), rhsexp)
	     in AS.SWITCHexp (var, map docase cases, defaultOp)
	    end)
(*
(* Sfun : V.var list * AS.exp -> AS.exp *)
(* "fn (v0, ..., vn) => rhsExp"; functionalized, multi-use rule RHS
    Note that the body exp is from the original rule, and hence will only
    contain occurrences of pattern vars, never match svars. *)
(* FIXED: Translate.mkExp0 expects single rule of form (VARpat v, body).
 * need to pass single parameter and destruct the tuple around body.
 * BUG? pvars for different functions may overlap, introducing duplication
 * among lambda bound lvars. Do lvar alpha-conversion to make bound lvars
 * unique? (fcontract problem). *)
fun Sfun (pvars, body, rhsTy) =
    (case pvars
       of nil => (* pattern contained no bound variables *)
	  let val dummyVar = V.newVALvar (S.varSymbol "sarg", BT.unitTy)
	      val rule = RULE (AS.VARpat dummyVar, body)
	     in AS.FNexp([rule], BT.unitTy, rhsTy)
	    end
        | [pvar] => (* single variable *)
	    let val pvarTy = V.varType pvar
		val rule = RULE (AS.VARpat pvar, body)
	     in AS.FNexp([rule], pvarTy, rhsTy) (* result ty not relevant *)
	    end
        | _ => (* multiple variables *)
	    let val pvarsTy = BasicTypes.tupleTy(map V.varType pvars)
		val argvar = V.newVALvar (S.varSymbol "sarg", pvarsTy)
		fun wrapLets (nil, _) = body
		  | wrapLets (v::rest, n) =
		      mkLetVar (v, AS.RSELECTexp (argvar, n), wrapLets (rest, n+1))
		val wrappedBody = wrapLets (pvars, 0)
		val rule = RULE( AS.VARpat argvar, wrappedBody)
	     in AS.FNexp([rule], pvarsTy, rhsTy) (* result ty not relevant *)
	    end)
*)
(* Sapp : SV.svar * SV.svar list -> mcexp *)
(* passing a single tuple value, consistent with Translate. *)
fun Sapp (funvar, argvars) =
    (case argvars
       of nil => AS.APPexp(mkVarExp funvar, AU.unitExp)
        | [var] => AS.APPexp(mkVarExp funvar, mkVarExp var)
	| _ => AS.APPexp(mkVarExp funvar, AU.TUPLEexp(map mkVarExp argvars)))

end (* top local *)
end (* structure MCUtil *)
