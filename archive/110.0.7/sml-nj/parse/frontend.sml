(* Copyright 1996 by AT&T Bell Laboratories *)
(* frontend.sml *)

signature FRONT_END = 
sig
    datatype parseResult
      = EOF   
      | ERROR 
      | ABORT 
      | PARSE of Ast.dec

    val parse : Source.inputSource -> unit -> parseResult
end (* signature FRONT_END *)

structure FrontEnd : FRONT_END =
struct 

structure MLLrVals = MLLrValsFun(structure Token = LrParser.Token)
structure Lex = MLLexFun(structure Tokens = MLLrVals.Tokens)
structure MLP = JoinWithArg(structure ParserData = MLLrVals.ParserData
                            structure Lex=Lex
                            structure LrParser = LrParser)

open ErrorMsg
structure T = Time

(* the following two functions are also defined in build/computil.sml *)
fun debugmsg  (msg : string) =
  let val printit = !Control.debugging
   in if printit then app Control.Print.say[msg, "\n"] else ();
      printit
  end

val addLines = Stats.addStat(Stats.makeStat "Source Lines")

datatype parseResult
  = EOF   (* end of file reached *)
  | ERROR (* parsed successfully, but with syntactic or semantic errors *)
  | ABORT (* could not even parse to end of declaration *)
  | PARSE of Ast.dec

val dummyEOF = MLLrVals.Tokens.EOF(0,0)
val dummySEMI = MLLrVals.Tokens.SEMICOLON(0,0)

fun parse (source as {sourceStream,errConsumer,interactive,
                      sourceMap, anyErrors,...}: Source.inputSource) =
  let val err = ErrorMsg.error source
      val complainMatch = ErrorMsg.matchErrorString source

      fun parseerror(s,p1,p2) = err (p1,p2) COMPLAIN s nullErrorBody

      val lexarg = {comLevel = ref 0,
                    sourceMap = sourceMap,
                    charlist = ref (nil : string list),
                    stringtype = ref false,
                    stringstart = ref 0,
                    err = err,
                    brack_stack = ref (nil: int ref list)}

      val doprompt = ref true
      val prompt = ref (!Control.primaryPrompt)

      fun inputc_sourceStream _ = TextIO.input(sourceStream)

      exception AbortLex
      fun getline k =
        (if !doprompt
         then (if !anyErrors then raise AbortLex else ();
               Control.Print.say
                (if !(#comLevel lexarg) > 0
                    orelse !(#charlist lexarg) <> nil
                 then !Control.secondaryPrompt
                 else !prompt);
               Control.Print.flush();
               doprompt := false)
         else ();
         let val s = inputc_sourceStream k
          in doprompt := ((String.sub(s,size s - 1) = #"\n")
                          handle _ => false);
             s
         end)

      val lexer = 
        Lex.makeLexer (if interactive then getline 
                       else inputc_sourceStream) lexarg
      val lexer' = ref(LrParser.Stream.streamify lexer)
      val lookahead = if interactive then 0 else 30

      fun oneparse () =
        let val _ = prompt := !Control.primaryPrompt
            val (nextToken,rest) = LrParser.Stream.get(!lexer') 

            val startpos = SourceMap.lastChange sourceMap
            fun linesRead() = SourceMap.newlineCount sourceMap 
                      (startpos, SourceMap.lastChange sourceMap)
         in (*if interactive then SourceMap.forgetOldPositions sourceMap 
              else ();*)
            if MLP.sameToken(nextToken,dummySEMI) 
            then (lexer' := rest; oneparse ())
            else if MLP.sameToken(nextToken,dummyEOF)
                 then EOF
                 else let val _ = prompt := !Control.secondaryPrompt;
                          val (result, lexer'') =
                            MLP.parse(lookahead,!lexer',parseerror,err)
                          val _ = addLines(linesRead())
                          val _ = lexer' := lexer''
                       in if !anyErrors then ERROR else PARSE result
                      end 
        end handle LrParser.ParseError => ABORT
                 | AbortLex => ABORT
            (* oneparse *)
   in fn () => (anyErrors := false; oneparse ())
  end

end (* structure FrontEnd *)


(*
 * $Log: frontend.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:47  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:43  george
 *   Version 109.24
 *
 *)
