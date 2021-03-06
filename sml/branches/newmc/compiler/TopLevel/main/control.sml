(* control.sml
 *
 * COPYRIGHT (c) 2019 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *)

(* Code generation controls (including some used in FLINT?) *)
structure Control_CG : CGCONTROL =
  struct
    val priority = [10, 11, 2]
    val obscurity = 6
    val prefix = "cg"

    val registry = ControlRegistry.new { help = "code generator settings" }

    val _ = BasicControl.nest (prefix, registry, priority)

    val b = ControlUtil.Cvt.bool
    val i = ControlUtil.Cvt.int
    val r = ControlUtil.Cvt.real
    val sl = ControlUtil.Cvt.stringList

    val nextpri = ref 0

    fun new (c, n, h, d) = let
	  val r = ref d
	  val p = !nextpri
	  val ctl = Controls.control {
		  name = n,
		  pri = [p],
		  obscurity = obscurity,
		  help = h,
		  ctl = r }
	  in
	    nextpri := p + 1;
	    ControlRegistry.register
		registry
		{ ctl = Controls.stringControl c ctl,
		  envName = SOME (ControlUtil.EnvName.toUpper "CG_" n) };
	    r
	  end

    val closureStrategy = new (i, "closure-strategy", "?", 0)	(* see CPS/clos/closure.sml *)
    val cpsopt = new (sl, "cpsopt", "cps optimizer phases", [
	    "first_contract", "eta", "zeroexpand", "last_contract"
	  ])
    (* ["first_contract", "eta", "uncurry", "etasplit",
	"cycle_expand", "eta", "last_contract" ] *)
    val rounds = new (i, "rounds", "max # of cpsopt rounds", 10)
    val path = new (b, "path", "?", false)
    val betacontract = new (b, "betacontract", "?", true)
    val eta = new (b, "eta", "?", true)
    val selectopt = new (b, "selectopt", "enable contraction of record select", true)
    val dropargs = new (b, "dropargs", "?", true)
    val deadvars = new (b, "deadvars", "?", true)
    val flattenargs = new (b, "flattenargs", "?", false)
    val extraflatten = new (b, "extraflatten", "?", false)
    val switchopt = new (b, "switchopt", "?", true)
    val handlerfold = new (b, "handlerfold", "?", true)
    val branchfold = new (b, "branchfold", "?", false)
    val arithopt = new (b, "arithopt", "?", true)
    val betaexpand = new (b, "betaexpand", "?", true)
    val unroll = new (b, "unroll", "?", true)
    val invariant = new (b, "invariant", "?", true)
    val lambdaprop = new (b, "lambdaprop", "?", false)
    val newconreps = new (b, "newconreps", "?", true)
    val boxedconstconreps = ElabDataControl.boxedconstconreps
    val unroll_recur = new (b, "unroll-recur", "?", true)
    val sharepath = new (b, "sharepath", "?", true)
    val staticprof = new (b, "staticprof", "?", false)
    val verbose = new (b, "verbose", "?", false)
    val debugcps = new (b, "debugcps", "?", false)
    val bodysize = new (i, "bodysize", "?", 20)
    val reducemore = new (i, "reducemore", "?", 15)
    val comment = new (b, "comment", "?", false)
    val knownGen = new (i, "known-gen", "?", 0)
    val knownClGen = new (i, "known-cl-gen", "?", 0)
    val escapeGen = new (i, "escape-gen", "?", 0)
    val calleeGen = new (i, "callee-gen", "?", 0)
    val spillGen = new (i, "spill-gen", "?", 0)
    val etasplit = new (b, "etasplit", "?", true)
    val uncurry = new (b, "uncurry", "enable uncurrying optimization", true)
    val ifidiom = new (b, "if-idiom", "enable if-idiom optimization", true)
    val comparefold = new (b, "comparefold", "enable optimization of conditional tests", true)
    val debugLits = new (b, "debug-lits", "print results of literal lifting", false)
    val newLiterals = new (b, "new-literals", "use new literal representation", false)
    val debugRep = new (b, "debug-rep", "?", false)
    val deadup = new (b, "deadup", "?", true)
    val memDisambiguate = new (b, "mem-disambiguate", "?", false)
    val printit = new (b, "printit", "whether to show CPS", false)
    val printClusters = new (b, "print-clusters", "whether to print clusters prior to codegen", false)
  end (* structure Control_CG *)


structure Control : CONTROL =
  struct

    local
      val priority = [10, 10, 9]
      val obscurity = 4
      val prefix = "control"

      val registry = ControlRegistry.new
                         { help = "miscellaneous control settings" }

      val _ = BasicControl.nest (prefix, registry, priority)

      val bool_cvt = ControlUtil.Cvt.bool
      val string_cvt = ControlUtil.Cvt.string

      val nextpri = ref 0

      fun register (cvt_fn, name, help, defaultRef) = let
	    val p = !nextpri
	    val ctl = Controls.control {
		    name = name,
		    pri = [p],
		    obscurity = obscurity,
		    help = help,
		    ctl = defaultRef
		  }
	    in
	      nextpri := p + 1;
              ControlRegistry.register registry {
		  ctl = Controls.stringControl cvt_fn ctl,
		  envName = SOME (ControlUtil.EnvName.toUpper "CONTROL_" name)
		};
	      defaultRef
	    end

    (* `flag (n, h, d)` defines new boolean control reference with default value `d` and registers
     * it with name `n` and help message `h`.
     *)
      fun flag (name, help, default) = register (bool_cvt, name, help, ref default)

    in

    structure Print : PRINTCONTROL = Control_Print

    structure ElabData : ELABDATA_CONTROL = ElabDataControl

    (* elaborator controls *)
    structure Elab : ELAB_CONTROL = ElabControl (* Elaborator/control/elabcontrol.{sml,sig} *)

    (* match compiler controls *)
    structure MC : MC_CONTROL = MCControl (* Elaborator/control/mccontrol.{sml,sig} *)

    structure FLINT = FLINT_Control

    structure MLRISC = MLRiscControl

    structure CG : CGCONTROL = Control_CG

    open BasicControl
    (* provides: val printWarnings = ref true
     *)

    open ParserControl
    (* provides: val primaryPrompt = ref "- "
		 val secondaryPrompt = ref "= "
		 val overloadKW = ref false
		 val lazysml = ref false
		 val quotation = ref false
                 val setSuccML : bool -> unit
     *)

    val sourceName = register(string_cvt, "source", "source file or stream", ref "")
    val debugging = flag ("debugging", "?", false)
    val printAst = flag ("printAst", "whether to print Ast representation", false)
    val printAbsyn = register (bool_cvt, "printAbsyn", "whether to print Absyn representation",
			       ElabControl.printAbsyn)
    val interp = flag ("interp", "?", false)

    val progressMsgs = flag ("progressMsgs", "whether to print a message after each phase is completed", false)
    val trackExn =
	flag ("track-exn",
	     "whether to generate code that tracks exceptions", true)
    (* warning message when call of polyEqual compiled: *)
    val polyEqWarn =
	flag ("poly-eq-warn", "whether to warn about calls of polyEqual", true)

    val preserveLvarNames = flag ("preserve-names", "?", false)
    (* these are really all the same ref cell: *)
    val saveit : bool ref = ElabData.saveLvarNames
    val saveAbsyn : bool ref = saveit
    val saveLambda : bool ref = saveit
    val saveConvert : bool ref = saveit
    val saveCPSopt : bool ref = saveit
    val saveClosure : bool ref = saveit

    (* LambdaSplitting: controls the "splitting" phase of FLINT optimization
     * (FLINTOpt.optimize).  Default value of the control (returned by get) is NONE. *)
    structure LambdaSplitting = struct
	datatype globalsetting = Off | Default of int option
	type localsetting = int option option
	val UseDefault : localsetting = NONE
	fun Suggest s : localsetting = SOME s
	fun parse "off" = SOME Off
	  | parse "on" = SOME (Default NONE)
	  | parse s = Option.map (Default o SOME) (Int.fromString s)
	fun show Off = "off"
	  | show (Default NONE) = "on"
	  | show (Default (SOME i)) = Int.toString i
	local
	    val registry = ControlRegistry.new
			       { help = "cross-module inlining" }

	    val priority = [10, 10, 0, 1]

	    val _ = BasicControl.nest ("inline", registry, priority)

	    val cvt = { tyName = "Control.LambdaSplitting.globalsetting",
			fromString = parse, toString = show }
	    val state_r = ref (Default NONE)
	    val ctl = Controls.control
			  { name = "split-aggressiveness",
			    pri = [0],
			    obscurity = 1,
			    help = "aggressiveness of lambda-splitter",
			    ctl = state_r }
	    val _ = ControlRegistry.register
			registry
			{ ctl = Controls.stringControl cvt ctl,
			  envName = SOME "INLINE_SPLIT_AGGRESSIVENESS" }
	in
   	    fun set x = Controls.set (ctl, x)
	    fun get () =
		case Controls.get ctl of
		    Off => NONE
		  | Default d => d
	    fun get' NONE = get ()
	      | get' (SOME a) =
		(case Controls.get ctl of
		     Off => NONE
		   | Default _ => a)
	end
      end (* LambdaSplitting *)

    val tdp_instrument = TDPInstrument.enabled

    end (* local *)

  end (* structure Control *)
