exception Error

type pos = int
type svalue = Tokens.svalue
type ('a,'b) token = ('a,'b) Tokens.token
type lexresult = (svalue,pos) token
type lexarg = {srcMap : SourceMap.sourcemap,
               err    : pos * pos * string -> unit
              }
type arg = lexarg

open Tokens

val commentLevel = ref 0
val metaLevel = ref 0

val asmLQuote = ref "``"
val asmRQuote = ref "''"
val asmLMeta  = ref "<"
val asmRMeta  = ref ">"

exception Error

fun init() = (commentLevel := 0; metaLevel := 0;
	      asmLQuote := "``"; asmRQuote := "''";
	      asmLMeta := "<"; asmRMeta := ">"
	     )

fun eof{srcMap,err} = 
    let val pos = SourceMap.currPos srcMap
    in  EOF(pos,pos) end
fun debug _ = ()

fun check(err,_,_,SOME w) = w
  | check(err,pos,s,NONE) = 
      (err(pos,pos+size s,"bad literal "^s); raise Error)

fun strip k s = String.substring(s,k,String.size s - k)
fun scan err fmt (s,s') tok pos = 
      tok(check(err,pos,s,StringCvt.scanString fmt s'),
                pos,pos + size s) 
      handle _ => ID(s,pos,pos)

fun wdecimal(err,s,pos) = 
      scan err (Word32.scan StringCvt.DEC) (s,strip 2 s) WORD pos
fun whex(err,s,pos) = 
      scan err (Word32.scan StringCvt.HEX) (s,strip 3 s) WORD pos
fun woctal(err,s,pos) = scan err (Word32.scan StringCvt.OCT) (s,strip 3 s) WORD pos
fun wbinary(err,s,pos) = scan err (Word32.scan StringCvt.BIN) (s,strip 3 s) WORD pos
fun decimal(err,s,pos) = scan err (Int.scan StringCvt.DEC) (s,s) INT pos
fun hex(err,s,pos) = scan err (Int.scan StringCvt.HEX) (s,strip 2 s) INT pos
fun octal(err,s,pos) = scan err (Int.scan StringCvt.OCT) (s,strip 2 s) INT pos
fun binary(err,s,pos) = scan err (Int.scan StringCvt.BIN) (s,strip 2 s) INT pos

fun string(err,s,pos) = 
  STRING(
    check(err,pos,s,String.fromString(String.substring(s,1,String.size s-2))),
    pos, pos + size s)
fun char(err,s,pos) = 
  CHAR(check(err,pos,s,Char.fromString(String.substring(s,2,String.size s-3))),
       pos,pos + size s)
fun asmtext(err,s,pos) = 
  ASMTEXT(check(err,pos,s,String.fromString s),pos,pos + size s)

infix $$ 
fun x $$ y = y :: x 

exception NotFound

val keywords = HashTable.mkTable (HashString.hashString,op =) (13,NotFound) 
               : (string,int * int -> (svalue,int) token) HashTable.hash_table
val symbols  = HashTable.mkTable (HashString.hashString,op =) (13,NotFound)
               : (string,int * int -> (svalue,int) token) HashTable.hash_table

val _ = app (HashTable.insert keywords) 
( nil       $$
 ("_",WILD) $$
 ("architecture", ARCHITECTURE) $$
 ("name", NAME) $$
 ("version", VERSION) $$
 ("datatype", DATATYPE) $$
 ("type", TYPE) $$
 ("end", END) $$
 ("fun", FUN) $$
 ("fn", FN) $$
 ("val", VAL) $$
 ("raise", RAISE) $$
 ("handle", HANDLE) $$
 ("let", LET) $$
 ("local", LOCAL) $$
 ("structure", STRUCTURE) $$
 ("signature", SIGNATURE) $$
 ("storage", STORAGE) $$
 ("locations", LOCATIONS) $$
 ("called", CALLED) $$
 ("functor", FUNCTOR) $$
 ("sig", SIG) $$
 ("struct", STRUCT) $$
 ("sharing", SHARING) $$
 ("where", WHERE) $$
 ("if", IF) $$
 ("then", THEN) $$
 ("else", ELSE) $$
 ("in", IN) $$
 ("true", TRUE) $$
 ("false", FALSE) $$
 ("and", AND) $$
 ("at", AT) $$
 ("opcode", OPCODE) $$
 ("vliw", VLIW) $$
 ("field", FIELD) $$
 ("fields", FIELDS) $$
 ("signed", SIGNED) $$
 ("unsigned", UNSIGNED) $$
 ("superscalar", SUPERSCALAR) $$
 ("of", OF) $$
 ("case", CASE) $$
 ("bits", BITS) $$
 ("ordering", ORDERING) $$
 ("little", LITTLE) $$
 ("big", BIG) $$
 ("endian", ENDIAN) $$
 ("register", REGISTER) $$
 ("as", AS) $$
 ("formats", FORMATS) $$
 ("cell", CELL) $$
 ("cells", CELLS) $$
 ("cellset", CELLSET) $$
 ("pipeline", PIPELINE) $$
 ("cpu", CPU) $$
 ("resource", RESOURCE) $$
 ("reservation", RESERVATION) $$
 ("table", TABLE) $$
 ("latency", LATENCY) $$
 ("predicated", PREDICATED) $$
 ("instruction", INSTRUCTION) $$
 ("uppercase", UPPERCASE) $$
 ("lowercase", LOWERCASE) $$
 ("verbatim", VERBATIM) $$
 ("assembly", ASSEMBLY) $$
 ("span", SPAN) $$
 ("dependent", DEPENDENT) $$
 ("nullified", NULLIFIED) $$
 ("always", ALWAYS) $$
 ("never", NEVER) $$
 ("forwards", FORWARDS) $$
 ("backwards", BACKWARDS) $$
 ("delayslot", DELAYSLOT) $$
 ("nodelayslot", NODELAYSLOT) $$
 ("branching", BRANCHING) $$
 ("when", WHEN) $$
 ("candidate", CANDIDATE) $$
 ("rtl", RTL) $$
 ("open", OPEN) $$
 ("include", INCLUDE) $$
 ("infix", INFIX) $$
 ("infixr", INFIXR) $$
 ("nonfix", NONFIX) $$
 ("debug", DEBUG) $$
 ("zero", ZERO) $$
 ("not", NOT) 
)

val _ = app (HashTable.insert symbols) 
(
  nil $$
  ("=",	EQ) $$
  ("*",	TIMES) $$
  ("$",	DOLLAR) $$
  (":",	COLON) $$
  (".",	DOT) $$
  ("..", DOTDOT) $$
  ("...", DOTDOT) $$
  ("|", BAR) $$
  ("->", ARROW) $$
  ("=>", DARROW) $$
  ("#", HASH) $$
  ("!", DEREF) $$
  ("^^", CONCAT)
)

fun lookup(s,yypos) =
let val l = String.size s
in  HashTable.lookup keywords s (yypos,yypos + l) 
      handle _ => ID(Symbol.toString(Symbol.new s), yypos, yypos + l)
end

fun lookupSym(s,yypos) =
let val l = String.size s
in  HashTable.lookup symbols s (yypos,yypos + l) 
      handle _ => SYMBOL(Symbol.toString(Symbol.new s), yypos, yypos + l)
end

%%

%header (functor MDLexFun(Tokens : MD_TOKENS));
%arg ({srcMap,err});

alpha=[A-Za-z];
digit=[0-9];
id=[A-Za-z_][A-Za-z0-9_\']*;
tyvar=\'{id};
decimal={digit}+;
integer=-?{decimal};
octal=0[0-7]+;
hex=0x[0-9a-fA-F]+;
binary=0b[0-1]+;
wdecimal=0w{digit}+;
woctal=0w0[0-7]+;
whex=0wx[0-9a-fA-F]+;
wbinary=0wb[0-1]+;
ws=[\ \t];
string=\"([^\\\n\t"]|\\.)*\";
char=#\"([^\\\n\t"]|\\.)*\";
sym1=(\-|[=\.+~/*:!@#$%^&*|?])+;
sym2=`+|'+|\<+|\>+|\=\>|~\>\>;
asmsymbol={sym1}|{sym2};
symbol=(\-|[=\.+~/*:!@#$%^&*|?<>])+|``|'';
asmtext=([^\n\t<>']+|');

%s COMMENT ASM ASMQUOTE;

%%
<INITIAL,COMMENT,ASM>\n		=> (SourceMap.newline srcMap yypos; continue());
<INITIAL,COMMENT,ASM>{ws}	=> (continue());
<ASMQUOTE>\n		=> (err(yypos,yypos+size yytext,
                                "newline in assembly text!"); continue());
<INITIAL>\-\-.*\n	=> (continue());
<INITIAL>"(*"		=> (commentLevel := 1; YYBEGIN COMMENT; continue());
<INITIAL,ASM>{decimal}	=> (decimal(err,yytext,yypos));
<INITIAL,ASM>{hex}	=> (hex(err,yytext,yypos));
<INITIAL,ASM>{octal}	=> (octal(err,yytext,yypos));
<INITIAL,ASM>{binary}	=> (binary(err,yytext,yypos));
<INITIAL,ASM>{wdecimal}	=> (wdecimal(err,yytext,yypos));
<INITIAL,ASM>{whex}	=> (whex(err,yytext,yypos));
<INITIAL,ASM>{woctal}	=> (woctal(err,yytext,yypos));
<INITIAL,ASM>{wbinary}	=> (wbinary(err,yytext,yypos));
<INITIAL,ASM>{string}	=> (string(err,yytext,yypos));
<INITIAL,ASM>{char}	=> (char(err,yytext,yypos));
<INITIAL,ASM>"asm:"     => (ASM_COLON(yypos,yypos + size yytext));
<INITIAL,ASM>"mc:"      => (MC_COLON(yypos,yypos + size yytext));
<INITIAL,ASM>"rtl:"     => (RTL_COLON(yypos,yypos + size yytext));
<INITIAL,ASM>"delayslot:" => (DELAYSLOT_COLON(yypos,size yytext));
<INITIAL,ASM>"padding:" => (PADDING_COLON(yypos,size yytext));
<INITIAL,ASM>"nullified:" => (NULLIFIED_COLON(yypos,size yytext));
<INITIAL,ASM>"candidate:" => (CANDIDATE_COLON(yypos,size yytext));
<INITIAL,ASM>{id}	=> (lookup(yytext,yypos));
<INITIAL,ASM>{tyvar}	=> (TYVAR(yytext,yypos,yypos + size yytext));
<INITIAL,ASM>"("	=> (LPAREN(yypos,yypos+1));
<INITIAL,ASM>")"	=> (RPAREN(yypos,yypos+1));
<INITIAL,ASM>"["	=> (LBRACKET(yypos,yypos+1));
<INITIAL,ASM>"]"	=> (RBRACKET(yypos,yypos+1));
<INITIAL,ASM>"[["	=> (LLBRACKET(yypos,yypos+2));
<INITIAL,ASM>"]]"	=> (RRBRACKET(yypos,yypos+2));
<INITIAL,ASM>"{"	=> (LBRACE(yypos,yypos+1));
<INITIAL,ASM>"}"	=> (RBRACE(yypos,yypos+1));
<INITIAL,ASM>","	=> (COMMA(yypos,yypos+1));
<INITIAL,ASM>";"	=> (SEMICOLON(yypos,yypos+1));

<INITIAL>{symbol}	=> (if yytext = !asmLQuote then
				(debug("lquote "^yytext^"\n");
				 YYBEGIN ASMQUOTE; 
                                 LDQUOTE(yypos,yypos+size yytext))
			    else
			        lookupSym(yytext,yypos));
<ASMQUOTE>{asmsymbol}	=> (if yytext = !asmRQuote then
				(if !metaLevel <> 0 then
                                    err(yypos,yypos+size yytext,
                                       "Mismatch between "^(!asmLMeta)^
                                          " and "^(!asmRMeta)) else ();
				 debug("rquote "^yytext^"\n");
                                 YYBEGIN INITIAL; 
                                 RDQUOTE(yypos,yypos+size yytext))
			    else if yytext = !asmLMeta then
				(metaLevel := !metaLevel + 1;
				 debug("lmeta "^yytext^"\n");
				 YYBEGIN ASM; LMETA(yypos,yypos+size yytext))
			    else
			        asmtext(err,yytext,yypos));
<ASM>{asmsymbol}	=> (if yytext = !asmRMeta then
				(metaLevel := !metaLevel - 1;
				 debug("rmeta "^yytext^"("^Int.toString(!metaLevel)^")\n");
				 if !metaLevel = 0 then YYBEGIN ASMQUOTE
				 else (); RMETA(yypos,yypos+size yytext))
			    else
			        lookupSym(yytext,yypos));
<ASMQUOTE>{asmtext}	=> (debug("text="^yytext^"\n"); 
                            asmtext(err,yytext,yypos));
<COMMENT>"*)"		=> (commentLevel := !commentLevel - 1;
			    if !commentLevel = 0 then YYBEGIN INITIAL else (); 
			    continue());
<COMMENT>"(*"		=> (commentLevel := !commentLevel + 1; continue());
<COMMENT>.		=> (continue());
.			=> (err(yypos,yypos+size yytext,
                                "unknown character "^String.toString yytext);
                            continue());
