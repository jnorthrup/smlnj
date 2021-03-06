(* flint-opt.sml
 *
 * COPYRIGHT (c) 2019 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *)

structure FLINTOpt : sig

  (* the int option gets passed to lambda-split phases (if any) *)
    val optimize : FLINT.prog * Absyn.dec CompInfo.compInfo -> FLINT.prog

  end = struct

    structure CTRL = FLINT_Control
    structure PP = PPFlint
    structure LT = LtyExtern
    structure F  = FLINT

    fun bug s = ErrorMsg.impossible ("FLINTOpt:" ^ s)
    val say = Control_Print.say

    datatype flintkind = FK_WRAP | FK_REIFY | FK_DEBRUIJN | FK_NAMED

    fun phase x = Stats.doPhase (Stats.makePhase x)

    val deb2names = phase "FLINT 056 deb2names" TvarCvt.debIndex2names
    val names2deb = phase "FLINT 057 names2deb" TvarCvt.names2debIndex

    val lcontract = phase "FLINT 052 lcontract" LContract.lcontract
    (*  val lcontract' = phase "FLINT 052 lcontract'" LContract.lcontract *)
    val fcollect  = phase "FLINT 052a fcollect" Collect.collect
    val fcontract = phase "FLINT 052b fcontract"
			  (fn (opts,lexp) => FContract.contract opts lexp)
    val fcontract = fn opts => fn lexp => fcontract(opts, fcollect lexp)
    val loopify   = phase "FLINT 057 loopify" Loopify.loopify
    val fixfix    = phase "FLINT 056 fixfix" FixFix.fixfix

    val typelift  = phase "FLINT 0535 typelift" Lift.typeLift
    val wformed   = phase "FLINT 0536 wformed" Lift.wellFormed

    val specialize= phase "FLINT 053 specialize" Specialize.specialize
    val wrapping  = phase "FLINT 054 wrapping" Wrapping.wrapping
    val reify     = phase "FLINT 055 reify" Reify.reify
    val recover   = phase "FLINT 05a recover" Recover.recover

  (** pretty printing FLINT code *)
    fun prF s e = if !CTRL.print
	  then (
	    say (concat["\n[After ", s, " ...]\n\n"]);
	    PPFlint.printProg e;
	    say "\n"; e)
	  else e

  (** writing out a term into a error output file *)
    fun dumpTerm (printE, s, le) = let
          val outS = TextIO.openAppend s;
	  val saveOut = !Control.Print.out
	  fun done () = (
	        TextIO.closeOut outS; Control.Print.out := saveOut)
          in
	    Control.Print.out := {
		say = fn s => TextIO.output(outS,s),
		flush = fn () => TextIO.flushOut outS
	      };
	    printE le handle x => (done () handle _ => (); raise x);
	    done ()
          end (* function dumpTerm *)

    val fcs : (FLINT.prog -> FLINT.prog) list ref = ref []

  (** optimizing FLINT code *)
    fun optimize (flint, compInfo: Absyn.dec CompInfo.compInfo) = let
	  val {sourceName=src, ...} = compInfo

	  fun check (checkE, printE, chkId) (lvl,logId) e = if checkE (e,lvl)
		then (
		  dumpTerm (printE, src ^ "." ^ chkId ^ logId, e);
		  bug (chkId ^ " typing errors " ^ logId))
		else ()
	  fun wff (f, s) = if wformed f
		then ()
		else print ("\nAfter " ^ s ^ " CODE NOT WELL FORMED\n")

	 (* f:prog        flint code
	  * fk:flintkind  what kind of flint variant this is
	  * l:string      last phase through which it went
	  *)
	  fun runphase (p, (f, fk, l)) = (case (p, fk)
		 of (("fcontract" | "lcontract"), FK_DEBRUIJN) => (
		      say("\n!! "^p^" cannot be applied to the DeBruijn form !!\n");
		      (f, fk, l))
		  | ("fcontract",_) =>
		    (fcontract {etaSplit=false, tfnInline=false} f,  fk, p)
		  | ("fcontract+eta",_)	=>
		    (fcontract {etaSplit=true, tfnInline=false} f,  fk, p)
		  | ("lcontract",_) => (lcontract f,  fk, p)
		  | ("fixfix", _) => (fixfix f, fk, p)
		  | ("loopify", _) => (loopify f, fk, p)
		  | ("specialize", FK_NAMED) => (specialize f, fk, p)
		  | ("wrap", FK_NAMED) => (wrapping f, FK_WRAP, p)
		  | ("reify", FK_WRAP) => (reify f, FK_REIFY, p)
		  | ("deb2names",FK_DEBRUIJN) => (deb2names f, FK_NAMED, p)
		  | ("names2deb",FK_NAMED) => (names2deb f, FK_DEBRUIJN, p)
		  | ("typelift", _) => let
		      val f = typelift f
		      in
			if !CTRL.check then wff(f, p) else ();
			(f, fk, p)
		      end
		  (* pseudo FLINT phases *)
		  | ("collect", _) => (fcollect f, fk, p)
		  | _ => (case (p, fk)
		       of ("id",_) => ()
			| ("wellformed",_) => wff(f,l)
			| ("recover",_) => let
			    val {getLty,...} = recover(f, fk = FK_REIFY)
			    in
			      CTRL.recover := (say o LT.lt_print o getLty o F.VAR)
			    end
			| ("print",_) =>
			    (say("\n[After "^l^"...]\n\n"); PP.printFundec f; say "\n")
			| ("check",_) =>
			    (check (ChkFlint.checkTop, PPFlint.printFundec, "FLINT")
				   (fk = FK_REIFY, l) f)
			| _ => say(concat[
			      "\n!! Unknown or badly scheduled FLINT phase '", p, "' !!\n"
			    ])
		     (* end case *);
		     (f, fk, l))
		(* end case *))

	  fun print (f, fk, l) = (prF l f; (f, fk, l))
	  fun check' (f, fk , l) = let
		fun c n reified f =
		      check (ChkFlint.checkTop, PPFlint.printFundec, n)
			    (reified, l) (names2deb f)
	        in
		  if !CTRL.check
		    then (c "FLINT" (fk = FK_REIFY) f; ())
		    else ();
		  (f, fk, l)
		end

	  fun showhist [s] = say(concat["  raised at:\t", s, "\n"])
	    | showhist (s::r) = (showhist r; say (concat["\t\t", s, "\n"]))
	    | showhist [] = ()

	  fun runphase' (arg as (p,{1=f,...})) =
	      (if !CTRL.printPhases then say("Phase "^p^"...") else ();
	       ((check' o print o runphase) arg) before
	       (if !CTRL.printPhases then say("..."^p^" Done.\n") else ()))
		  handle x => (say ("\nwhile in "^p^" phase\n");
			       dumpTerm(PPFlint.printFundec, "flint.core", f);
			       showhist(SMLofNJ.exnHistory x);
			       raise x)

	  val (flint, fk, _) = foldl runphase'
				      (flint, FK_DEBRUIJN, "flintnm")
				      ((* "id" :: *) "deb2names" :: !CTRL.phases)

        (* run any missing phases *)
	  val (flint,fk) =
	      if fk = FK_DEBRUIJN
	      then (say "\n!!Forgot deb2names!!\n"; (deb2names flint, FK_NAMED))
	      else (flint,fk)
	  val (flint,fk) =
	      if fk = FK_NAMED
	      then (say "\n!!Forgot wrap!!\n"; (wrapping flint, FK_WRAP))
	      else (flint,fk)
	  val (flint,fk) =
	      if fk = FK_WRAP
	      then (say "\n!!Forgot reify!!\n"; (reify flint, FK_REIFY))
	      else (flint,fk)
	  in
	    flint
	  end (* function flintcomp *)

    val optimize = phase "FLINT 050 flintopt" optimize

  end (* structure FLINTOpt *)
