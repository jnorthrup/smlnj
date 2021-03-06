(* ML-Yacc Parser Generator (c) 1989, 1990 Andrew W. Appel, David R. Tarditi *)

functor ParseGenFun(structure ParseGenParser : PARSE_GEN_PARSER
		    structure MakeTable : MAKE_LR_TABLE
		    structure Verbose : VERBOSE
		    structure PrintStruct : PRINT_STRUCT

		    sharing MakeTable.LrTable = PrintStruct.LrTable
		    sharing MakeTable.Errs = Verbose.Errs

                    structure Absyn : ABSYN
		    ) : PARSE_GEN =
  struct
    open Array List
    infix 9 sub
    structure Grammar = MakeTable.Grammar
    structure Header = ParseGenParser.Header

    open Header Grammar

    (* approx. maximum length of a line *)

    val lineLength = 70

    (* record type describing names of structures in the program being
 	generated *)

    datatype names = NAMES 
			of {miscStruct : string,  (* Misc{n} struct name *)
			    tableStruct : string, (* LR table structure *)
			    tokenStruct : string, (* Tokens{n} struct name *)
			    actionsStruct : string, (* Actions structure *)
			    valueStruct: string, (* semantic value structure *)
			    ecStruct : string,  (* error correction structure *)
			    arg: string, (* user argument for parser *)
			    tokenSig : string,  (* TOKENS{n} signature *)
			    miscSig :string, (* Signature for Misc structure *)
			    dataStruct:string, (* name of structure in Misc *)
						(* which holds parser data *)
			    dataSig:string (* signature for this structure *)
					
		 	    }

    val DEBUG = true
    exception Semantic

    (* common functions and values used in printing out program *)

    datatype values = VALS
		      of {say : string -> unit,
			  saydot : string -> unit,
			  sayln : string -> unit,
			  pureActions: bool,
			  pos_type : string,
			  arg_type : string,
			  ntvoid : string,
			  termvoid : string,
			  start : Grammar.nonterm,
			  hasType : Grammar.symbol -> bool,

			  (* actual (user) name of terminal *)

			  termToString : Grammar.term -> string,
			  symbolToString : Grammar.symbol -> string,

			  (* type symbol comes from the HDR structure,
			     and is now abstract *)

			  term : (Header.symbol * ty option) list,
			  nonterm : (Header.symbol * ty option) list,
			  terms : Grammar.term list}
			  
    structure SymbolHash = Hash(type elem = string
	    		        val gt = (op >) : string*string -> bool)

    structure TermTable = Table(type key = Grammar.term
				val gt = fn (T i,T j) => i > j)

    structure SymbolTable = Table(
	type key = Grammar.symbol
	val gt = fn (TERM(T i),TERM(T j)) => i>j
		  | (NONTERM(NT i),NONTERM(NT j)) => i>j
		  | (NONTERM _,TERM _) => true
		  | (TERM _,NONTERM _) => false)

    (* printTypes: function to print the following types in the LrValues
       structure and a structure containing the datatype svalue:

		type svalue -- it holds semantic values on the parse
				   stack
		type pos -- the type of line numbers
		type result -- the type of the value that results
				   from the parse

	The type svalue is set equal to the datatype svalue declared
	in the structure named by valueStruct.  The datatype svalue
	is declared inside the structure named by valueStruct to deal
	with the scope of constructors.
    *)

    val printTypes = fn (VALS {say,sayln,term,nonterm,symbolToString,pos_type,
				 arg_type,
				 termvoid,ntvoid,saydot,hasType,start,
				 pureActions,...},
			   NAMES {valueStruct,...},symbolType) =>
     let val prConstr = fn (symbol,SOME s) => 
			   say (" | " ^ (symbolName symbol) ^ " of " ^
			          (if pureActions then "" else "unit -> ") ^
				" (" ^ tyName s ^ ")"
				)
			 | _ => ()
     in sayln "local open Header in";
	sayln ("type pos = " ^ pos_type);
	sayln ("type arg = " ^ arg_type);
	sayln ("structure " ^ valueStruct ^ " = ");
	sayln "struct";
	say ("datatype svalue = " ^ termvoid ^ " | " ^ ntvoid ^ " of" ^
	     (if pureActions then "" else " unit -> ") ^ " unit");
	app prConstr term;
	app prConstr nonterm;
	sayln "\nend";
	sayln ("type svalue = " ^ valueStruct ^ ".svalue");
	say "type result = ";
	case symbolType (NONTERM start)
	of NONE => sayln "unit"
	 | SOME t => (say (tyName t); sayln "");
	sayln "end"
    end

     (* function to print Tokens{n} structure *)

    val printTokenStruct =
     fn (VALS {say, sayln, termToString, hasType,termvoid,terms,
	       pureActions,...},
	 NAMES {miscStruct,tableStruct,valueStruct,
		tokenStruct,tokenSig,dataStruct,...}) =>
		(sayln ("structure " ^ tokenStruct ^ " : " ^ tokenSig ^ " =");
		 sayln "struct";
	         sayln ("type svalue = " ^ dataStruct ^ ".svalue");
		 sayln "type ('a,'b) token = ('a,'b) Token.token";
		 let val f = fn term as T i =>
			(say "fun "; say (termToString term);
			 say " (";
		         if (hasType (TERM term)) then say "i," else ();
			 say "p1,p2) = Token.TOKEN (";
			 say (dataStruct ^ "." ^ tableStruct ^ ".T ");
			 say (makestring i);
			 say ",(";
			 say (dataStruct ^ "." ^ valueStruct ^ ".");
			 if (hasType (TERM term)) then 
			    (say (termToString term);
			     if pureActions then say " i"
			     else say " (fn () => i)")
			 else say termvoid;
			 say ",";
			 sayln "p1,p2))")
		in app f terms
		end;
		sayln "end")
			  
    (* function to print signatures out - takes print function which
	does not need to insert line breaks *)

    val printSigs = fn (VALS {term,...},
			NAMES {tokenSig,tokenStruct,miscSig,
				dataStruct, dataSig, ...},
			say) =>
          say  ("signature " ^ tokenSig ^ " =\nsig\n\
		 \type ('a,'b) token\ntype svalue\n" ^
		 (fold (fn ((s,ty),r) =>
		          "val "^symbolName s^ 
			   (case ty
			    of NONE => ": " 
			     | SOME l => ": (" ^ (tyName l) ^ ") * ") ^
			    " 'a * 'a -> (svalue,'a) token\n"^r) term "") ^
		 "end\nsignature " ^ miscSig ^
		  "=\nsig\nstructure Tokens : " ^ tokenSig ^
		  "\nstructure " ^ dataStruct ^ ":" ^ dataSig ^
		  "\nsharing type " ^ dataStruct ^
		  ".Token.token = Tokens.token\nsharing type " ^
		  dataStruct ^ ".svalue = Tokens.svalue\nend\n")
		
    (* function to print structure for error correction *)

    val printEC = fn (keyword : term list,
		      preferred : term list,
		      subst : (term * term) list,
		      noshift : term list,
		      value : (term * string) list,
		      VALS {termToString, say,sayln,terms,saydot,hasType,
			    termvoid,pureActions,...},
		      NAMES {ecStruct,tableStruct,valueStruct,...}) =>
       let

	 (* subst is a list of pairs (sym,sym'), where sym is a preferred
	    substitution for sym'.  Construct a list of (sym,[..syms...]) where
	    the elements of the list are all the preferred substitions for
	    the sym *)
	
	 val subst =
	   let fun f ((sym,sym'),table) =
		case TermTable.find(sym',table)
		  of SOME l => TermTable.insert((sym',sym :: l),table)
		   | NONE => TermTable.insert((sym',[sym]),table)
	   in TermTable.make_list (fold f subst TermTable.empty)
	   end

	 val sayterm = fn (T i) => (say "(T "; say (makestring i); say ")")

	 val printBoolCase = fn ( l : term list) =>
	    (say "fn ";
	     app (fn t => (sayterm t; say " => true"; say " | ")) l;
	     sayln "_ => false")

	 val printTermList = fn (l : term list) =>
	    (app (fn t => (sayterm t; say " :: ")) l; sayln "nil")

	 val printSubst = fn (l : (term * (term list)) list) =>
	    (sayln "val preferred_subst =";
	     say "fn ";
	     app (fn (t,l') =>
		    (sayterm t; say " =>";
		     app (fn t => (sayterm t; say "::")) l';
		     sayln "nil"; say "|"
		    )
		 ) l;
	     sayln " _ => nil")

	 val printErrValues = fn (l : (term * string) list) =>
	    (sayln "val errtermvalue=";
	     sayln "let open Header in";
	     say "fn ";
	     app (fn (t,s) =>
		    (sayterm t; say " => ";
		     saydot valueStruct; say (termToString t);
		     say "(";
		     if pureActions then () else say "fn () => ";
		     say "("; say s; say "))";
		     sayln " | "
		    )
		 ) l;
	    say "_ => ";
	    say (valueStruct ^ ".");
	    sayln termvoid; sayln "end")
	      

	  val printNames = fn () =>
		let val f = fn term =>
			 (sayterm term; say " => "; say "\"";
			  say (termToString term); sayln "\""; say "  | ")
		in (sayln "val showTerminal =";
		    say "fn ";
		    app f terms;
		    sayln "_ => \"bogus-term\"")
		end

	   val ecTerms = 
		List.fold (fn (t,r) =>
		  if hasType (TERM t) orelse exists (fn (a,_)=>a=t) value
		    then r
		    else t::r)
		terms nil
				  
	in  say "structure ";
	    say ecStruct;
	    sayln "=";
	    sayln "struct";
	    say "open ";
	    sayln tableStruct;
	    sayln "val is_keyword =";
	    printBoolCase keyword;
	    sayln "val preferred_insert =";
	    printBoolCase preferred;
	    printSubst subst;
	    sayln "val noShift = ";
	    printBoolCase noshift;
	    printNames ();
	    printErrValues value;
	    say "val terms = ";
	    printTermList ecTerms;
	    sayln "end"
	end

val printAction = fn (rules,
			  VALS {hasType,say,sayln,termvoid,ntvoid,
			        symbolToString,saydot,start,pureActions,...},
			  NAMES {actionsStruct,valueStruct,tableStruct,arg,...}) =>
let val printAbsynRule = Absyn.printRule(say,sayln)
    val is_nonterm = fn (NONTERM i) => true | _ => false
    val numberRhs = fn r =>
	List.revfold (fn (e,(r,table)) =>
		let val num = case SymbolTable.find(e,table)
			       of SOME i => i
				| NONE => 1
		 in ((e,num,hasType e orelse is_nonterm e)::r,
		     SymbolTable.insert((e,num+1),table))
		 end) r (nil,SymbolTable.empty)

    val saySym = symbolToString

    val printCase = fn (i:int, r as {lhs=lhs as (NT lhsNum),prec,
				        rhs,code,rulenum}) =>

       (* mkToken: Build an argument *)

       let open Absyn
	   val mkToken = fn (sym,num : int,typed) =>
	     let val symString = symbolToString sym
	       val symNum = symString ^ (makestring num)
	     in PTUPLE[WILD,
		     PTUPLE[if not (hasType sym) then
			      (if is_nonterm sym then
				   PAPP(valueStruct^"."^ntvoid,
					PVAR symNum)
			      else WILD)
			   else	
			       PAPP(valueStruct^"."^symString,
			         if num=1 andalso pureActions
				     then AS(PVAR symNum,PVAR symString)
				 else PVAR symNum),
			     if num=1 then AS(PVAR (symString^"left"),
					      PVAR(symNum^"left"))
			     else PVAR(symNum^"left"),
			     if num=1 then AS(PVAR(symString^"right"),
					      PVAR(symNum^"right"))
			     else PVAR(symNum^"right")]]
	     end

            val numberedRhs = #1 (numberRhs rhs)

	(* construct case pattern *)

	   val pat = PTUPLE[PINT i,PLIST(map mkToken numberedRhs @
					   [PVAR "rest671"])]

	(* remove terminals in argument list w/o types *)

	   val argsWithTypes =
		  fold (fn ((_,_,false),r) => r
			 | (s as (_,_,true),r) => s::r) numberedRhs nil

        (* construct case body *)

           val defaultPos = EVAR "defaultPos"
           val resultexp = EVAR "result"
           val resultpat = PVAR "result"
           val code = CODE code
           val rest = EVAR "rest671"

	   val body =
	     LET([VB(resultpat,
		     EAPP(EVAR(valueStruct^"."^
			     (if hasType (NONTERM lhs)
				  then saySym(NONTERM lhs)
                                  else ntvoid)),
                          if pureActions then code
		          else if argsWithTypes=nil then FN(WILD,code)
                          else
			   FN(WILD,
			     let val body =
				LET(map (fn (sym,num:int,_) =>
				  let val symString = symbolToString sym
				      val symNum = symString ^ makestring num
				  in VB(if num=1 then
					     AS(PVAR symString,PVAR symNum)
					else PVAR symNum,
					EAPP(EVAR symNum,UNIT))
				  end) (rev argsWithTypes),
		                      code)
			     in if hasType (NONTERM lhs) then
				    body else SEQ(body,UNIT)
			     end)))],
                   ETUPLE[EAPP(EVAR(tableStruct^".NT"),EINT(lhsNum)),
			  case rhs
			  of nil => ETUPLE[resultexp,defaultPos,defaultPos]
			   | r =>let val (rsym,rnum,_) = hd(numberedRhs)
				     val (lsym,lnum,_) = hd(rev numberedRhs)
				 in ETUPLE[resultexp,
					   EVAR (symbolToString lsym ^
						 makestring lnum ^ "left"),
					   EVAR (symbolToString rsym ^
						  makestring rnum ^ "right")]
				 end,
                           rest])
    in printAbsynRule (RULE(pat,body))
    end

	  val prRules = fn () =>
	     (sayln "fn (i392,defaultPos,stack,";
	      say   "    ("; say arg; sayln "):arg) =>";
	      sayln "case (i392,stack)";
	      say "of ";
	      app (fn (rule as {rulenum,...}) =>
		   (printCase(rulenum,rule); say "| ")) rules;
	     sayln "_ => raise (mlyAction i392)")

   	in say "structure ";
	   say actionsStruct;
	   sayln " =";
	   sayln "struct ";
	   sayln "exception mlyAction of int";
	   sayln "val actions = ";
	   sayln "let open Header";
	   sayln "in";
	   prRules();
	   sayln "end";
	   say "val void = ";
	   saydot valueStruct;
	   sayln termvoid;
	   say "val extract = ";
	   say "fn a => (fn ";
	   saydot valueStruct;
	   if hasType (NONTERM start)
	      then say (symbolToString (NONTERM start))
	      else say "ntVOID";
	   sayln " x => x";
	   sayln "| _ => let exception ParseInternal";
	   say "\tin raise ParseInternal end) a ";
	   sayln (if pureActions then "" else "()");
	   sayln "end"
	end

    val make_parser = fn ((header,
	 DECL {eop,prefer,keyword,nonterm,prec, subst,
	       term, control,value} : declData,
	       rules : rule list),spec,error : pos -> string -> unit,
	       wasError : unit -> bool) =>
     let
	val verbose = List.exists (fn VERBOSE=>true | _ => false) control
	val defaultReductions = not (List.exists (fn NODEFAULT=>true | _ => false) control)
	val pos_type =
	   let fun f nil = NONE
		 | f ((POS s)::r) = SOME s 
		 | f (_::r) = f r
	   in f control
	   end
	val start =
	   let fun f nil = NONE
		 | f ((START_SYM s)::r) = SOME s 
		 | f (_::r) = f r
	   in f control
	   end
	val name =
	   let fun f nil = NONE
		 | f ((PARSER_NAME s)::r) = SOME s 
		 | f (_::r) = f r
	   in f control
	   end
	val header_decl =
	   let fun f nil = NONE
		 | f ((FUNCTOR s)::r) = SOME s 
		 | f (_::r) = f r
	   in f control
	   end
	val arg_decl =
	   let fun f nil = ("()","unit")
		 | f ((PARSE_ARG s)::r) = s 
		 | f (_::r) = f r
	   in f control
	   end

	val noshift =
	   let fun f nil = nil
		 | f ((NSHIFT s)::r) = s 
		 | f (_::r) = f r
	   in f control
	   end

	val pureActions =
	   let fun f nil = false
		 | f ((PURE)::r) = true 
		 | f (_::r) = f r
	   in f control
	   end

	val term =
	 case term
	   of NONE => (error 1 "missing %term definition"; nil)
	    | SOME l => l

	val nonterm =
	 case nonterm
	  of NONE => (error 1 "missing %nonterm definition"; nil)
	   | SOME l => l

	val pos_type =
	 case pos_type
	  of NONE => (error 1 "missing %pos definition"; "")
	   | SOME l => l


	val termHash = 
	  fold (fn ((symbol,_),table) =>
	      let val name = symbolName symbol
	      in if SymbolHash.exists(name,table) then
		   (error (symbolPos symbol)
		          ("duplicate definition of " ^ name ^ " in %term");
		    table)
		else SymbolHash.add(name,table)
              end) term SymbolHash.empty

	val isTerm = fn name => SymbolHash.exists(name,termHash)

	val symbolHash = 
	  fold (fn ((symbol,_),table) =>
	    let val name = symbolName symbol
	    in if SymbolHash.exists(name,table) then
		 (error (symbolPos symbol)
	             (if isTerm name then
		          name ^ " is defined as a terminal and a nonterminal"
		      else 
			  "duplicate definition of " ^ name ^ " in %nonterm");
		     table)
             else SymbolHash.add(name,table)
            end) nonterm termHash

	fun makeUniqueId s =
		if SymbolHash.exists(s,symbolHash) then makeUniqueId (s ^ "'")
		else s

	val _ = if wasError() then raise Semantic else ()

	val numTerms = SymbolHash.size termHash
	val numNonterms = SymbolHash.size symbolHash - numTerms

	val symError = fn sym => fn err => fn symbol =>
	  error (symbolPos symbol)
	        (symbolName symbol^" in "^err^" is not defined as a " ^ sym)

	val termNum : string -> Header.symbol -> term =
	  let val termError = symError "terminal" 
	  in fn stmt =>
	     let val stmtError = termError stmt
	     in fn symbol =>
	        case SymbolHash.find(symbolName symbol,symbolHash)
	        of NONE => (stmtError symbol; T ~1)
	         | SOME i => T (if i<numTerms then i
			        else (stmtError symbol; ~1))
	     end
	  end
			
	val nontermNum : string -> Header.symbol -> nonterm =
	  let val nontermError = symError "nonterminal" 
	  in fn stmt =>
	     let val stmtError = nontermError stmt
	     in fn symbol =>
	        case SymbolHash.find(symbolName symbol,symbolHash)
	        of NONE => (stmtError symbol; NT ~1)
	         | SOME i => if i>=numTerms then NT (i-numTerms)
			     else (stmtError symbol;NT ~1)
	     end
	  end

	val symbolNum : string -> Header.symbol -> Grammar.symbol =
	  let val symbolError = symError "symbol" 
	  in fn stmt =>
	     let val stmtError = symbolError stmt
	     in fn symbol =>
	        case SymbolHash.find(symbolName symbol,symbolHash)
	        of NONE => (stmtError symbol; NONTERM (NT ~1))
	         | SOME i => if i>=numTerms then NONTERM(NT (i-numTerms))
			     else TERM(T i)
	     end
	  end

(* map all symbols in the following values to terminals and check that
   the symbols are defined as terminals:

	eop : symbol list
	keyword: symbol list
	prefer: symbol list
	prec: (lexvalue * (symbol list)) list
	subst: (symbol * symbol) list
*)

	val eop = map (termNum "%eop") eop
	val keyword = map (termNum "%keyword") keyword
	val prefer = map (termNum "%prefer") prefer
	val prec = map (fn (a,l) => 
			(a,case a
			   of LEFT => map (termNum "%left") l
			    | RIGHT => map (termNum "%right") l
			    | NONASSOC => map (termNum "%nonassoc") l
			)) prec
	val subst =
	 let val mapTerm = termNum "%subst"
	 in map (fn (a,b) => (mapTerm a,mapTerm b)) subst
	 end
	val noshift = map (termNum "%noshift") noshift
	val value =
	  let val mapTerm = termNum "%value"
	  in map (fn (a,b) => (mapTerm a,b)) value
	  end
	val (rules,_) =
	   let val symbolNum = symbolNum "rule"
	       val nontermNum = nontermNum "rule"
	       val termNum = termNum "%prec tag"
           in List.fold
	   (fn (RULE {lhs,rhs,code,prec},(l,n)) =>
	     ( {lhs=nontermNum lhs,rhs=map symbolNum rhs,
	        code=code,prec=case prec
				of NONE => NONE
				 | SOME t => SOME (termNum t),
		 rulenum=n}::l,n-1))
		 rules (nil,length rules-1)
	end

	val _ = if wasError() then raise Semantic else ()

	(* termToString: map terminals back to strings *)

	val termToString =
	   let val data = array(numTerms,"")
	       val unmap = fn (symbol,_) =>
		   let val name = symbolName symbol
                   in update(data,
			     case SymbolHash.find(name,symbolHash)
			     of SOME i => i,name)
                   end
	       val _ = app unmap term
	   in fn T i =>
		if DEBUG andalso (i<0 orelse i>=numTerms)
		  then "bogus-num" ^ (makestring i)
		  else data sub i
	   end

	val nontermToString = 
	   let val data = array(numNonterms,"")
	       val unmap = fn (symbol,_) =>
		    let val name = symbolName symbol
		    in update(data,
			      case SymbolHash.find(name,symbolHash)
			      of SOME i => i-numTerms,name)
		    end
	       val _ = app unmap nonterm
	   in fn NT i =>
		if DEBUG andalso (i<0 orelse i>=numNonterms)
		  then "bogus-num" ^ (makestring i)
		  else data sub i
	   end

(* create functions mapping terminals to precedence numbers and rules to
  precedence numbers.

  Precedence statements are listed in order of ascending (tighter binding)
  precedence in the specification.   We receive a list composed of pairs
  containing the kind of precedence (left,right, or assoc) and a list of
  terminals associated with that precedence.  The list has the same order as
  the corresponding declarations did in the specification.

  Internally, a tighter binding has a higher precedence number.  We give
  precedences using multiples of 3:

		p+2 = right associative (force shift of symbol)
		p+1 = precedence for rule
		p = left associative (force reduction of rule)

  Nonassociative terminals are given also given a precedence of p+1.  The
table generator detects when the associativity of a nonassociative terminal
is being used to resolve a shift/reduce conflict by checking if the
precedences of the rule and the terminal are equal.

  A rule is given the precedence of its rightmost terminal *)

	val termPrec =
	    let val precData = array(numTerms, NONE : int option)
	        val addPrec = fn termPrec => fn term as (T i) =>
		   case precData sub i
		   of SOME _ =>
		     error 1 ("multiple precedences specified for terminal " ^
			    (termToString term))
		    | NONE => update(precData,i,termPrec)
		val termPrec = fn ((LEFT,_) ,i) => i
			      | ((RIGHT,_),i) => i+2
			      | ((NONASSOC,l),i) => i+1
		val _ = revfold (fn (args as ((_,l),i)) =>
			        (app (addPrec (SOME (termPrec args))) l; i+3))
			  prec 0
	   in fn (T i) =>
		if  DEBUG andalso (i < 0 orelse i >= numTerms) then
			NONE
		else precData sub i
	   end

	val rulePrec = 
	   let fun findRightTerm (nil,r) = r
	         | findRightTerm (TERM t :: tail,r) =
				 findRightTerm(tail,SOME t)
		 | findRightTerm (_ :: tail,r) = findRightTerm(tail,r)
	   in fn rhs =>
		 case findRightTerm(rhs,NONE)
		 of NONE => NONE
		  | SOME term => 
		       case termPrec term
		       of SOME i => SOME (i - (i mod 3) + 1)
		        | a => a
	   end

	val grammarRules =
	  let val conv = fn {lhs,rhs,code,prec,rulenum} =>
		{lhs=lhs,rhs =rhs,precedence=
			case prec
			  of SOME t => termPrec t
			   | _ => rulePrec rhs,
	         rulenum=rulenum}
	  in map conv rules
	  end

    (* get start symbol *)

	val start =
	 case start
	   of NONE => #lhs (hd grammarRules)
	    | SOME name => 
		nontermNum "%start" name

	val symbolType = 
	   let val data = array(numTerms+numNonterms,NONE : ty option)
	       val unmap = fn (symbol,ty) =>
		      update(data,
			     case SymbolHash.find(symbolName symbol,symbolHash)
			     of SOME i => i,ty)
	       val _ = (app unmap term; app unmap nonterm)
	   in fn NONTERM(NT i) =>
		if DEBUG andalso (i<0 orelse i>=numNonterms)
		  then NONE
		  else data sub (i+numTerms)
	       | TERM (T i) =>
		if DEBUG andalso (i<0 orelse i>=numTerms)
		  then NONE
		  else data sub i
	   end

	val symbolToString = 
	     fn NONTERM i => nontermToString i
	      | TERM i => termToString i

	val grammar  = GRAMMAR {rules=grammarRules,
				 terms=numTerms,nonterms=numNonterms,
				 eop = eop, start=start,noshift=noshift,
				 termToString = termToString,
				 nontermToString = nontermToString,
				 precedence = termPrec}

	val name' = case name 
	            of NONE => ""
		     | SOME s => symbolName s

	val names = NAMES {miscStruct=name' ^ "LrValsFun",
			   valueStruct="MlyValue",
			   tableStruct="LrTable",
			   tokenStruct="Tokens",
			   actionsStruct="Actions",
			   ecStruct="EC",
			   arg= #1 arg_decl,
			   tokenSig = name' ^ "_TOKENS",
			   miscSig = name' ^ "_LRVALS",
			   dataStruct = "ParserData",
			   dataSig = "PARSER_DATA"}
		       
	val (table,stateErrs,corePrint,errs) =
		 MakeTable.mkTable(grammar,defaultReductions)

        val entries = ref 0 (* save number of action table entries here *)
	
    in  let val result = open_out (spec ^ ".sml")
 	    val sigs = open_out (spec ^ ".sig")
	    val pos = ref 0
	    val pr = fn s => output(result,s)
	    val say = fn s => let val l = String.length s
			           val newPos = (!pos) + l
			      in if newPos > lineLength 
				    then (pr "\n"; pos := l)
				    else (pos := newPos);
				   pr s
			      end
	    val saydot = fn s => (say (s ^ "."))
	    val sayln = fn t => (pr t; pr "\n"; pos := 0)
	    val termvoid = makeUniqueId "VOID"
	    val ntvoid = makeUniqueId "ntVOID"
	    val hasType = fn s => case symbolType s
				  of NONE => false
				   | _ => true
	    val terms = let fun f n = if n=numTerms then nil
				      else (T n) :: f(n+1)
		        in f 0
		        end
            val values = VALS {say=say,sayln=sayln,saydot=saydot,
		 	       termvoid=termvoid, ntvoid = ntvoid,
			       hasType=hasType, pos_type = pos_type,
			       arg_type = #2 arg_decl,
			       start=start,pureActions=pureActions,
			       termToString=termToString,
			       symbolToString=symbolToString,term=term,
			       nonterm=nonterm,terms=terms}

	    val (NAMES {miscStruct,tableStruct,dataStruct,...}) = names
         in case header_decl
	    of NONE => (say "functor "; say miscStruct; 
			sayln "(structure Token : TOKEN)")
	     | SOME s => say s;
	    sayln " = ";
	    sayln "struct";
	    sayln ("structure " ^ dataStruct ^ "=");
	    sayln "struct";
	    sayln "structure Header = ";
	    sayln "struct";
	    sayln header;
	    sayln "end";
	    sayln "structure LrTable = Token.LrTable";
	    sayln "structure Token = Token";
	    sayln "local open LrTable in ";
	    entries := PrintStruct.makeStruct{table=table,print=pr,
					      name = "table",
				              verbose=verbose};
	    sayln "end";
	    printTypes(values,names,symbolType);
	    printEC (keyword,prefer,subst,noshift,value,values,names);
	    printAction(rules,values,names);
	    sayln "end";
	    printTokenStruct(values,names);
	    sayln "end";
	    printSigs(values,names,fn s => output(sigs,s));    
	    close_out sigs;
	    close_out result;
	    MakeTable.Errs.printSummary (fn s => output(std_out,s)) errs
	end;
        if verbose then
	 let val f = open_out (spec ^ ".desc")
	     val say = fn s=> output(f,s)
	     val printRule =
	        let val rules = arrayoflist grammarRules
	        in fn say => 
		   let val prRule = fn {lhs,rhs,precedence,rulenum} =>
		     ((say o nontermToString) lhs; say " : ";
		      app (fn s => (say (symbolToString s); say " ")) rhs)
	           in fn i => prRule (rules sub i)
	           end
	        end
	 in Verbose.printVerbose
	    {termToString=termToString,nontermToString=nontermToString,
	     table=table, stateErrs=stateErrs,errs = errs,entries = !entries,
	     print=say, printCores=corePrint,printRule=printRule};
	    close_out f
	 end
        else ()
    end

    val parseGen = fn spec =>
		let val (result,inputSource) = ParseGenParser.parse spec
		in make_parser(getResult result,spec,Header.error inputSource,
				errorOccurred inputSource)
		end
end;
