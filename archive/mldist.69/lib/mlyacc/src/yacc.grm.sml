
functor MlyaccLrValsFun(structure Hdr : HEADER
			     structure Token : TOKEN
			     sharing Hdr = Header) = 
struct
structure ParserData=
struct
structure Header = 
struct
(* ML-Yacc Parser Generator (c) 1989 Andrew W. Appel, David R. Tarditi *)

(* parser for the ML parser generator *)

open Hdr

end
structure LrTable = Token.LrTable
structure Token = Token
local open LrTable in 
val table=let val actionRows =
"\
\\001\000\005\000\055\000\000\000\
\\001\000\005\000\066\000\000\000\
\\001\000\005\000\076\000\000\000\
\\001\000\005\000\088\000\000\000\
\\001\000\006\000\075\000\032\000\074\000\000\000\
\\001\000\007\000\023\000\014\000\022\000\016\000\021\000\019\000\020\000\
\\020\000\019\000\021\000\018\000\022\000\017\000\024\000\016\000\
\\025\000\015\000\026\000\014\000\027\000\013\000\028\000\012\000\
\\030\000\011\000\034\000\010\000\035\000\009\000\036\000\008\000\
\\038\000\007\000\039\000\006\000\000\000\
\\001\000\008\000\000\000\000\000\
\\001\000\010\000\053\000\000\000\
\\001\000\010\000\080\000\000\000\
\\001\000\011\000\003\000\000\000\
\\001\000\012\000\024\000\000\000\
\\001\000\012\000\026\000\000\000\
\\001\000\012\000\027\000\000\000\
\\001\000\012\000\029\000\000\000\
\\001\000\012\000\039\000\013\000\038\000\000\000\
\\001\000\012\000\039\000\013\000\038\000\017\000\037\000\031\000\036\000\
\\037\000\035\000\000\000\
\\001\000\012\000\043\000\000\000\
\\001\000\012\000\048\000\000\000\
\\001\000\012\000\063\000\015\000\062\000\000\000\
\\001\000\012\000\063\000\015\000\062\000\032\000\061\000\000\000\
\\001\000\012\000\067\000\000\000\
\\001\000\012\000\069\000\000\000\
\\001\000\012\000\070\000\000\000\
\\001\000\012\000\087\000\000\000\
\\001\000\012\000\091\000\000\000\
\\001\000\031\000\032\000\000\000\
\\001\000\031\000\045\000\000\000\
\\001\000\031\000\049\000\000\000\
\\001\000\031\000\090\000\000\000\
\\001\000\031\000\094\000\000\000\
\\096\000\012\000\048\000\000\000\
\\097\000\000\000\
\\098\000\000\000\
\\099\000\004\000\050\000\000\000\
\\100\000\004\000\050\000\000\000\
\\101\000\012\000\054\000\000\000\
\\102\000\000\000\
\\103\000\012\000\054\000\000\000\
\\104\000\012\000\054\000\000\000\
\\105\000\012\000\054\000\000\000\
\\106\000\004\000\052\000\000\000\
\\107\000\012\000\054\000\000\000\
\\108\000\000\000\
\\109\000\000\000\
\\110\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\111\000\000\000\
\\112\000\000\000\
\\113\000\000\000\
\\114\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\115\000\000\000\
\\116\000\000\000\
\\117\000\000\000\
\\118\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\119\000\023\000\079\000\000\000\
\\120\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\121\000\023\000\051\000\000\000\
\\122\000\004\000\083\000\000\000\
\\123\000\000\000\
\\124\000\000\000\
\\125\000\000\000\
\\126\000\000\000\
\\127\000\000\000\
\\128\000\000\000\
\\129\000\000\000\
\\130\000\000\000\
\\131\000\000\000\
\\132\000\000\000\
\\133\000\000\000\
\\134\000\000\000\
\\135\000\012\000\039\000\013\000\038\000\000\000\
\\136\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\137\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\138\000\001\000\058\000\002\000\057\000\012\000\039\000\013\000\038\000\000\000\
\\139\000\000\000\
\\140\000\000\000\
\\141\000\000\000\
\\142\000\000\000\
\\143\000\000\000\
\\144\000\012\000\054\000\029\000\085\000\000\000\
\"
val actionRowNumbers =
"\009\000\032\000\005\000\031\000\
\\010\000\045\000\011\000\012\000\
\\013\000\060\000\060\000\025\000\
\\015\000\047\000\060\000\060\000\
\\011\000\046\000\016\000\060\000\
\\026\000\017\000\027\000\033\000\
\\055\000\036\000\040\000\007\000\
\\039\000\035\000\000\000\048\000\
\\068\000\063\000\066\000\019\000\
\\014\000\073\000\037\000\041\000\
\\034\000\043\000\038\000\042\000\
\\030\000\058\000\001\000\049\000\
\\020\000\015\000\021\000\022\000\
\\059\000\015\000\067\000\015\000\
\\015\000\004\000\002\000\065\000\
\\076\000\075\000\074\000\057\000\
\\060\000\053\000\054\000\008\000\
\\051\000\044\000\069\000\070\000\
\\064\000\018\000\015\000\056\000\
\\078\000\015\000\023\000\003\000\
\\072\000\060\000\028\000\024\000\
\\052\000\050\000\015\000\078\000\
\\061\000\077\000\071\000\029\000\
\\062\000\006\000"
val gotoT =
"\
\\001\000\093\000\000\000\
\\006\000\002\000\000\000\
\\005\000\003\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\002\000\023\000\000\000\
\\000\000\
\\013\000\026\000\000\000\
\\003\000\028\000\000\000\
\\003\000\029\000\000\000\
\\000\000\
\\007\000\032\000\014\000\031\000\000\000\
\\000\000\
\\003\000\038\000\000\000\
\\003\000\039\000\000\000\
\\002\000\040\000\000\000\
\\000\000\
\\000\000\
\\003\000\042\000\000\000\
\\000\000\
\\010\000\045\000\011\000\044\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\004\000\058\000\008\000\057\000\000\000\
\\007\000\062\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\010\000\063\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\007\000\032\000\014\000\066\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\007\000\032\000\014\000\069\000\000\000\
\\000\000\
\\007\000\032\000\014\000\070\000\000\000\
\\007\000\032\000\014\000\071\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\000\000\
\\003\000\076\000\009\000\075\000\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\007\000\054\000\000\000\
\\007\000\054\000\000\000\
\\000\000\
\\004\000\079\000\000\000\
\\007\000\032\000\014\000\080\000\000\000\
\\000\000\
\\012\000\082\000\000\000\
\\007\000\032\000\014\000\084\000\000\000\
\\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\003\000\087\000\000\000\
\\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\000\000\
\\007\000\032\000\014\000\090\000\000\000\
\\012\000\091\000\000\000\
\\000\000\
\\000\000\
\\007\000\054\000\000\000\
\\000\000\
\\000\000\
\\000\000\
\"
val numstates = 94
val numrules = 49
val s = ref "" and index = ref 0
val string_to_int = fn () => 
let val i = !index
in index := i+2; ordof(!s,i) + ordof(!s,i+1) * 256
end
val string_to_list = fn s' =>
    let val len = String.length s'
        fun f () =
           if !index < len then string_to_int() :: f()
           else nil
   in index := 0; s := s'; f ()
   end
val string_to_pairlist = fn (conv_key,conv_entry) =>
     let fun f () =
         case string_to_int()
         of 0 => EMPTY
          | n => PAIR(conv_key (n-1),conv_entry (string_to_int()),f())
     in f
     end
val string_to_pairlist_default = fn (conv_key,conv_entry) =>
    let val conv_row = string_to_pairlist(conv_key,conv_entry)
    in fn () =>
       let val default = conv_entry(string_to_int())
           val row = conv_row()
       in (row,default)
       end
   end
val string_to_table = fn (convert_row,s') =>
    let val len = String.length s'
 	 fun f ()=
	    if !index < len then convert_row() :: f()
	    else nil
     in (s := s'; index := 0; f ())
     end
local
  val memo = array(numstates+numrules,ERROR)
  val _ =let fun g i=(update(memo,i,REDUCE(i-numstates)); g(i+1))
	fun f i =
	     if i=numstates then g i
	     else (update(memo,i,SHIFT (STATE i)); f (i+1))
	   in f 0 handle Subscript => ()
	   end
in
val entry_to_action = fn 0 => ACCEPT | 1 => ERROR | j => memo sub (j-2)
end
val gotoT=arrayoflist(string_to_table(string_to_pairlist(NT,STATE),gotoT))
val actionRows=string_to_table(string_to_pairlist_default(T,entry_to_action),actionRows)
val actionRowNumbers = string_to_list actionRowNumbers
val actionT = let val actionRowLookUp=
let val a=arrayoflist(actionRows) in fn i=>a sub i end
in arrayoflist(map actionRowLookUp actionRowNumbers)
end
in LrTable.mkLrTable {actions=actionT,gotos=gotoT,numRules=numrules,
numStates=numstates,initialState=STATE 0}
end
end
local open Header in
type pos = int
type arg = Hdr.inputSource
structure MlyValue = 
struct
datatype svalue = VOID | ntVOID of unit ->  unit
 | UNKNOWN of unit ->  (string) | TYVAR of unit ->  (string)
 | PROG of unit ->  (string) | PREC of unit ->  (Header.prec)
 | INT of unit ->  (string) | IDDOT of unit ->  (string)
 | ID of unit ->  (string*int) | HEADER of unit ->  (string)
 | TY of unit ->  (string)
 | SUBST_DECL of unit ->  ( ( Hdr.symbol * Hdr.symbol )  list)
 | G_RULE_PREC of unit ->  (Hdr.symbol option)
 | G_RULE_LIST of unit ->  (Hdr.rule list)
 | G_RULE of unit ->  (Hdr.rule list)
 | RHS_LIST of unit ->  ({ rhs:Hdr.symbol list,code:string,prec:Hdr.symbol option }  list)
 | RECORD_LIST of unit ->  (string) | QUAL_ID of unit ->  (string)
 | MPC_DECLS of unit ->  (Hdr.declData)
 | MPC_DECL of unit ->  (Hdr.declData) | LABEL of unit ->  (string)
 | ID_LIST of unit ->  (Hdr.symbol list)
 | CONSTR_LIST of unit ->  ( ( Hdr.symbol * Hdr.ty option )  list)
 | BEGIN of unit ->  (string*Hdr.declData* ( Hdr.rule list ) )
end
type svalue = MlyValue.svalue
type result = string*Hdr.declData* ( Hdr.rule list ) 
end
structure EC=
struct
open LrTable
val is_keyword =
fn _ => false
val preferred_insert =
fn _ => false
val preferred_subst =
fn  _ => nil
val noShift = 
fn _ => false
val showTerminal =
fn (T 0) => "ARROW"
  | (T 1) => "ASTERISK"
  | (T 2) => "BLOCK"
  | (T 3) => "BAR"
  | (T 4) => "COLON"
  | (T 5) => "COMMA"
  | (T 6) => "DELIMITER"
  | (T 7) => "EOF"
  | (T 8) => "EQUAL"
  | (T 9) => "FOR"
  | (T 10) => "HEADER"
  | (T 11) => "ID"
  | (T 12) => "IDDOT"
  | (T 13) => "PERCENT_HEADER"
  | (T 14) => "INT"
  | (T 15) => "KEYWORD"
  | (T 16) => "LBRACE"
  | (T 17) => "LPAREN"
  | (T 18) => "NAME"
  | (T 19) => "NODEFAULT"
  | (T 20) => "NONTERM"
  | (T 21) => "NOSHIFT"
  | (T 22) => "OF"
  | (T 23) => "PERCENT_EOP"
  | (T 24) => "PERCENT_PURE"
  | (T 25) => "PERCENT_POS"
  | (T 26) => "PERCENT_ARG"
  | (T 27) => "PREC"
  | (T 28) => "PREC_TAG"
  | (T 29) => "PREFER"
  | (T 30) => "PROG"
  | (T 31) => "RBRACE"
  | (T 32) => "RPAREN"
  | (T 33) => "SUBST"
  | (T 34) => "START"
  | (T 35) => "TERM"
  | (T 36) => "TYVAR"
  | (T 37) => "VERBOSE"
  | (T 38) => "VALUE"
  | (T 39) => "UNKNOWN"
  | (T 40) => "BOGUS_VALUE"
  | _ => "bogus-term"
val errtermvalue=
let open Header in
fn _ => MlyValue.VOID
end
val terms = (T 0) :: (T 1) :: (T 2) :: (T 3) :: (T 4) :: (T 5) :: (T 6
) :: (T 7) :: (T 8) :: (T 9) :: (T 13) :: (T 15) :: (T 16) :: (T 17)
 :: (T 18) :: (T 19) :: (T 20) :: (T 21) :: (T 22) :: (T 23) :: (T 24)
 :: (T 25) :: (T 26) :: (T 28) :: (T 29) :: (T 31) :: (T 32) :: (T 33)
 :: (T 34) :: (T 35) :: (T 37) :: (T 38) :: (T 40) :: nil
end
structure Actions =
struct 
exception mlyAction of int
val actions = 
let open Header
in
fn (i392,defaultPos,stack,
    (inputSource):arg) =>
case (i392,stack)
of (0,(_,(MlyValue.G_RULE_LIST G_RULE_LIST1,_,G_RULE_LIST1right))::_::
(_,(MlyValue.MPC_DECLS MPC_DECLS1,_,_))::(_,(MlyValue.HEADER HEADER1,
HEADER1left,_))::rest671) => let val result=MlyValue.BEGIN(fn _ => 
let val HEADER as HEADER1=HEADER1 ()
val MPC_DECLS as MPC_DECLS1=MPC_DECLS1 ()
val G_RULE_LIST as G_RULE_LIST1=G_RULE_LIST1 ()
 in (HEADER,MPC_DECLS,rev G_RULE_LIST) end
)
 in (LrTable.NT 0,(result,HEADER1left,G_RULE_LIST1right),rest671) end
| (1,(_,(MlyValue.MPC_DECL MPC_DECL1,MPC_DECLleft,MPC_DECL1right))::(_
,(MlyValue.MPC_DECLS MPC_DECLS1,MPC_DECLS1left,_))::rest671) => let 
val result=MlyValue.MPC_DECLS(fn _ => let val MPC_DECLS as MPC_DECLS1=
MPC_DECLS1 ()
val MPC_DECL as MPC_DECL1=MPC_DECL1 ()
 in (join_decls(MPC_DECLS,MPC_DECL,inputSource,MPC_DECLleft)) end
)
 in (LrTable.NT 5,(result,MPC_DECLS1left,MPC_DECL1right),rest671) end
| (2,rest671) => let val result=MlyValue.MPC_DECLS(fn _ => (
DECL {prec=nil,nonterm=NONE,term=NONE,eop=nil,control=nil,
		   prefer=nil,keyword=nil,subst=nil,
		   value=nil}
))
 in (LrTable.NT 5,(result,defaultPos,defaultPos),rest671) end
| (3,(_,(MlyValue.CONSTR_LIST CONSTR_LIST1,_,CONSTR_LIST1right))::(_,(
_,TERM1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _ => 
let val CONSTR_LIST as CONSTR_LIST1=CONSTR_LIST1 ()
 in (
DECL { prec=nil,nonterm=NONE,
	       term = SOME CONSTR_LIST, eop =nil,control=nil,
		prefer=nil,subst=nil,keyword=nil,
		value=nil}
) end
)
 in (LrTable.NT 4,(result,TERM1left,CONSTR_LIST1right),rest671) end
| (4,(_,(MlyValue.CONSTR_LIST CONSTR_LIST1,_,CONSTR_LIST1right))::(_,(
_,NONTERM1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _
 => let val CONSTR_LIST as CONSTR_LIST1=CONSTR_LIST1 ()
 in (
DECL { prec=nil,control=nil,nonterm= SOME CONSTR_LIST,
	       term = NONE, eop=nil,prefer=nil,subst=nil,keyword=nil,
	       value=nil}
) end
)
 in (LrTable.NT 4,(result,NONTERM1left,CONSTR_LIST1right),rest671) end
| (5,(_,(MlyValue.ID_LIST ID_LIST1,_,ID_LIST1right))::(_,(
MlyValue.PREC PREC1,PREC1left,_))::rest671) => let val result=
MlyValue.MPC_DECL(fn _ => let val PREC as PREC1=PREC1 ()
val ID_LIST as ID_LIST1=ID_LIST1 ()
 in (
DECL {prec= [(PREC,ID_LIST)],control=nil,
	      nonterm=NONE,term=NONE,eop=nil,prefer=nil,subst=nil,
	      keyword=nil,value=nil}
) end
)
 in (LrTable.NT 4,(result,PREC1left,ID_LIST1right),rest671) end
| (6,(_,(MlyValue.ID ID1,_,ID1right))::(_,(_,START1left,_))::rest671)
 => let val result=MlyValue.MPC_DECL(fn _ => let val ID as ID1=ID1 ()
 in (
DECL {prec=nil,control=[START_SYM (symbolMake ID)],nonterm=NONE,
	       term = NONE, eop = nil,prefer=nil,subst=nil,keyword=nil,
	       value=nil}
) end
)
 in (LrTable.NT 4,(result,START1left,ID1right),rest671) end
| (7,(_,(MlyValue.ID_LIST ID_LIST1,_,ID_LIST1right))::(_,(_,
PERCENT_EOP1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn 
_ => let val ID_LIST as ID_LIST1=ID_LIST1 ()
 in (
DECL {prec=nil,control=nil,nonterm=NONE,term=NONE,
		eop=ID_LIST, prefer=nil,subst=nil,keyword=nil,
	 	value=nil}
) end
)
 in (LrTable.NT 4,(result,PERCENT_EOP1left,ID_LIST1right),rest671) end
| (8,(_,(MlyValue.ID_LIST ID_LIST1,_,ID_LIST1right))::(_,(_,
KEYWORD1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _
 => let val ID_LIST as ID_LIST1=ID_LIST1 ()
 in (
DECL {prec=nil,control=nil,nonterm=NONE,term=NONE,eop=nil,
		prefer=nil,subst=nil,keyword=ID_LIST,
	 	value=nil}
) end
)
 in (LrTable.NT 4,(result,KEYWORD1left,ID_LIST1right),rest671) end
| (9,(_,(MlyValue.ID_LIST ID_LIST1,_,ID_LIST1right))::(_,(_,
PREFER1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _ => 
let val ID_LIST as ID_LIST1=ID_LIST1 ()
 in (
DECL {prec=nil,control=nil,nonterm=NONE,term=NONE,eop=nil,
		prefer=ID_LIST, subst=nil,keyword=nil,
		value=nil}
) end
)
 in (LrTable.NT 4,(result,PREFER1left,ID_LIST1right),rest671) end
| (10,(_,(MlyValue.SUBST_DECL SUBST_DECL1,_,SUBST_DECL1right))::(_,(_,
SUBST1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _ => 
let val SUBST_DECL as SUBST_DECL1=SUBST_DECL1 ()
 in (
DECL {prec=nil,control=nil,nonterm=NONE,term=NONE,eop=nil,
		prefer=nil,subst=SUBST_DECL,keyword=nil,
		value=nil}
) end
)
 in (LrTable.NT 4,(result,SUBST1left,SUBST_DECL1right),rest671) end
| (11,(_,(MlyValue.ID_LIST ID_LIST1,_,ID_LIST1right))::(_,(_,
NOSHIFT1left,_))::rest671) => let val result=MlyValue.MPC_DECL(fn _
 => let val ID_LIST as ID_LIST1=ID_LIST1 ()
 in (
DECL {prec=nil,control=[NSHIFT ID_LIST],nonterm=NONE,term=NONE,
	            eop=nil,prefer=nil,subst=nil,keyword=nil,
		    value=nil}
) end
)
 in (LrTable.NT 4,(result,NOSHIFT1left,ID_LIST1right),rest671) end
| (12,(_,(MlyValue.PROG PROG1,_,PROG1right))::(_,(_,
PERCENT_HEADER1left,_))::rest671) => let val result=MlyValue.MPC_DECL(
fn _ => let val PROG as PROG1=PROG1 ()
 in (
DECL {prec=nil,control=[FUNCTOR PROG],nonterm=NONE,term=NONE,
	            eop=nil,prefer=nil,subst=nil,keyword=nil,
		    value=nil}
) end
)
 in (LrTable.NT 4,(result,PERCENT_HEADER1left,PROG1right),rest671) end
| (13,(_,(MlyValue.ID ID1,_,ID1right))::(_,(_,NAME1left,_))::rest671)
 => let val result=MlyValue.MPC_DECL(fn _ => let val ID as ID1=ID1 ()
 in (
DECL {prec=nil,control=[PARSER_NAME (symbolMake ID)],
	            nonterm=NONE,term=NONE,
		    eop=nil,prefer=nil,subst=nil,keyword=nil, value=nil}
) end
)
 in (LrTable.NT 4,(result,NAME1left,ID1right),rest671) end
| (14,(_,(MlyValue.TY TY1,_,TY1right))::_::(_,(MlyValue.PROG PROG1,_,_
))::(_,(_,PERCENT_ARG1left,_))::rest671) => let val result=
MlyValue.MPC_DECL(fn _ => let val PROG as PROG1=PROG1 ()
val TY as TY1=TY1 ()
 in (
DECL {prec=nil,control=[PARSE_ARG(PROG,TY)],nonterm=NONE,
	            term=NONE,eop=nil,prefer=nil,subst=nil,keyword=nil,
		     value=nil}
) end
)
 in (LrTable.NT 4,(result,PERCENT_ARG1left,TY1right),rest671) end
| (15,(_,(_,VERBOSE1left,VERBOSE1right))::rest671) => let val result=
MlyValue.MPC_DECL(fn _ => (
DECL {prec=nil,control=[Hdr.VERBOSE],
	        nonterm=NONE,term=NONE,eop=nil,
	        prefer=nil,subst=nil,keyword=nil,
		value=nil}
))
 in (LrTable.NT 4,(result,VERBOSE1left,VERBOSE1right),rest671) end
| (16,(_,(_,NODEFAULT1left,NODEFAULT1right))::rest671) => let val 
result=MlyValue.MPC_DECL(fn _ => (
DECL {prec=nil,control=[Hdr.NODEFAULT],
	        nonterm=NONE,term=NONE,eop=nil,
	        prefer=nil,subst=nil,keyword=nil,
		value=nil}
))
 in (LrTable.NT 4,(result,NODEFAULT1left,NODEFAULT1right),rest671) end
| (17,(_,(_,PERCENT_PURE1left,PERCENT_PURE1right))::rest671) => let 
val result=MlyValue.MPC_DECL(fn _ => (
DECL {prec=nil,control=[Hdr.PURE],
	        nonterm=NONE,term=NONE,eop=nil,
	        prefer=nil,subst=nil,keyword=nil,
		value=nil}
))
 in (LrTable.NT 4,(result,PERCENT_PURE1left,PERCENT_PURE1right),
rest671) end
| (18,(_,(MlyValue.TY TY1,_,TY1right))::(_,(_,PERCENT_POS1left,_))::
rest671) => let val result=MlyValue.MPC_DECL(fn _ => let val TY as TY1
=TY1 ()
 in (
DECL {prec=nil,control=[Hdr.POS TY],
	        nonterm=NONE,term=NONE,eop=nil,
	        prefer=nil,subst=nil,keyword=nil,
		value=nil}
) end
)
 in (LrTable.NT 4,(result,PERCENT_POS1left,TY1right),rest671) end
| (19,(_,(MlyValue.PROG PROG1,_,PROG1right))::(_,(MlyValue.ID ID1,_,_)
)::(_,(_,VALUE1left,_))::rest671) => let val result=MlyValue.MPC_DECL(
fn _ => let val ID as ID1=ID1 ()
val PROG as PROG1=PROG1 ()
 in (
DECL {prec=nil,control=nil,
	        nonterm=NONE,term=NONE,eop=nil,
	        prefer=nil,subst=nil,keyword=nil,
		value=[(symbolMake ID,PROG)]}
) end
)
 in (LrTable.NT 4,(result,VALUE1left,PROG1right),rest671) end
| (20,(_,(MlyValue.ID ID2,_,ID2right))::_::(_,(MlyValue.ID ID1,_,_))::
_::(_,(MlyValue.SUBST_DECL SUBST_DECL1,SUBST_DECL1left,_))::rest671)
 => let val result=MlyValue.SUBST_DECL(fn _ => let val SUBST_DECL as 
SUBST_DECL1=SUBST_DECL1 ()
val ID1=ID1 ()
val ID2=ID2 ()
 in ((symbolMake ID1,symbolMake ID2)::SUBST_DECL) end
)
 in (LrTable.NT 12,(result,SUBST_DECL1left,ID2right),rest671) end
| (21,(_,(MlyValue.ID ID2,_,ID2right))::_::(_,(MlyValue.ID ID1,ID1left
,_))::rest671) => let val result=MlyValue.SUBST_DECL(fn _ => let val 
ID1=ID1 ()
val ID2=ID2 ()
 in ([(symbolMake ID1,symbolMake ID2)]) end
)
 in (LrTable.NT 12,(result,ID1left,ID2right),rest671) end
| (22,(_,(MlyValue.TY TY1,_,TY1right))::_::(_,(MlyValue.ID ID1,_,_))::
_::(_,(MlyValue.CONSTR_LIST CONSTR_LIST1,CONSTR_LIST1left,_))::rest671
) => let val result=MlyValue.CONSTR_LIST(fn _ => let val CONSTR_LIST
 as CONSTR_LIST1=CONSTR_LIST1 ()
val ID as ID1=ID1 ()
val TY as TY1=TY1 ()
 in ((symbolMake ID,SOME (tyMake TY))::CONSTR_LIST) end
)
 in (LrTable.NT 1,(result,CONSTR_LIST1left,TY1right),rest671) end
| (23,(_,(MlyValue.ID ID1,_,ID1right))::_::(_,(MlyValue.CONSTR_LIST 
CONSTR_LIST1,CONSTR_LIST1left,_))::rest671) => let val result=
MlyValue.CONSTR_LIST(fn _ => let val CONSTR_LIST as CONSTR_LIST1=
CONSTR_LIST1 ()
val ID as ID1=ID1 ()
 in ((symbolMake ID,NONE)::CONSTR_LIST) end
)
 in (LrTable.NT 1,(result,CONSTR_LIST1left,ID1right),rest671) end
| (24,(_,(MlyValue.TY TY1,_,TY1right))::_::(_,(MlyValue.ID ID1,ID1left
,_))::rest671) => let val result=MlyValue.CONSTR_LIST(fn _ => let val 
ID as ID1=ID1 ()
val TY as TY1=TY1 ()
 in ([(symbolMake ID,SOME (tyMake TY))]) end
)
 in (LrTable.NT 1,(result,ID1left,TY1right),rest671) end
| (25,(_,(MlyValue.ID ID1,ID1left,ID1right))::rest671) => let val 
result=MlyValue.CONSTR_LIST(fn _ => let val ID as ID1=ID1 ()
 in ([(symbolMake ID,NONE)]) end
)
 in (LrTable.NT 1,(result,ID1left,ID1right),rest671) end
| (26,(_,(MlyValue.RHS_LIST RHS_LIST1,_,RHS_LIST1right))::_::(_,(
MlyValue.ID ID1,ID1left,_))::rest671) => let val result=
MlyValue.G_RULE(fn _ => let val ID as ID1=ID1 ()
val RHS_LIST as RHS_LIST1=RHS_LIST1 ()
 in (
map (fn {rhs,code,prec} =>
    	          Hdr.RULE {lhs=symbolMake ID,rhs=rev rhs,
			       code=code,prec=prec})
	 RHS_LIST
) end
)
 in (LrTable.NT 9,(result,ID1left,RHS_LIST1right),rest671) end
| (27,(_,(MlyValue.G_RULE G_RULE1,_,G_RULE1right))::(_,(
MlyValue.G_RULE_LIST G_RULE_LIST1,G_RULE_LIST1left,_))::rest671) => 
let val result=MlyValue.G_RULE_LIST(fn _ => let val G_RULE_LIST as 
G_RULE_LIST1=G_RULE_LIST1 ()
val G_RULE as G_RULE1=G_RULE1 ()
 in (G_RULE@G_RULE_LIST) end
)
 in (LrTable.NT 10,(result,G_RULE_LIST1left,G_RULE1right),rest671) end
| (28,(_,(MlyValue.G_RULE G_RULE1,G_RULE1left,G_RULE1right))::rest671)
 => let val result=MlyValue.G_RULE_LIST(fn _ => let val G_RULE as 
G_RULE1=G_RULE1 ()
 in (G_RULE) end
)
 in (LrTable.NT 10,(result,G_RULE1left,G_RULE1right),rest671) end
| (29,(_,(MlyValue.ID ID1,_,ID1right))::(_,(MlyValue.ID_LIST ID_LIST1,
ID_LIST1left,_))::rest671) => let val result=MlyValue.ID_LIST(fn _ => 
let val ID_LIST as ID_LIST1=ID_LIST1 ()
val ID as ID1=ID1 ()
 in (symbolMake ID :: ID_LIST) end
)
 in (LrTable.NT 2,(result,ID_LIST1left,ID1right),rest671) end
| (30,rest671) => let val result=MlyValue.ID_LIST(fn _ => (nil))
 in (LrTable.NT 2,(result,defaultPos,defaultPos),rest671) end
| (31,(_,(MlyValue.PROG PROG1,_,PROG1right))::(_,(MlyValue.G_RULE_PREC
 G_RULE_PREC1,_,_))::(_,(MlyValue.ID_LIST ID_LIST1,ID_LIST1left,_))::
rest671) => let val result=MlyValue.RHS_LIST(fn _ => let val ID_LIST
 as ID_LIST1=ID_LIST1 ()
val G_RULE_PREC as G_RULE_PREC1=G_RULE_PREC1 ()
val PROG as PROG1=PROG1 ()
 in ([{rhs=ID_LIST,code=PROG,prec=G_RULE_PREC}]) end
)
 in (LrTable.NT 8,(result,ID_LIST1left,PROG1right),rest671) end
| (32,(_,(MlyValue.PROG PROG1,_,PROG1right))::(_,(MlyValue.G_RULE_PREC
 G_RULE_PREC1,_,_))::(_,(MlyValue.ID_LIST ID_LIST1,_,_))::_::(_,(
MlyValue.RHS_LIST RHS_LIST1,RHS_LIST1left,_))::rest671) => let val 
result=MlyValue.RHS_LIST(fn _ => let val RHS_LIST as RHS_LIST1=
RHS_LIST1 ()
val ID_LIST as ID_LIST1=ID_LIST1 ()
val G_RULE_PREC as G_RULE_PREC1=G_RULE_PREC1 ()
val PROG as PROG1=PROG1 ()
 in ({rhs=ID_LIST,code=PROG,prec=G_RULE_PREC}::RHS_LIST) end
)
 in (LrTable.NT 8,(result,RHS_LIST1left,PROG1right),rest671) end
| (33,(_,(MlyValue.TYVAR TYVAR1,TYVAR1left,TYVAR1right))::rest671) => 
let val result=MlyValue.TY(fn _ => let val TYVAR as TYVAR1=TYVAR1 ()
 in (TYVAR) end
)
 in (LrTable.NT 13,(result,TYVAR1left,TYVAR1right),rest671) end
| (34,(_,(_,_,RBRACE1right))::(_,(MlyValue.RECORD_LIST RECORD_LIST1,_,
_))::(_,(_,LBRACE1left,_))::rest671) => let val result=MlyValue.TY(fn 
_ => let val RECORD_LIST as RECORD_LIST1=RECORD_LIST1 ()
 in ("{ "^RECORD_LIST^" } ") end
)
 in (LrTable.NT 13,(result,LBRACE1left,RBRACE1right),rest671) end
| (35,(_,(_,_,RBRACE1right))::(_,(_,LBRACE1left,_))::rest671) => let 
val result=MlyValue.TY(fn _ => ("{}"))
 in (LrTable.NT 13,(result,LBRACE1left,RBRACE1right),rest671) end
| (36,(_,(MlyValue.PROG PROG1,PROG1left,PROG1right))::rest671) => let 
val result=MlyValue.TY(fn _ => let val PROG as PROG1=PROG1 ()
 in (" ( "^PROG^" ) ") end
)
 in (LrTable.NT 13,(result,PROG1left,PROG1right),rest671) end
| (37,(_,(MlyValue.QUAL_ID QUAL_ID1,_,QUAL_ID1right))::(_,(MlyValue.TY
 TY1,TY1left,_))::rest671) => let val result=MlyValue.TY(fn _ => let 
val TY as TY1=TY1 ()
val QUAL_ID as QUAL_ID1=QUAL_ID1 ()
 in (TY^" "^QUAL_ID) end
)
 in (LrTable.NT 13,(result,TY1left,QUAL_ID1right),rest671) end
| (38,(_,(MlyValue.QUAL_ID QUAL_ID1,QUAL_ID1left,QUAL_ID1right))::
rest671) => let val result=MlyValue.TY(fn _ => let val QUAL_ID as 
QUAL_ID1=QUAL_ID1 ()
 in (QUAL_ID) end
)
 in (LrTable.NT 13,(result,QUAL_ID1left,QUAL_ID1right),rest671) end
| (39,(_,(MlyValue.TY TY2,_,TY2right))::_::(_,(MlyValue.TY TY1,TY1left
,_))::rest671) => let val result=MlyValue.TY(fn _ => let val TY1=TY1 
()
val TY2=TY2 ()
 in (TY1^"*"^TY2) end
)
 in (LrTable.NT 13,(result,TY1left,TY2right),rest671) end
| (40,(_,(MlyValue.TY TY2,_,TY2right))::_::(_,(MlyValue.TY TY1,TY1left
,_))::rest671) => let val result=MlyValue.TY(fn _ => let val TY1=TY1 
()
val TY2=TY2 ()
 in (TY1 ^ " -> " ^ TY2) end
)
 in (LrTable.NT 13,(result,TY1left,TY2right),rest671) end
| (41,(_,(MlyValue.TY TY1,_,TY1right))::_::(_,(MlyValue.LABEL LABEL1,_
,_))::_::(_,(MlyValue.RECORD_LIST RECORD_LIST1,RECORD_LIST1left,_))::
rest671) => let val result=MlyValue.RECORD_LIST(fn _ => let val 
RECORD_LIST as RECORD_LIST1=RECORD_LIST1 ()
val LABEL as LABEL1=LABEL1 ()
val TY as TY1=TY1 ()
 in (RECORD_LIST^","^LABEL^":"^TY) end
)
 in (LrTable.NT 7,(result,RECORD_LIST1left,TY1right),rest671) end
| (42,(_,(MlyValue.TY TY1,_,TY1right))::_::(_,(MlyValue.LABEL LABEL1,
LABEL1left,_))::rest671) => let val result=MlyValue.RECORD_LIST(fn _
 => let val LABEL as LABEL1=LABEL1 ()
val TY as TY1=TY1 ()
 in (LABEL^":"^TY) end
)
 in (LrTable.NT 7,(result,LABEL1left,TY1right),rest671) end
| (43,(_,(MlyValue.ID ID1,ID1left,ID1right))::rest671) => let val 
result=MlyValue.QUAL_ID(fn _ => let val ID as ID1=ID1 ()
 in ((fn (a,_) => a) ID) end
)
 in (LrTable.NT 6,(result,ID1left,ID1right),rest671) end
| (44,(_,(MlyValue.QUAL_ID QUAL_ID1,_,QUAL_ID1right))::(_,(
MlyValue.IDDOT IDDOT1,IDDOT1left,_))::rest671) => let val result=
MlyValue.QUAL_ID(fn _ => let val IDDOT as IDDOT1=IDDOT1 ()
val QUAL_ID as QUAL_ID1=QUAL_ID1 ()
 in (IDDOT^QUAL_ID) end
)
 in (LrTable.NT 6,(result,IDDOT1left,QUAL_ID1right),rest671) end
| (45,(_,(MlyValue.ID ID1,ID1left,ID1right))::rest671) => let val 
result=MlyValue.LABEL(fn _ => let val ID as ID1=ID1 ()
 in ((fn (a,_) => a) ID) end
)
 in (LrTable.NT 3,(result,ID1left,ID1right),rest671) end
| (46,(_,(MlyValue.INT INT1,INT1left,INT1right))::rest671) => let val 
result=MlyValue.LABEL(fn _ => let val INT as INT1=INT1 ()
 in (INT) end
)
 in (LrTable.NT 3,(result,INT1left,INT1right),rest671) end
| (47,(_,(MlyValue.ID ID1,_,ID1right))::(_,(_,PREC_TAG1left,_))::
rest671) => let val result=MlyValue.G_RULE_PREC(fn _ => let val ID as 
ID1=ID1 ()
 in (SOME (symbolMake ID)) end
)
 in (LrTable.NT 11,(result,PREC_TAG1left,ID1right),rest671) end
| (48,rest671) => let val result=MlyValue.G_RULE_PREC(fn _ => (NONE))
 in (LrTable.NT 11,(result,defaultPos,defaultPos),rest671) end
| _ => raise (mlyAction i392)
end
val void = MlyValue.VOID
val extract = fn a => (fn MlyValue.BEGIN x => x
| _ => let exception ParseInternal
	in raise ParseInternal end) a ()
end
end
structure Tokens : Mlyacc_TOKENS =
struct
type svalue = ParserData.svalue
type ('a,'b) token = ('a,'b) Token.token
fun ARROW (p1,p2) = Token.TOKEN (ParserData.LrTable.T 0,(
ParserData.MlyValue.VOID,p1,p2))
fun ASTERISK (p1,p2) = Token.TOKEN (ParserData.LrTable.T 1,(
ParserData.MlyValue.VOID,p1,p2))
fun BLOCK (p1,p2) = Token.TOKEN (ParserData.LrTable.T 2,(
ParserData.MlyValue.VOID,p1,p2))
fun BAR (p1,p2) = Token.TOKEN (ParserData.LrTable.T 3,(
ParserData.MlyValue.VOID,p1,p2))
fun COLON (p1,p2) = Token.TOKEN (ParserData.LrTable.T 4,(
ParserData.MlyValue.VOID,p1,p2))
fun COMMA (p1,p2) = Token.TOKEN (ParserData.LrTable.T 5,(
ParserData.MlyValue.VOID,p1,p2))
fun DELIMITER (p1,p2) = Token.TOKEN (ParserData.LrTable.T 6,(
ParserData.MlyValue.VOID,p1,p2))
fun EOF (p1,p2) = Token.TOKEN (ParserData.LrTable.T 7,(
ParserData.MlyValue.VOID,p1,p2))
fun EQUAL (p1,p2) = Token.TOKEN (ParserData.LrTable.T 8,(
ParserData.MlyValue.VOID,p1,p2))
fun FOR (p1,p2) = Token.TOKEN (ParserData.LrTable.T 9,(
ParserData.MlyValue.VOID,p1,p2))
fun HEADER (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 10,(
ParserData.MlyValue.HEADER (fn () => i),p1,p2))
fun ID (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 11,(
ParserData.MlyValue.ID (fn () => i),p1,p2))
fun IDDOT (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 12,(
ParserData.MlyValue.IDDOT (fn () => i),p1,p2))
fun PERCENT_HEADER (p1,p2) = Token.TOKEN (ParserData.LrTable.T 13,(
ParserData.MlyValue.VOID,p1,p2))
fun INT (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 14,(
ParserData.MlyValue.INT (fn () => i),p1,p2))
fun KEYWORD (p1,p2) = Token.TOKEN (ParserData.LrTable.T 15,(
ParserData.MlyValue.VOID,p1,p2))
fun LBRACE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 16,(
ParserData.MlyValue.VOID,p1,p2))
fun LPAREN (p1,p2) = Token.TOKEN (ParserData.LrTable.T 17,(
ParserData.MlyValue.VOID,p1,p2))
fun NAME (p1,p2) = Token.TOKEN (ParserData.LrTable.T 18,(
ParserData.MlyValue.VOID,p1,p2))
fun NODEFAULT (p1,p2) = Token.TOKEN (ParserData.LrTable.T 19,(
ParserData.MlyValue.VOID,p1,p2))
fun NONTERM (p1,p2) = Token.TOKEN (ParserData.LrTable.T 20,(
ParserData.MlyValue.VOID,p1,p2))
fun NOSHIFT (p1,p2) = Token.TOKEN (ParserData.LrTable.T 21,(
ParserData.MlyValue.VOID,p1,p2))
fun OF (p1,p2) = Token.TOKEN (ParserData.LrTable.T 22,(
ParserData.MlyValue.VOID,p1,p2))
fun PERCENT_EOP (p1,p2) = Token.TOKEN (ParserData.LrTable.T 23,(
ParserData.MlyValue.VOID,p1,p2))
fun PERCENT_PURE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 24,(
ParserData.MlyValue.VOID,p1,p2))
fun PERCENT_POS (p1,p2) = Token.TOKEN (ParserData.LrTable.T 25,(
ParserData.MlyValue.VOID,p1,p2))
fun PERCENT_ARG (p1,p2) = Token.TOKEN (ParserData.LrTable.T 26,(
ParserData.MlyValue.VOID,p1,p2))
fun PREC (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 27,(
ParserData.MlyValue.PREC (fn () => i),p1,p2))
fun PREC_TAG (p1,p2) = Token.TOKEN (ParserData.LrTable.T 28,(
ParserData.MlyValue.VOID,p1,p2))
fun PREFER (p1,p2) = Token.TOKEN (ParserData.LrTable.T 29,(
ParserData.MlyValue.VOID,p1,p2))
fun PROG (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 30,(
ParserData.MlyValue.PROG (fn () => i),p1,p2))
fun RBRACE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 31,(
ParserData.MlyValue.VOID,p1,p2))
fun RPAREN (p1,p2) = Token.TOKEN (ParserData.LrTable.T 32,(
ParserData.MlyValue.VOID,p1,p2))
fun SUBST (p1,p2) = Token.TOKEN (ParserData.LrTable.T 33,(
ParserData.MlyValue.VOID,p1,p2))
fun START (p1,p2) = Token.TOKEN (ParserData.LrTable.T 34,(
ParserData.MlyValue.VOID,p1,p2))
fun TERM (p1,p2) = Token.TOKEN (ParserData.LrTable.T 35,(
ParserData.MlyValue.VOID,p1,p2))
fun TYVAR (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 36,(
ParserData.MlyValue.TYVAR (fn () => i),p1,p2))
fun VERBOSE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 37,(
ParserData.MlyValue.VOID,p1,p2))
fun VALUE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 38,(
ParserData.MlyValue.VOID,p1,p2))
fun UNKNOWN (i,p1,p2) = Token.TOKEN (ParserData.LrTable.T 39,(
ParserData.MlyValue.UNKNOWN (fn () => i),p1,p2))
fun BOGUS_VALUE (p1,p2) = Token.TOKEN (ParserData.LrTable.T 40,(
ParserData.MlyValue.VOID,p1,p2))
end
end
