(* Copyright 1989 by AT&T Bell Laboratories *)
(* coreinfo.sml *)

(* info extracted from Core structure *)

structure CoreInfo : COREINFO =
struct

  open Access Basics EnvAcc
  val bogusCON = DATACON{name=Symbol.symbol "bogus",const=true,
			 typ=BasicTyp.exnTy,
			 rep=CONSTANT 0,sign=[]}

  val exnBind = ref(bogusCON)
  val exnMatch = ref(bogusCON)
  val stringequalPath = ref[0]
  val polyequalPath = ref[0]
  val currentPath = ref[0]
  val toplevelPath = ref[0]
  val forcerPath = ref[0]
  val getDebugVar = ref(mkVALvar (Symbol.symbol "getDebug"))

  fun resetCore () = 
      (exnBind := bogusCON; exnMatch := bogusCON;
       stringequalPath := [0];       polyequalPath := [0];
       currentPath := [0];       toplevelPath := [0];
       forcerPath := [0])

  fun setCore(STRvar{access=PATH p,binding,...}) =
      let fun extractPath name = 
	      let val sym = Symbol.symbol name
		  val VARbind(VALvar{access=PATH p,...}) =
			lookVARCONinStr(binding, sym, p, [sym],
					ErrorMsg.impossible)
	       in p
	      end
	  fun coreCon name = 
	      let val CONbind c = lookVARCONinStr(binding,name,p,[name],
						   ErrorMsg.impossible)
	       in c
	      end
       in exnBind := coreCon(Symbol.symbol "Bind");
	  exnMatch := coreCon(Symbol.symbol "Match");
	  stringequalPath := extractPath "stringequal";
	  forcerPath := extractPath "forcer_p";
	  polyequalPath := extractPath "polyequal";
	  currentPath := extractPath "current";
	  toplevelPath := extractPath "toplevel";
	  getDebugVar := let val name = Symbol.symbol "getDebug"
			     val VARbind x = lookVARCONinStr(binding,name,p,
						[name],ErrorMsg.impossible)
			  in x
			 end
      end
    | setCore _ = ErrorMsg.impossible "EnvAcc.setCore"

end (* CoreInfo *)
