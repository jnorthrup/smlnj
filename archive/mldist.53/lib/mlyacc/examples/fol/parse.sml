(* Uses the generated lexer and parser to export parsing functions *)

signature PARSE =
sig

structure Absyn : ABSYN

(* parse a program from a string *)

    val prog_parse : string -> Absyn.absyn 

(* parse a query from a string *)

    val query_parse : string -> Absyn.absyn

(* parse a program in a file *)

    val file_parse : string -> Absyn.absyn
 
(* parse a query from the standard input *)

    val top_parse : unit -> Absyn.absyn

end  (* signature PARSE *)


functor Parse (structure Absyn : ABSYN
	       structure Interface : INTERFACE
	       structure Parser : PARSER
	          sharing type Parser.arg = Interface.arg
	          sharing type Parser.pos = Interface.pos
		  sharing type Parser.result = Absyn.absyn
	       structure Tokens : Fol_TOKENS
	          sharing type Tokens.token = Parser.Token.token
		  sharing type Tokens.svalue = Parser.svalue
               ) : PARSE =
struct

structure Absyn = Absyn

val parse = fn (dummyToken,lookahead,reader : int -> string) =>
    let val _ = Interface.init_line()
	val empty = !Interface.line
	val dummyEOF = Tokens.EOF(empty,empty)
	val dummyTOKEN = dummyToken(empty,empty)
	fun invoke lexer = 
	   let val newLexer = Parser.Stream.cons(dummyTOKEN,lexer)
	   in Parser.parse(lookahead,newLexer,Interface.error,
				Interface.nothing)
	   end
        fun loop lexer =
	  let val (result,lexer) = invoke lexer
	      val (nextToken,lexer) = Parser.Stream.get lexer
	  in if Parser.sameToken(nextToken,dummyEOF) then result
	     else loop lexer
	  end
     in loop (Parser.makeLexer reader)
     end

fun string_reader s =
 let val next = ref s
 in fn _ => !next before next := ""
 end
    
val prog_parse = fn s => parse (Tokens.PARSEPROG,15,string_reader s)

val query_parse = fn s => parse (Tokens.PARSEQUERY,15,string_reader s)

val file_parse = fn name =>
  let val dev = open_in name
   in (parse (Tokens.PARSEPROG,15,input dev)) before close_in dev
   end

val top_parse = fn () => parse (Tokens.PARSEQUERY,0,fn i => input_line std_in)

end  (* functor Parse *)
