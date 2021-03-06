(* Copyright 1992 by AT&T Bell Laboratories 
 *
 *)

signature AST =
sig
  type fixity
  type symbol  (* = Symbol.symbol *)
  val infixleft : int -> fixity
  val infixright : int -> fixity
  type literal = IntInf.int

  (* to mark positions in files *)
  type srcpos  (* = int *)
  type region  (* = srcpos * srcpos *)
  (* symbolic path (SymPath.spath) *)
  type path
  type 'a fixitem (* = {item: 'a, fixity: symbol option, region: region} *)

  datatype 'a sigConst
    = NoSig
    | Transparent of 'a
    | Opaque of 'a

  (* EXPRESSIONS *)

  datatype exp
    = VarExp of path		(* variable *)
    | FnExp of rule list		(* abstraction *)
    | FlatAppExp of exp fixitem list
                                  (* expressions prior to fixity parsing *)
    | AppExp of {function:exp,argument:exp}
				  (* application *)
    | CaseExp of{expr:exp,rules:rule list}
				  (* case expression *)
    | LetExp of {dec:dec,expr:exp} (* let expression *)
    | SeqExp of exp list		(* sequence of expressions *)
    | IntExp of literal		(* integer *)
    | WordExp of literal	(* word literal *)
    | RealExp of string		(* floating point coded by its string *)
    | StringExp of string	(* string *)
    | CharExp of string		(* char *)
    | RecordExp of (symbol * exp) list	(* record *)
    | ListExp of exp list	(*  [list,in,square,brackets] *)
    | TupleExp of exp list	(* tuple (derived form) *)
    | SelectorExp of symbol	(* selector of a record field *)
    | ConstraintExp of {expr:exp,constraint:ty}
				  (* type constraint *)
    | HandleExp of {expr:exp, rules:rule list}
				  (* exception handler *)
    | RaiseExp of exp		(* raise an exception *)
    | IfExp of {test:exp, thenCase:exp, elseCase:exp}
				  (* if expression (derived form) *)
    | AndalsoExp of exp * exp	(* andalso (derived form) *)
    | OrelseExp of exp * exp	(* orelse (derived form) *)
    | VectorExp of exp list       (* vector *)
    | WhileExp of {test:exp,expr:exp}
				  (* while (derived form) *)
    | MarkExp of exp * region	(* mark an expression *)

  (* RULE for case functions and exception handler *)
  and rule = Rule of {pat:pat,exp:exp}

  (* PATTERN *)
  and pat = WildPat				(* empty pattern *)
	  | VarPat of path			(* variable pattern *)
	  | IntPat of literal			(* integer *)
	  | WordPat of literal			(* word literal *)
	  | StringPat of string			(* string *)
	  | CharPat of string			(* char *)
	  | RecordPat of {def:(symbol * pat) list, flexibility:bool}
						(* record *)
          | ListPat of pat list		       (*  [list,in,square,brackets] *)
	  | TuplePat of pat list		(* tuple *)
          | FlatAppPat of pat fixitem list
                                        (* patterns prior to fixity parsing *)
	  | AppPat of {constr:pat,argument:pat}(* application *)
	  | ConstraintPat of {pattern:pat,constraint:ty}
						  (* constraint *)
	  | LayeredPat of {varPat:pat,expPat:pat}	(* as expressions *)
          | VectorPat of pat list                 (* vector pattern *)
	  | MarkPat of pat * region	(* mark a pattern *)
	  | OrPat of pat list			(* or-pattern *)

  (* STRUCTURE EXPRESSION *) 
  and strexp = VarStr of path			(* variable structure *)
	     | BaseStr of dec			(* defined structure *)
             | ConstrainedStr of strexp * sigexp sigConst (* signature constrained *)
	     | AppStr of path * (strexp * bool) list (* application (external) *)
             | AppStrI of path * (strexp * bool) list (* application (internal) *)
	     | LetStr of dec * strexp		(* let in structure *)
	     | MarkStr of strexp * region (* mark *)

  (* FUNCTOR EXPRESSION *)
  and fctexp = VarFct of path * fsigexp sigConst	(* functor variable *)
	     | BaseFct of  {			(* definition of a functor *)
		params	   : (symbol option * sigexp) list,
		body	   : strexp,
		constraint : sigexp sigConst}
	     | LetFct of dec * fctexp
	     | AppFct of path * (strexp * bool) list * fsigexp sigConst
						  (* application *)
	     | MarkFct of fctexp * region (* mark *)

  (* WHERE SPEC *)
  and wherespec = WhType of symbol list * tyvar list * ty
                | WhStruct of symbol list * symbol list

  (* SIGNATURE EXPRESSION *)
  and sigexp = VarSig of symbol			 (* signature variable *)
             | AugSig of sigexp * wherespec list (* sig augmented with where spec *)
	     | BaseSig of spec list		 (* defined signature *)
	     | MarkSig of sigexp * region	 (* mark *)

  (* FUNCTOR SIGNATURE EXPRESSION *)
  and fsigexp = VarFsig of symbol			(* funsig variable *)
	      | BaseFsig of {param: (symbol option * sigexp) list, result:sigexp}
						  (* defined funsig *)
	      | MarkFsig of fsigexp * region	(* mark a funsig *)

  (* SPECIFICATION FOR SIGNATURE DEFINITIONS *)
  and spec = StrSpec of (symbol * sigexp * path option) list
                                                                (* structure *)
           | TycSpec of ((symbol * tyvar list * ty option) list * bool)
                                                                (* type *)
	   | FctSpec of (symbol * fsigexp) list			(* functor *)
	   | ValSpec of (symbol * ty) list			(* value *)
	   | DataSpec of {datatycs: db list, withtycs: tb list}	(* datatype *)
	   | ExceSpec of (symbol * ty option) list		(* exception *)
	   | FixSpec of  {fixity: fixity, ops: symbol list} 	(* fixity *)
	   | ShareStrSpec of path list			(* structure sharing *)
	   | ShareTycSpec of path list			(* type sharing *)
	   | IncludeSpec of sigexp			(* include specif *)
	   | MarkSpec of spec * region	(* mark a spec *)

  (* DECLARATIONS (let and structure) *)
  and dec = ValDec of (vb list * tyvar list)		(* values *)
	  | ValrecDec of (rvb list * tyvar list)	(* recursive values *)
	  | FunDec of (fb list * tyvar list)		(* recurs functions *)
	  | TypeDec of tb list				(* type dec *)
	  | DatatypeDec of {datatycs: db list, withtycs: tb list}
							  (* datatype dec *)
	  | AbstypeDec of {abstycs: db list, withtycs: tb list, body: dec}
							  (* abstract type *)
	  | ExceptionDec of eb list			(* exception *)
	  | StrDec of strb list				(* structure *)
	  | AbsDec of strb list				(* abstract struct *)
	  | FctDec of fctb list				(* functor *)
	  | SigDec of sigb list				(* signature *)
	  | FsigDec of fsigb list				(* funsig *)
	  | LocalDec of dec * dec				(* local dec *)
	  | SeqDec of dec list				(* sequence of dec *)
	  | OpenDec of path list			(* open structures *)
	  | OvldDec of symbol * ty * exp list	(* overloading (internal) *)
	  | FixDec of {fixity: fixity, ops: symbol list}  (* fixity *)
	  | ImportDec of string list		(* import (unused) *)
	  | MarkDec of dec * region		(* mark a dec *)

  (* VALUE BINDINGS *)
  and vb = Vb of {pat:pat, exp:exp}
         | LVb of {pat:pat, exp:exp}   (* ZIDO:  PWLE *)
	 | MarkVb of vb * region

  (* RECURSIVE VALUE BINDINGS *)
  and rvb = Rvb of {var:symbol, fixity: (symbol * region) option,
		    exp:exp, resultty: ty option}
          | LRvb of {var:symbol, fixity: (symbol * region) option,
                    exp:exp, resultty: ty option}   (* ZIDO:  PWLE *)
	  | MarkRvb of rvb * region

  (* RECURSIVE FUNCTIONS BINDINGS *)
  and fb = Fb of clause list
         | LFb of clause list   (* ZIDO:  PWLE *)
	 | MarkFb of fb * region

  (* CLAUSE: a definition for a single pattern in a function binding *)
  and clause = Clause of {pats: pat fixitem list, resultty: ty option, exp:exp}

  (* TYPE BINDING *)
  and tb = Tb of {tyc : symbol, def : ty, tyvars : tyvar list}
	 | MarkTb of tb * region

  (* DATATYPE BINDING *)
  and db = Db of {tyc : symbol, tyvars : tyvar list, rhs : dbrhs}
         | LDb of {tyc : symbol, tyvars : tyvar list, rhs : dbrhs}   (* ZIDO:  PWLE *)
	 | MarkDb of db * region

  (* DATATYPE BINDING RIGHT HAND SIDE *)
  and dbrhs = Constrs of (symbol * ty option) list
            | Repl of symbol list

  (* EXCEPTION BINDING *)
  and eb = EbGen of {exn: symbol, etype: ty option} (* Exception definition *)
	 | EbDef of {exn: symbol, edef: path}	  (* defined by equality *)
	 | MarkEb of eb * region

  (* STRUCTURE BINDING *)
  and strb = Strb of {name: symbol,def: strexp,constraint: sigexp sigConst}
	   | MarkStrb of strb * region

  (* FUNCTOR BINDING *)
  and fctb = Fctb of {name: symbol,def: fctexp}
	   | MarkFctb of fctb * region

  (* SIGNATURE BINDING *)
  and sigb = Sigb of {name: symbol,def: sigexp}
	   | MarkSigb of sigb * region

  (* FUNSIG BINDING *)
  and fsigb = Fsigb of {name: symbol,def: fsigexp}
	    | MarkFsigb of fsigb * region

  (* TYPE VARIABLE *)
  and tyvar = Tyv of symbol
	    | MarkTyv of tyvar * region

  (* TYPES *)
  and ty 
      = VarTy of tyvar			(* type variable *)
      | ConTy of symbol list * ty list	(* type constructor *)
      | RecordTy of (symbol * ty) list 	(* record *)
      | TupleTy of ty list		(* tuple *)
      | MarkTy of ty * region	        (* mark type *)

end (* signature AST *)


(*
 * $Log: ast.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:47  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.10  1997/11/24 19:58:34  dbm
 *   Ast constructor name changes.
 *
 * Revision 1.9  1997/10/26  23:14:36  dbm
 *   Changed argument of constructor StrSpec.  Signature is no longer optional.
 *
 * Revision 1.8  1997/08/25  23:03:34  walidt
 * Add in the names of new fixityparse and lazycomp files, in comments.
 *
 *
 * Merged the "lazy" extension to syntax with newest version.
 *
 * Revision 1.7  1997/08/02  02:21:27  dbm
 *   Added syntax for "include <sigexp>" and constrained strexp.
 *
 * Revision 1.6  1997/05/20  12:25:21  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.5  1997/04/14  21:33:59  dbm
 *   Generalized where spec associated with AugSig to accomodate multiple
 *   simultaneous definitions (and ultimately structure definitions in
 *   addition to type definitions).
 *
 * Revision 1.4  1997/03/17  18:56:20  dbm
 * New syntax (dbrhs) added for datatype replication.
 *
 * Revision 1.3  1997/01/31  15:12:34  dbm
 * Added sigConst datatype and modified VarFct, FctFct, AppFct, Strb to support
 * opaque signature constraints (":>").
 *
 * Revision 1.2  1997/01/28  23:20:41  jhr
 * Integer and word literals are now represented by IntInf.int (instead of
 * as strings).
 *
 * Revision 1.1.1.1  1997/01/14  01:38:42  george
 *   Version 109.24
 *
 *)
