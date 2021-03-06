(*
 * The revised pickler using the new "generic" pickling facility.
 *
 * March 2000, Matthias Blume
 *)
signature PICKMOD = sig

    (* There are three possible reasons to run the pickler.  Each form
     * of context (see datatype context below) corresponds to one of them:
     *
     *  1. The initial pickle.  This is done right after a new static
     *     environment has been constructed by the elaborator.  The context
     *     is used to identify those identifiers (ModuleId.<xxx>Id) that
     *     correspond to stubs.  Only the domain of the given map is relevant
     *     here, but since we (usually) need the full map right afterwards
     *     for unpickling, there is no gain in using a set.
     *
     *  2. Pickling a previously pickled-and-unpickled environment from
     *     which some parts may have been pruned.  This is used to calculate
     *     a new hash value that is equal to the hash obtained from an initial
     *     pickle (1.) of the environment if it had been pruned earlier.
     *     (This is used by the compilation manager's cutoff recompilation
     *     system.  Pickles obtained here are never unpickled.)
     *     No actual context is necessary because stubification info is
     *     fully embedded in the environment to be pickled.  However, we
     *     must provide the original pid obtained from the first pickling
     *     because occurences of that pid have to be treated the same way
     *     their "not-yet-occurrences" had been treated in step 1.
     *
     *  3. A set of environments that have already gone through an initial
     *     pickling-and-unpickling is pickled as part of a stable library.
     *     The context is a sequence of maps together with information of
     *     how to get hold of the same map later during unpickling.
     *     (The full context of a stable library is a set of other stable
     *     libraries, but during unpickling we want to avoid unpickling
     *     all of these other libraries in full.)  *)
    datatype context =
	INITIAL of ModuleId.tmap
      | REHASH of PersStamps.persstamp
      | LIBRARY of ((int * Symbol.symbol) option * ModuleId.tmap) list

    type map
    val emptyMap : map

    val envPickler : (Access.lvar -> unit) ->
		     context ->
		     { pickler: (map, StaticEnv.staticEnv) PickleUtil.pickler,
		       stampConverter: Stamps.converter }

    val pickleEnv : context ->
		    StaticEnv.staticEnv ->
		    { hash: PersStamps.persstamp,
		      pickle: Word8Vector.vector, 
		      exportLvars: Access.lvar list,
		      hasExports: bool,
		      stampConverter: Stamps.converter }

    val pickleFLINT: FLINT.prog option -> { hash: PersStamps.persstamp,
					    pickle: Word8Vector.vector }

    val symenvPickler : (map, SymbolicEnv.env) PickleUtil.pickler

    val pickle2hash: Word8Vector.vector -> PersStamps.persstamp
	
    val dontPickle : 
	{ env: StaticEnv.staticEnv, count: int } ->
        { newenv: StaticEnv.staticEnv, hash: PersStamps.persstamp,
	  exportLvars: Access.lvar list, hasExports: bool }
end

local
    functor MapFn = RedBlackMapFn
    structure IntMap = IntRedBlackMap
in
  structure PickMod :> PICKMOD = struct

    datatype context =
	INITIAL of ModuleId.tmap
      | REHASH of PersStamps.persstamp
      | LIBRARY of ((int * Symbol.symbol) option * ModuleId.tmap) list

    (* to gather some statistics... *)
    val addPickles = Stats.addStat (Stats.makeStat "Pickle Bytes")

    fun bug msg = ErrorMsg.impossible ("PickMod: " ^ msg)

    structure A = Access
    structure DI = DebIndex
    structure LK = LtyKernel
    structure PT = PrimTyc
    structure F = FLINT
    structure T = Types
    structure SP = SymPath
    structure IP = InvPath
    structure MI = ModuleId
    structure II = InlInfo
    structure V = VarCon
    structure ED = EntPath.EvDict
    structure PS = PersStamps
    structure P = PrimOp
    structure M = Modules
    structure B = Bindings

    (** NOTE: the CRC functions really ought to work on Word8Vector.vectors **)
    fun pickle2hash pickle =
	PS.fromBytes
	  (Byte.stringToBytes
	     (CRC.toString
	        (CRC.fromString
		  (Byte.bytesToString pickle))))

    fun symCmp (a, b) =
	if Symbol.symbolGt (a, b) then GREATER
	else if Symbol.eq (a, b) then EQUAL else LESS

    structure LTMap = MapFn
	(struct type ord_key = LK.lty val compare = LK.lt_cmp end)
    structure TCMap = MapFn
	(struct type ord_key = LK.tyc val compare = LK.tc_cmp end)
    structure TKMap = MapFn
	(struct type ord_key = LK.tkind val compare = LK.tk_cmp end)
    structure DTMap = StampMap
    structure MBMap = StampMap

    structure PU = PickleUtil
    structure PSymPid = PickleSymPid

    type map =
	{ lt: PU.id LTMap.map,
	  tc: PU.id TCMap.map,
	  tk: PU.id TKMap.map,
	  dt: PU.id DTMap.map,
	  mb: PU.id MBMap.map,
	  mi: PU.id MI.umap }

    val emptyMap = { lt = LTMap.empty, tc = TCMap.empty, tk = TKMap.empty,
		     dt = DTMap.empty, mb = MBMap.empty, mi = MI.emptyUmap }

    (* type info *)
    val (NK, AO, CO, PO, CS, A, CR, LT, TC, TK,
	 V, C, E, FK, RK, ST, MI, EQP, TYCKIND, DTI,
	 DTF, TYCON, T, II, VAR, SD, SG, FSG,  SP, EN,
	 STR, F, STE, TCE, STRE, FE, EE, ED, EEV, FX,
	 B, DCON, DICT, FPRIM, FUNDEC, TFUNDEC, DATACON, DTMEM, NRD,
	 OVERLD, FCTC, SEN, FEN, SPATH, IPATH, STRID, FCTID, CCI, CTYPE,
         CCALL_TYPE) =
	(1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
	 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
	 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	 41, 42, 43, 44, 45, 46, 47, 48, 49,
	 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60)

    (* this is a bit awful...
     * (we really ought to have syntax for "functional update") *)
    val LTs = { find = fn (m: map, x) => LTMap.find (#lt m, x),
	        insert = fn ({ lt, tc, tk, dt, mb, mi }, x, v) =>
		         { lt = LTMap.insert (lt, x, v),
			   tc = tc,
			   tk = tk,
			   dt = dt,
			   mb = mb,
			   mi = mi } }
    val TCs = { find = fn (m: map, x) => TCMap.find (#tc m, x),
	        insert = fn ({ lt, tc, tk, dt, mb, mi }, x, v) =>
		         { lt = lt,
			   tc = TCMap.insert (tc, x, v),
			   tk = tk,
			   dt = dt,
			   mb = mb,
			   mi = mi } }
    val TKs = { find = fn (m: map, x) => TKMap.find (#tk m, x),
	        insert = fn ({ lt, tc, tk, dt, mb, mi }, x, v) =>
		         { lt = lt,
			   tc = tc,
			   tk = TKMap.insert (tk, x, v),
			   dt = dt,
			   mb = mb,
			   mi = mi } }
    fun DTs x = { find = fn (m: map, _) => DTMap.find (#dt m, x),
		  insert = fn ({ lt, tc, tk, dt, mb, mi }, _, v) =>
		           { lt = lt,
			     tc = tc,
			     tk = tk,
			     dt = DTMap.insert (dt, x, v),
			     mb = mb,
			     mi = mi } }
    fun MBs x = { find = fn (m: map, _) => MBMap.find (#mb m, x),
		  insert = fn ({ lt, tc, tk, dt, mb, mi }, _, v) =>
		           { lt = lt,
			     tc = tc,
			     tk = tk,
			     dt = dt,
			     mb = MBMap.insert (mb, x, v),
			     mi = mi } }
    fun TYCs id = { find = fn (m: map, _) => MI.uLookTyc (#mi m, id),
		    insert = fn ({ lt, tc, tk, dt, mb, mi }, _, v) =>
				{ lt = lt,
				  tc = tc,
				  tk = tk,
				  dt = dt,
				  mb = mb,
				  mi = MI.uInsertTyc (mi, id, v) } }
    val SIGs = { find = fn (m: map, r) => MI.uLookSig (#mi m, MI.sigId r),
		 insert = fn ({ lt, tc, tk, dt, mb, mi }, r, v) =>
			     { lt = lt,
			       tc = tc,
			       tk = tk,
			       dt = dt,
			       mb = mb,
			       mi = MI.uInsertSig (mi, MI.sigId r, v) } }
    fun STRs i = { find = fn (m: map, _) => MI.uLookStr (#mi m, i),
		   insert = fn ({ lt, tc, tk, dt, mb, mi }, _, v) =>
			       { lt = lt,
				 tc = tc,
				 tk = tk,
				 dt = dt,
				 mb = mb,
				 mi = MI.uInsertStr (mi, i, v) } }
    fun FCTs i = { find = fn (m: map, _) => MI.uLookFct (#mi m, i),
		   insert = fn ({ lt, tc, tk, dt, mb, mi }, _, v) =>
			       { lt = lt,
				 tc = tc,
				 tk = tk,
				 dt = dt,
				 mb = mb,
				 mi = MI.uInsertFct (mi, i, v) } }
    val ENVs = { find = fn (m: map, r) => MI.uLookEnv (#mi m, MI.envId r),
		 insert = fn ({ lt, tc, tk, dt, mb, mi }, r, v) =>
			     { lt = lt,
			       tc = tc,
			       tk = tk,
			       dt = dt,
			       mb = mb,
			       mi = MI.uInsertEnv (mi, MI.envId r, v) } }

    infix 3 $

    val int = PU.w_int
    val int32 = PU.w_int32
    val word = PU.w_word
    val word32 = PU.w_word32
    val string = PU.w_string
    val share = PU.ah_share
    val list = PU.w_list
    val pair = PU.w_pair
    val bool = PU.w_bool
    val option = PU.w_option
    val symbol = PSymPid.w_symbol
    val pid = PSymPid.w_pid

    fun mkAlphaConvert () = let
	val m = ref IntMap.empty
	val cnt = ref 0
	fun cvt i =
	    case IntMap.find (!m, i) of
		SOME i' => i'
	      | NONE => let
		    val i' = !cnt
		in
		    cnt := i' + 1;
		    m := IntMap.insert (!m, i, i');
		    i'
		end
    in
	cvt
    end

    fun numkind arg = let
	val op $ = PU.$ NK
	fun nk (P.INT i) = "A" $ [int i]
	  | nk (P.UINT i) = "B" $ [int i]
	  | nk (P.FLOAT i) = "C" $ [int i]
    in
	nk arg
    end

    fun arithop oper = let
	val op $ = PU.$ AO
	fun arithopc P.+ = "\000"
	  | arithopc P.- = "\001"
	  | arithopc P.* = "\002"
	  | arithopc P./ = "\003"
	  | arithopc P.~ = "\004"
	  | arithopc P.ABS = "\005"
	  | arithopc P.LSHIFT = "\006"
	  | arithopc P.RSHIFT = "\007"
	  | arithopc P.RSHIFTL = "\008"
	  | arithopc P.ANDB = "\009"
	  | arithopc P.ORB = "\010"
	  | arithopc P.XORB = "\011"
	  | arithopc P.NOTB = "\012"
          | arithopc P.FSQRT = "\013"
	  | arithopc P.FSIN = "\014"
	  | arithopc P.FCOS = "\015"
	  | arithopc P.FTAN = "\016"
	  | arithopc P.REM = "\017"
	  | arithopc P.DIV = "\018"
	  | arithopc P.MOD = "\019"
    in
	arithopc oper $ []
    end

    fun cmpop oper = let
	val op $ = PU.$ CO
	fun cmpopc P.> = "\000"
	  | cmpopc P.>= = "\001"
	  | cmpopc P.< = "\002"
	  | cmpopc P.<= = "\003"
	  | cmpopc P.LEU = "\004"
	  | cmpopc P.LTU = "\005"
	  | cmpopc P.GEU = "\006"
	  | cmpopc P.GTU = "\007"
	  | cmpopc P.EQL = "\008"
	  | cmpopc P.NEQ = "\009"
    in
	cmpopc oper $ []
    end

    fun ctype t = let
	val op $ = PU.$ CTYPE
	fun ?n = String.str (Char.chr n)
	fun %?n = ?n $ []
    in
	case t of
	    CTypes.C_void => %?0
	  | CTypes.C_float => %?1
	  | CTypes.C_double => %?2
	  | CTypes.C_long_double => %?3
	  | CTypes.C_unsigned CTypes.I_char => %?4
	  | CTypes.C_unsigned CTypes.I_short => %?5
	  | CTypes.C_unsigned CTypes.I_int => %?6
	  | CTypes.C_unsigned CTypes.I_long => %?7
	  | CTypes.C_unsigned CTypes.I_long_long => %?8
	  | CTypes.C_signed CTypes.I_char => %?9
	  | CTypes.C_signed CTypes.I_short => %?10
	  | CTypes.C_signed CTypes.I_int => %?11
	  | CTypes.C_signed CTypes.I_long => %?12
	  | CTypes.C_signed CTypes.I_long_long => %?13
	  | CTypes.C_PTR => %?14
	  | CTypes.C_ARRAY (t, i) => ?20 $ [ctype t, int i]
	  | CTypes.C_STRUCT l => ?21 $ [list ctype l]
	  | CTypes.C_UNION l => ?22 $ [list ctype l]
    end

    fun ccall_type t =
    let val op $ = PU.$ CCALL_TYPE
    in  case t of
          P.CCI32 => "\000" $ [] 
        | P.CCI64 => "\001" $ []
        | P.CCR64 => "\002" $ []
        | P.CCML  => "\003" $ []
    end

    fun ccall_info { c_proto = { conv, retTy, paramTys },
		     ml_args, ml_res_opt, reentrant } = let
	val op $ = PU.$ CCI 
    in
	"C" $ [string conv, ctype retTy, list ctype paramTys,
	       list ccall_type ml_args, option ccall_type ml_res_opt,
               bool reentrant
              ]
    end
	    
    fun primop p = let
	val op $ = PU.$ PO
	fun ?n = String.str (Char.chr n)
	fun fromto tag (from, to) = ?tag $ [int from, int to]
	fun %?n = ?n $ []
	in
	    case p of
		P.ARITH { oper, overflow, kind } =>
		    ?100 $ [arithop oper, bool overflow, numkind kind]
	      | P.CMP { oper, kind } => ?101 $ [cmpop oper, numkind kind]
	      | P.TEST x => fromto 102 x
	      | P.TESTU x => fromto 103 x
	      | P.TRUNC x => fromto 104 x
	      | P.EXTEND x => fromto 105 x
	      | P.COPY x => fromto 106 x
	      | P.INLLSHIFT kind => ?107 $ [numkind kind]
	      | P.INLRSHIFT kind => ?108 $ [numkind kind]
	      | P.INLRSHIFTL kind => ?109 $ [numkind kind]
	      | P.ROUND { floor, fromkind, tokind } =>
		    ?110 $ [bool floor, numkind fromkind, numkind tokind]
	      | P.REAL { fromkind, tokind } =>
		    ?111 $ [numkind fromkind, numkind tokind]
	      | P.NUMSUBSCRIPT { kind, checked, immutable } =>
		    ?112 $ [numkind kind, bool checked, bool immutable]
	      | P.NUMUPDATE { kind, checked } =>
		    ?113 $ [numkind kind, bool checked]
	      | P.INL_MONOARRAY kind => ?114 $ [numkind kind]
	      | P.INL_MONOVECTOR kind => ?115 $ [numkind kind]
	      | P.RAW_LOAD kind => ?116 $ [numkind kind]
	      | P.RAW_STORE kind => ?117 $ [numkind kind]
	      | P.RAW_CCALL (SOME i) => ?118 $ [ccall_info i]
	      | P.RAW_RECORD { fblock } => ?119 $ [bool fblock]

	      | P.INLMIN kind => ?120 $ [numkind kind]
	      | P.INLMAX kind => ?121 $ [numkind kind]
	      | P.INLABS kind => ?122 $ [numkind kind]
		    
	      | P.TEST_INF i => ?123 $ [int i]
	      | P.TRUNC_INF i => ?124 $ [int i]
	      | P.EXTEND_INF i => ?125 $ [int i]
	      | P.COPY_INF i => ?126 $ [int i]

	      | P.MKETAG => %?0
	      | P.WRAP => %?1
	      | P.UNWRAP => %?2
	      | P.SUBSCRIPT => %?3
	      | P.SUBSCRIPTV => %?4
	      | P.INLSUBSCRIPT => %?5
	      | P.INLSUBSCRIPTV => %?6
	      | P.INLMKARRAY => %?7
		    
	      | P.PTREQL => %?8
	      | P.PTRNEQ => %?9
	      | P.POLYEQL => %?10
	      | P.POLYNEQ => %?11
	      | P.BOXED => %?12
	      | P.UNBOXED => %?13
	      | P.LENGTH => %?14
	      | P.OBJLENGTH => %?15
	      | P.CAST => %?16
	      | P.GETRUNVEC => %?17
	      | P.MARKEXN => %?18
	      | P.GETHDLR => %?19
	      | P.SETHDLR => %?20
	      | P.GETVAR => %?21
	      | P.SETVAR => %?22
	      | P.GETPSEUDO => %?23
	      | P.SETPSEUDO => %?24
	      | P.SETMARK => %?25
	      | P.DISPOSE => %?26
	      | P.MAKEREF => %?27
	      | P.CALLCC => %?28
	      | P.CAPTURE => %?29
	      | P.THROW => %?30
	      | P.DEREF => %?31
	      | P.ASSIGN => %?32
	      (* NOTE: P.UNBOXEDASSIGN is defined below *)
	      | P.UPDATE => %?33
	      | P.INLUPDATE => %?34
	      | P.BOXEDUPDATE => %?35
	      | P.UNBOXEDUPDATE => %?36

	      | P.GETTAG => %?37
	      | P.MKSPECIAL => %?38
	      | P.SETSPECIAL => %?39
	      | P.GETSPECIAL => %?40
	      | P.USELVAR => %?41
	      | P.DEFLVAR => %?42
	      | P.INLNOT => %?43
	      | P.INLCOMPOSE => %?44
	      | P.INLBEFORE => %?45
	      | P.INL_ARRAY => %?46
	      | P.INL_VECTOR => %?47
	      | P.ISOLATE => %?48
	      | P.WCAST => %?49
	      | P.NEW_ARRAY0 => %?50
	      | P.GET_SEQ_DATA => %?51
	      | P.SUBSCRIPT_REC => %?52
	      | P.SUBSCRIPT_RAW64 => %?53
	      | P.UNBOXEDASSIGN => %?54
	      | P.RAW_CCALL NONE => %?55
	      | P.INLIGNORE => %?56
	      | P.INLIDENTITY => %?57
    end

    fun consig arg = let
	val op $ = PU.$ CS
	fun cs (A.CSIG (i, j)) = "S" $ [int i, int j]
	  | cs A.CNIL = "N" $ []
    in
	cs arg
    end

    fun mkAccess { lvar, isLocalPid } = let
	val op $ = PU.$ A
	fun access (A.LVAR i) = "A" $ [lvar i]
	  | access (A.EXTERN p) = "B" $ [pid p]
	  | access (A.PATH (a as A.EXTERN p, i)) =
	    (* isLocalPid always returns false for in the "normal pickler"
	     * case.  It returns true in the "repickle" case for the
	     * pid that was the hash of the original whole pickle.
	     * Since alpha-conversion has already taken place if we find
	     * an EXTERN pid, we don't call "lvar" but "int". *)
	    if isLocalPid p then "A" $ [int i]
	    else "C" $ [access a, int i]
	  | access (A.PATH (a, i)) = "C" $ [access a, int i]
	  | access A.NO_ACCESS = "D" $ []

	val op $ = PU.$ CR
	fun conrep A.UNTAGGED = "A" $ []
	  | conrep (A.TAGGED i) = "B" $ [int i]
	  | conrep A.TRANSPARENT = "C" $ []
	  | conrep (A.CONSTANT i) = "D" $ [int i]
	  | conrep A.REF = "E" $ []
	  | conrep (A.EXN a) = "F" $ [access a]
	  | conrep A.LISTCONS = "G" $ []
	  | conrep A.LISTNIL = "H" $ []
	  | conrep (A.SUSP NONE) = "I" $ []
	  | conrep (A.SUSP (SOME (a, b))) = "J" $ [access a, access b]
    in
	{ access = access, conrep = conrep }
    end

    (* lambda-type stuff; some of it is used in both picklers *)
    fun tkind x = let
	val op $ = PU.$ TK
	fun tk x =
	    case LK.tk_out x of
	    LK.TK_MONO => "A" $ []
	  | LK.TK_BOX => "B" $ []
	  | LK.TK_SEQ ks => "C" $ [list tkind ks]
	  | LK.TK_FUN (ks, kr) => "D" $ [list tkind ks, tkind kr]
    in
	share TKs tk x
    end

    fun mkLty lvar = let
	fun lty x = let
	    val op $ = PU.$ LT
	    fun ltyI x =
		case LK.lt_out x of
		    LK.LT_TYC tc => "A" $ [tyc tc]
		  | LK.LT_STR l => "B" $ [list lty l]
		  | LK.LT_FCT (ts1, ts2) => "C" $ [list lty ts1, list lty ts2]
		  | LK.LT_POLY (ks, ts) => "D" $ [list tkind ks, list lty ts]
		  | LK.LT_IND _ => bug "unexpected LT_IND in mkPickleLty"
		  | LK.LT_ENV _ => bug "unexpected LT_ENV in mkPickleLty"
		  | LK.LT_CONT _ => bug "unexpected LT_CONT in mkPickleLty"
	in
	    share LTs ltyI x
	end

	and tyc x = let
	    val op $ = PU.$ TC
	    fun tycI x =
		case LK.tc_out x of
		    LK.TC_VAR (db, i) => "A" $ [int (DI.di_toint db), int i]
		  | LK.TC_NVAR n => "B" $ [lvar n]
		  | LK.TC_PRIM t => "C" $ [int (PT.pt_toint t)]
		  | LK.TC_FN (ks, tc) => "D" $ [list tkind ks, tyc tc]
		  | LK.TC_APP (tc, l) => "E" $ [tyc tc, list tyc l]
		  | LK.TC_SEQ l => "F" $ [list tyc l]
		  | LK.TC_PROJ (tc, i) => "G" $ [tyc tc, int i]
		  | LK.TC_SUM l => "H" $ [list tyc l]
		  | LK.TC_FIX ((n, tc, ts), i) =>
			"I" $ [int n, tyc tc, list tyc ts, int i]
		  | LK.TC_ABS tc => "J" $ [tyc tc]
		  | LK.TC_BOX tc => "K" $ [tyc tc]
		  | LK.TC_TUPLE (_, l) => "L" $ [list tyc l]
		  | LK.TC_ARROW (LK.FF_VAR (b1, b2), ts1, ts2) =>
			"M" $ [bool b1, bool b2, list tyc ts1, list tyc ts2]
		  | LK.TC_ARROW (LK.FF_FIXED, ts1, ts2) =>
			"N" $ [list tyc ts1, list tyc ts2]
		  | LK.TC_PARROW _ => bug "unexpected TC_PARREW in mkPickleLty"
		  | LK.TC_TOKEN (tk, t) => "O" $ [int (LK.token_int tk), tyc t]
		  | LK.TC_IND _ => bug "unexpected TC_IND in mkPickleLty"
		  | LK.TC_ENV _ => bug "unexpected TC_ENV in mkPickleLty"
		  | LK.TC_CONT _ => bug "unexpected TC_CONT in mkPickleLty"
	in
	    share TCs tycI x
	end
    in
	{ tyc = tyc, lty = lty }
    end

    (* the FLINT pickler *)
    fun flint flint_exp = let
	val alphaConvert = mkAlphaConvert ()
	val lvar = int o alphaConvert
	val { access, conrep } = mkAccess { lvar = lvar,
					    isLocalPid = fn _ => false }
	val { lty, tyc } = mkLty lvar

	val op $ = PU.$ V
	fun value (F.VAR v) = "a" $ [lvar v]
	  | value (F.INT i) = "b" $ [int i]
	  | value (F.INT32 i32) = "c" $ [int32 i32]
	  | value (F.WORD w) = "d" $ [word w]
	  | value (F.WORD32 w32) = "e" $ [word32 w32]
	  | value (F.REAL s) = "f" $ [string s]
	  | value (F.STRING s) = "g" $ [string s]

	fun con arg = let
	    val op $ = PU.$ C
	    fun c (F.DATAcon (dc, ts, v), e) =
		"1" $ [dcon (dc, ts), lvar v, lexp e]
	      | c (F.INTcon i, e) = "2" $ [int i, lexp e]
	      | c (F.INT32con i32, e) = "3" $ [int32 i32, lexp e]
	      | c (F.WORDcon w, e) = "4" $ [word w, lexp e]
	      | c (F.WORD32con w32, e) = "5" $ [word32 w32, lexp e]
	      | c (F.REALcon s, e) = "6" $ [string s, lexp e]
	      | c (F.STRINGcon s, e) = "7" $ [string s, lexp e]
	      | c (F.VLENcon i, e) = "8" $ [int i, lexp e]
	in
	    c arg
	end

	and dcon ((s, cr, t), ts) = let
	    val op $ = PU.$ DCON
	in
	    "x" $ [symbol s, conrep cr, lty t, list tyc ts]
	end

	and dict { default = v, table = tbls } = let
	    val op $ = PU.$ DICT
	in
	    "y" $ [lvar v, list (pair (list tyc, lvar)) tbls]
	end

	and fprim (dtopt, p, t, ts) = let
	    val op $ = PU.$ FPRIM
	in
	    "z" $ [option dict dtopt, primop p, lty t, list tyc ts]
	end

	and lexp arg = let
	    val op $ = PU.$ E
	    fun l (F.RET vs) = "j" $ [list value vs]
	      | l (F.LET (vs, e1, e2)) =
		"k" $ [list lvar vs, lexp e1, lexp e2]
	      | l (F.FIX (fdecs, e)) = "l" $ [list fundec fdecs, lexp e]
	      | l (F.APP (v, vs)) = "m" $ [value v, list value vs]
	      | l (F.TFN (tfdec, e)) = "n" $ [tfundec tfdec, lexp e]
	      | l (F.TAPP (v, ts)) = "o" $ [value v, list tyc ts]
	      | l (F.SWITCH (v, crl, cel, eo)) =
		"p" $ [value v, consig crl, list con cel, option lexp eo]
	      | l (F.CON (dc, ts, u, v, e)) =
		"q" $ [dcon (dc, ts), value u, lvar v, lexp e]
	      | l (F.RECORD (rk, vl, v, e)) =
		"r" $ [rkind rk, list value vl, lvar v, lexp e]
	      | l (F.SELECT (u, i, v, e)) =
		"s" $ [value u, int i, lvar v, lexp e]
	      | l (F.RAISE (u, ts)) = "t" $ [value u, list lty ts]
	      | l (F.HANDLE (e, u)) = "u" $ [lexp e, value u]
	      | l (F.BRANCH (p, vs, e1, e2)) =
		"v" $ [fprim p, list value vs, lexp e1, lexp e2]
	      | l (F.PRIMOP (p, vs, v, e)) =
		"w" $ [fprim p, list value vs, lvar v, lexp e]
	      | l (F.SUPERCAST (x, v, t, e)) =
		"x" $ [value x, lvar v, lty t, lexp e]
	in
	    l arg
	end

	and fundec (fk, v, vts, e) = let
	    val op $ = PU.$ FUNDEC
	in
	    "a" $ [fkind fk, lvar v, list (pair (lvar, lty)) vts, lexp e]
	end

	and tfundec (_, v, tvks, e) = let
	    val op $ = PU.$ TFUNDEC
	in
	    "b" $ [lvar v, list (pair (lvar, tkind)) tvks, lexp e]
	end

	and fkind arg = let
	    val op $ = PU.$ FK
	    fun isAlways F.IH_ALWAYS = true
	      | isAlways _ = false
	    fun strip (x, y) = x
	    fun fk { cconv = F.CC_FCT, ... } = "2" $ []
	      | fk { isrec, cconv = F.CC_FUN fixed, known, inline } =
		case fixed of
		    LK.FF_VAR (b1, b2) =>
			"3" $ [option (list lty) (Option.map strip isrec),
			       bool b1, bool b2, bool known,
			       bool (isAlways inline)]
		  | LK.FF_FIXED =>
			"4" $ [option (list lty) (Option.map strip isrec),
			       bool known, bool (isAlways inline)]
	in
	    fk arg
	end

	and rkind arg = let
	    val op $ = PU.$ RK
	    fun rk (F.RK_VECTOR tc) = "5" $ [tyc tc]
	      | rk F.RK_STRUCT = "6" $ []
	      | rk (F.RK_TUPLE _) = "7" $ []
	in
	    rk arg
	end
    in
	fundec flint_exp
    end

    fun pickleFLINT fo = let
	val pickle =
	    Byte.stringToBytes (PU.pickle emptyMap (option flint fo))
	val hash = pickle2hash pickle
    in
	{ pickle = pickle, hash = hash }
    end

    fun symenvPickler sye =
	list (pair (pid, flint)) (SymbolicEnv.listItemsi sye)

    (* the environment pickler *)
    fun envPickler registerLvar context = let
	val { tycStub, sigStub, strStub, fctStub, envStub,
	      isLocalPid, isLib } =
	    case context of
		INITIAL tmap => let
		    fun stub (xId, freshX, lookX) r = let
			val id = xId r
		    in
			if freshX id then NONE
			else if isSome (lookX (tmap, id)) then SOME (NONE, id)
			else NONE
		    end
		in
		    { tycStub = stub (MI.tycId, MI.freshTyc, MI.lookTyc),
		      sigStub = stub (MI.sigId, MI.freshSig, MI.lookSig),
		      strStub = stub (MI.strId, MI.freshStr, MI.lookStr),
		      fctStub = stub (MI.fctId, MI.freshFct, MI.lookFct),
		      envStub = stub (MI.envId, MI.freshEnv, MI.lookEnv),
		      isLocalPid = fn _ => false,
		      isLib = false }
		end
	      | REHASH myPid => let
		    fun isLocalPid p = PersStamps.compare (p, myPid) = EQUAL
		    fun stub (idX, stubX, owner) r =
			case stubX r of
			    NONE => bug "REHASH:no stubinfo"
			  | SOME stb =>
			    if isLocalPid (owner stb) then SOME (NONE, idX r)
			    else NONE
		in
		    { tycStub = stub (MI.tycId, #stub, #owner),
		      sigStub = stub (MI.sigId, #stub, #owner),
		      strStub = stub (MI.strId, #stub o #rlzn, #owner),
		      fctStub = stub (MI.fctId, #stub o #rlzn, #owner),
		      envStub = stub (MI.envId, #stub, #owner),
		      isLocalPid = isLocalPid,
		      isLib = false }
		end
	      | LIBRARY l => let
		    fun stub (idX, stubX, lookX, lib) r = let
			fun get id = let
			    fun loop [] =
				bug "LIBRARY:import info missing"
			      | loop ((lms, m) :: t) =
				if isSome (lookX (m, id)) then lms else loop t
			in
			    loop l
			end
		    in
			case stubX r of
			    NONE => bug "LIBRARY:no stubinfo"
			  | SOME stb => let
				val id = idX r
			    in
				if lib stb then SOME (get id, id) else NONE
			    end
		    end
		in
		    { tycStub = stub (MI.tycId, #stub, MI.lookTyc, #lib),
		      sigStub = stub (MI.sigId, #stub, MI.lookSig, #lib),
		      strStub = stub (MI.strId, #stub o #rlzn,
				      MI.lookStr, #lib),
		      fctStub = stub (MI.fctId, #stub o #rlzn,
				      MI.lookFct, #lib),
		      envStub = stub (MI.envId, #stub, MI.lookEnv, #lib),
		      isLocalPid = fn _ => false,
		      isLib = true }
		end

	(* Owner pids of stubs are pickled only in the case of libraries,
	 * otherwise they are ignored completely. *)
	fun libPid x =
	    if isLib then
		case x of
		    (NONE, _) => []
		  | (SOME stb, ownerOf) => [pid (ownerOf stb)]
	    else []

	fun libModSpec lms = option (pair (int, symbol)) lms

	val stampConverter = Stamps.newConverter ()

	fun stamp s = let
	    val op $ = PU.$ ST
	in
	    Stamps.Case	stampConverter s
		{ fresh = fn i => "A" $ [int i],
		  global = fn { pid = p, cnt } => "B" $ [pid p, int cnt],
		  special = fn s => "C" $ [string s] }
	end

	val tycId = stamp
	val sigId = stamp
	fun strId { sign, rlzn } = let
	    val op $ = PU.$ STRID
	in
	    "D" $ [stamp sign, stamp rlzn]
	end
	fun fctId { paramsig, bodysig, rlzn } = let
	    val op $ = PU.$ FCTID
	in
	    "E" $ [stamp paramsig, stamp bodysig, stamp rlzn]
	end
	val envId = stamp

	val entVar = stamp
	val entPath = list entVar

	val anotherLvar =
	    let val lvcount = ref 0
	    in (fn v => let val j = !lvcount
			in registerLvar v; lvcount := j + 1; j end)
	    end

	val { access, conrep } = mkAccess { lvar = int o anotherLvar,
					    isLocalPid = isLocalPid }

	val op $ = PU.$ SPATH
	fun spath (SP.SPATH p) = "s" $ [list symbol p]
	val op $ = PU.$ IPATH
	fun ipath (IP.IPATH p) = "i" $ [list symbol p]

	  (* for debugging *)
	fun showipath (IP.IPATH p) =
	    concat (map (fn s => Symbol.symbolToString s ^ ".") (rev p))

	val label = symbol

	fun eqprop eqp = let
	    val op $ = PU.$ EQP
	    fun eqc T.YES = "\000"
	      | eqc T.NO = "\001"
	      | eqc T.IND = "\002"
	      | eqc T.OBJ = "\003"
	      | eqc T.DATA = "\004"
	      | eqc T.ABS = "\005"
	      | eqc T.UNDEF = "\006"
	in
	    eqc eqp $ []
	end

	fun datacon (T.DATACON { name, const, typ, rep, sign, lazyp }) = let
	    val op $ = PU.$ DATACON
	in
	    "c" $ [symbol name, bool const, ty typ, conrep rep,
		   consig sign, bool lazyp]
	end

	and tyckind arg = let
	    val op $ = PU.$ TYCKIND
	    fun tk (T.PRIMITIVE pt) = "a" $ [int pt]
	      | tk (T.DATATYPE { index, family, stamps, root,freetycs }) =
		"b" $ [int index, option entVar root,
		       dtypeInfo (stamps, family, freetycs)]
	      | tk (T.ABSTRACT tyc) = "c" $ [tycon tyc]
	      | tk (T.FLEXTYC tps) = "d" $ [] (* "f" $ tycpath tps *)
	      (*** I (Matthias) carried through this message from Zhong:
	       tycpath should never be pickled; the only way it can be
	       pickled is when pickling the domains of a mutually 
	       recursive datatypes; right now the mutually recursive
	       datatypes are not assigned accurate domains ... (ZHONG)
	       the preceding code is just a temporary gross hack. 
	       ***)
	      | tk T.FORMAL = "d" $ []
	      | tk T.TEMP = "e" $ []
	in
	    tk arg
	end

	and dtypeInfo x = let
	    val op $ = PU.$ DTI
	    fun dti_raw (ss, family, freetycs) =
		"a" $ [list stamp (Vector.foldr (op ::) [] ss),
		       dtFamily family, list tycon freetycs]
	in
	    share (DTs (Vector.sub (#1 x, 0))) dti_raw x
	end

	and dtFamily x = let
	    val op $ = PU.$ DTF
	    fun dtf_raw { mkey, members, properties } =
		"b" $ [stamp mkey,
		       list dtmember (Vector.foldr (op ::) [] members)]
	in
	    share (MBs (#mkey x)) dtf_raw x
	end

	and dtmember { tycname, dcons, arity, eq = ref e, lazyp, sign } = let
	    val op $ = PU.$ DTMEM
	in
	    "c" $ [symbol tycname, list nameRepDomain dcons, int arity,
		   eqprop e, bool lazyp, consig sign]
	end

	and nameRepDomain { name, rep, domain } = let
	    val op $ = PU.$ NRD
	in
	    "d" $ [symbol name, conrep rep, option ty domain]
	end

	and tycon arg = let
	    val op $ = PU.$ TYCON
	    fun tc (tyc as T.GENtyc g) =
		let fun gt_raw (g as { stamp = s, arity, eq = ref eq, kind,
				       path, stub }) =
			case tycStub g of
			    SOME (l, i) => "A" $ [libModSpec l, tycId i]
			  | NONE => "B" $ ([stamp s, int arity, eqprop eq,
					    tyckind kind, ipath path]
					   @ libPid (stub, #owner))
		in
		    share (TYCs (MI.tycId g)) gt_raw g
		end
	      | tc (tyc as T.DEFtyc dt) = let
		    fun dt_raw { stamp = s, tyfun, strict, path } = let
			val T.TYFUN { arity, body } = tyfun
		    in
			"C" $ [stamp s, int arity, ty body,
			       list bool strict, ipath path]
		    end
		in
		    share (TYCs (MI.tycId' tyc)) dt_raw dt
		end
	      | tc (T.PATHtyc { arity, entPath = ep, path }) =
		"D" $ [int arity, entPath ep, ipath path]
	      | tc (T.RECORDtyc l) = "E" $ [list label l]
	      | tc (T.RECtyc i) = "F" $ [int i]
	      | tc (T.FREEtyc i) = "G" $ [int i]
	      | tc T.ERRORtyc = "H" $ []
	in
	    tc arg
	end

	and ty arg = let
	    val op $ = PU.$ T
	    fun ty (T.VARty (ref (T.INSTANTIATED t))) = ty t
	      | ty (T.VARty (ref (T.OPEN _))) =
		bug "uninstantiated VARty in pickmod"
	      | ty (T.CONty (c, l)) = "a" $ [tycon c, list ty l]
	      | ty (T.IBOUND i) = "b" $ [int i]
	      | ty T.WILDCARDty = "c" $ []
	      | ty (T.POLYty { sign, tyfun = T.TYFUN { arity, body } }) =
		"d" $ [list bool sign, int arity, ty body]
	      | ty T.UNDEFty = "e" $ []
	      | ty _ = bug "unexpected type in pickmod-ty"
	in
	    ty arg
	end

	val op $ = PU.$ II
	fun inl_info i =
	    II.match i { inl_prim = fn (p, t) => "A" $ [primop p, ty t],
			 inl_str = fn sl => "B" $ [list inl_info sl],
			 inl_no = fn () => "C" $ [],
			 inl_pgn = fn () => "D" $ [] }

	val op $ = PU.$ VAR
	fun var (V.VALvar { access = a, info, path, typ = ref t }) =
	    "1" $ [access a, inl_info info, spath path, ty t]
	  | var (V.OVLDvar { name, options = ref p,
			     scheme = T.TYFUN { arity, body } }) =
	    "2" $ [symbol name, list overld p, int arity, ty body]
	  | var V.ERRORvar = "3" $ []

	and overld { indicator, variant } = let
	    val op $ = PU.$ OVERLD
	in
	    "o" $ [ty indicator, var variant]
	end

	fun strDef arg = let
	    val op $ = PU.$ SD
	    fun sd (M.CONSTstrDef s) = "C" $ [Structure s]
	      | sd (M.VARstrDef (s, p)) = "V" $ [Signature s, entPath p]
	in
	    sd arg
	end

	(* 
	 * boundeps is not pickled right now, but it really should
	 * be pickled in the future.
	 *)
	and Signature arg = let
	    val op $ = PU.$ SG
	    fun sg  M.ERRORsig = "A" $ []
	      | sg (M.SIG s) =
		(case sigStub s of
		     SOME (l, i) => "B" $ [libModSpec l, sigId i]
		   | NONE => let
			 fun sig_raw (s: M.sigrec) = let
			     val { stamp = sta, name, closed,
				   fctflag, symbols, elements,
				   properties,
				   (* boundeps = ref b, *)
				   (* lambdaty = _, *)
				   stub, typsharing, strsharing } = s
			     val b = ModulePropLists.sigBoundeps s
			     val b = NONE (* currently turned off *)
			 in
			     "C" $ ([stamp sta,
				     option symbol name, bool closed,
				     bool fctflag,
				     list symbol symbols,
				     list (pair (symbol, spec)) elements,
				     option (list (pair (entPath, tkind))) b,
				     list (list spath) typsharing,
				     list (list spath) strsharing]
				    @ libPid (stub, #owner))
			 end
		     in
			 share SIGs sig_raw s
		     end)
	in
	    sg arg
	end

	and fctSig arg = let
	    val op $ = PU.$ FSG
	    fun fsg M.ERRORfsig = "a" $ []
	      | fsg (M.FSIG { kind, paramsig, paramvar, paramsym, bodysig }) =
		"c" $ [option symbol kind, Signature paramsig,
		       entVar paramvar,
		       option symbol paramsym,
		       Signature bodysig]
	in
	    fsg arg
	end

	and spec arg = let
	    val op $ = PU.$ SP
	    fun sp (M.TYCspec { spec = t, entVar = v, repl, scope }) =
		"1" $ [tycon t, entVar v, bool repl, int scope]
	      | sp (M.STRspec { sign, slot, def, entVar = v }) =
		"2" $ [Signature sign, int slot,
		       option (pair (strDef, int)) def, entVar v]
	      | sp (M.FCTspec { sign, slot, entVar = v }) =
		"3" $ [fctSig sign, int slot, entVar v]
	      | sp (M.VALspec { spec = t, slot }) = "4" $ [ty t, int slot]
	      | sp (M.CONspec { spec = c, slot }) =
		"5" $ [datacon c, option int slot]
	in
	    sp arg
	end

	and entity arg = let
	    val op $ = PU.$ EN
	    fun en (M.TYCent t) = "A" $ [tycEntity t]
	      | en (M.STRent t) = "B" $ [strEntity t]
	      | en (M.FCTent t) = "C" $ [fctEntity t]
	      | en M.ERRORent = "D" $ []
	in
	    en arg
	end

	and fctClosure (M.CLOSURE { param, body, env }) = let
	    val op $ = PU.$ FCTC
	in
	    "f" $ [entVar param, strExp body, entityEnv env]
	end

	and Structure arg = let
	    val op $ = PU.$ STR
	    fun str (M.STRSIG { sign, entPath = p }) =
		"A" $ [Signature sign, entPath p]
	      | str M.ERRORstr = "B" $ []
	      | str (M.STR (s as { sign, rlzn, access = a, info })) =
		(case strStub s of
		     (* stub represents just the strerec suspension! *)
		     SOME (l, i) => "C" $ [Signature sign,
					   libModSpec l,
					   strId i,
					   access a,
					   inl_info info]
		   | NONE => "D" $ [Signature sign,
				    shStrEntity (MI.strId s) rlzn,
				    access a, inl_info info])
	in
	    str arg
	end

	and Functor arg = let
	    val op $ = PU.$ F
	    fun fct M.ERRORfct = "E" $ []
	      | fct (M.FCT (f as { sign, rlzn, access = a, info })) =
		(case fctStub f of
		     SOME (l, i) => "F" $ [fctSig sign,
					   libModSpec l,
					   fctId i,
					   access a,
					   inl_info info]
		   | NONE => "G" $ [fctSig sign,
				    shFctEntity (MI.fctId f) rlzn,
				    access a, inl_info info])
	in
	    fct arg
	end

	and (* stampExp (M.CONST s) = PU.$ STE ("a", [stamp s])
	  | *) stampExp (M.GETSTAMP s) = PU.$ STE ("b", [strExp s])
	  | stampExp M.NEW = "c" $ []

        and tycExp (M.CONSTtyc t) = PU.$ TCE ("d", [tycon t])
	  | tycExp (M.FORMtyc t) = PU.$ TCE ("e", [tycon t])
	  | tycExp (M.VARtyc s) = PU.$ TCE ("f", [entPath s])

        and strExp arg = let
	    val op $ = PU.$ STRE
	    fun stre (M.VARstr s) = "g" $ [entPath s]
	      | stre (M.CONSTstr s) = "h" $ [strEntity s]
	      | stre (M.STRUCTURE { stamp = s, entDec }) =
		"i" $ [stampExp s, entityDec entDec]
	      | stre (M.APPLY (f, s)) = "j" $ [fctExp f, strExp s]
	      | stre (M.LETstr (e, s)) = "k" $ [entityDec e, strExp s]
	      | stre (M.ABSstr (s, e)) = "l" $ [Signature s, strExp e]
	      | stre (M.CONSTRAINstr { boundvar, raw, coercion }) =
		"m" $ [entVar boundvar, strExp raw, strExp coercion]
	      | stre (M.FORMstr fs) = "n" $ [fctSig fs]
	in
	    stre arg
	end

        and fctExp arg = let
	    val op $ = PU.$ FE
	    fun fe (M.VARfct s) = "o" $ [entPath s]
	      | fe (M.CONSTfct e) = "p" $ [fctEntity e]
	      | fe (M.LAMBDA { param, body }) =
		"q" $ [entVar param, strExp body]
	      | fe (M.LAMBDA_TP { param, body, sign }) =
		"r" $ [entVar param, strExp body, fctSig sign]
	      | fe (M.LETfct (e, f)) = "s" $ [entityDec e, fctExp f]
	in
	    fe arg
	end

        and entityExp arg = let
	    val op $ = PU.$ EE
	    fun ee (M.TYCexp t) = "t" $ [tycExp t]
	      | ee (M.STRexp s) = "u" $ [strExp s]
	      | ee (M.FCTexp f) = "v" $ [fctExp f]
	      | ee M.ERRORexp = "w" $ []
	      | ee M.DUMMYexp = "x" $ []
	in
	    ee arg
	end

        and entityDec arg = let
	    val op $ = PU.$ ED
	    fun ed (M.TYCdec (s, x)) = "A" $ [entVar s, tycExp x]
	      | ed (M.STRdec (s, x, n)) = "B" $ [entVar s, strExp x, symbol n]
	      | ed (M.FCTdec (s, x)) = "C" $ [entVar s, fctExp x]
	      | ed (M.SEQdec e) = "D" $ [list entityDec e]
	      | ed (M.LOCALdec (a, b)) = "E" $ [entityDec a, entityDec b]
	      | ed M.ERRORdec = "F" $ []
	      | ed M.EMPTYdec = "G" $ []
	in
	    ed arg
	end

        and entityEnv (M.MARKeenv m) =
	    (case envStub m of
		 SOME (l, i) => "D" $ [libModSpec l, envId i]
	       | NONE => let
		     fun mee_raw { stamp = s, env, stub } =
			 "E" $ ([stamp s, entityEnv env]
				@ libPid (stub: M.stubinfo option, #owner))
		 in
		     share ENVs mee_raw m
		 end)
	  | entityEnv (M.BINDeenv (d, r)) =
	    PU.$ EEV ("A", [list (pair (entVar, entity)) (ED.listItemsi d),
		           entityEnv r])
	  | entityEnv M.NILeenv = "B" $ []
	  | entityEnv M.ERReenv = "C" $ []

        and strEntity { stamp = s, entities, properties, rpath, stub } =
	    let val op $ = PU.$ SEN
	    in
		"s" $ ([stamp s, entityEnv entities, ipath rpath]
		       @ libPid (stub: M.stubinfo option, #owner))
	    end

	and shStrEntity id = share (STRs id) strEntity

        and fctEntity { stamp = s,
			closure, properties, tycpath, rpath, stub } =
	    let val op $ = PU.$ FEN
	    in
		"f" $ ([stamp s, fctClosure closure, ipath rpath]
		       @ libPid (stub: M.stubinfo option, #owner))
	    end

	and shFctEntity id = share (FCTs id) fctEntity

        and tycEntity x = tycon x

        fun fixity Fixity.NONfix = "N" $ []
	  | fixity (Fixity.INfix (i, j)) = PU.$ FX ("I", [int i, int j])

	val op $ = PU.$ B
	fun binding (B.VALbind x) = "1" $ [var x]
	  | binding (B.CONbind x) = "2" $ [datacon x]
	  | binding (B.TYCbind x) = "3" $ [tycon x]
	  | binding (B.SIGbind x) = "4" $ [Signature x]
	  | binding (B.STRbind x) = "5" $ [Structure x]
	  | binding (B.FSGbind x) = "6" $ [fctSig x]
	  | binding (B.FCTbind x) = "7" $ [Functor x]
	  | binding (B.FIXbind x) = "8" $ [fixity x]

	fun env e = let
	    val syms = ListMergeSort.uniqueSort symCmp (StaticEnv.symbols e)
	    val pairs = map (fn s => (s, StaticEnv.look (e, s))) syms
	in
	    list (pair (symbol, binding)) pairs
	end
    in
	{ pickler = env, stampConverter = stampConverter }
    end

    fun pickleEnv context e = let
	val lvlist = ref []
	fun registerLvar v = lvlist := v :: !lvlist
	val { pickler, stampConverter } = envPickler registerLvar context
	val pickle = Byte.stringToBytes (PU.pickle emptyMap (pickler e))
	val exportLvars = rev (!lvlist)
	val hash = pickle2hash pickle
	val hasExports = not (List.null exportLvars)
    in
	addPickles (Word8Vector.length pickle);
	{ hash = hash, pickle = pickle, exportLvars = exportLvars,
	  hasExports = hasExports,
	  stampConverter = stampConverter }
    end

    (* the dummy environment pickler *)
    fun dontPickle { env = senv, count } = let
	val hash = let
	    val toByte = Word8.fromLargeWord o Word32.toLargeWord
	    val >> = Word32.>>
	    infix >>
	    val w = Word32.fromInt count
	in
	    PS.fromBytes
	      (Word8Vector.fromList
	       [0w0,0w0,0w0,toByte(w >> 0w24),0w0,0w0,0w0,toByte(w >> 0w16),
		0w0,0w0,0w0,toByte(w >> 0w8),0w0,0w0,0w0,toByte(w)])
	end
        (* next line is an alternative to using Env.consolidate *)
	val syms = ListMergeSort.uniqueSort symCmp (StaticEnv.symbols senv)
	fun newAccess i = A.PATH (A.EXTERN hash, i)
	fun mapbinding (sym, (i, env, lvars)) =
	    case StaticEnv.look (senv, sym) of
		B.VALbind (V.VALvar {access=a, info=z, path=p, typ= ref t }) =>
		(case a of
		     A.LVAR k =>
		     (i+1,
		      StaticEnv.bind (sym,
				      B.VALbind (V.VALvar
						     { access = newAccess i,
						       info = z, path = p,
						       typ = ref t}),
				      env),
		      k :: lvars)
		   | _ => bug ("dontPickle 1: " ^ A.prAcc a))
	      | B.STRbind (M.STR { sign = s, rlzn = r, access = a, info =z }) =>
		(case a of
		     A.LVAR k => 
		     (i+1,
		      StaticEnv.bind (sym,
				      B.STRbind (M.STR
						     { access = newAccess i,
						       sign = s, rlzn = r,
						       info = z }),
				env),
		      k :: lvars)
		   | _ => bug ("dontPickle 2" ^ A.prAcc a))
	      | B.FCTbind (M.FCT { sign = s, rlzn = r, access = a, info=z }) =>
		(case a of
		     A.LVAR k => 
		     (i+1,
		      StaticEnv.bind (sym,
				      B.FCTbind (M.FCT
						     { access = newAccess i,
						       sign = s, rlzn = r,
						       info = z }),
				      env),
		      k :: lvars)
		   | _ => bug ("dontPickle 3" ^ A.prAcc a))
	      | B.CONbind (T.DATACON { name = n, const = c, typ = t, sign = s,
				       lazyp= false, rep as (A.EXN a) }) => let
		    val newrep = A.EXN (newAccess i)
		in
		    case a of
			A.LVAR k =>
			(i+1,
			 StaticEnv.bind (sym,
					 B.CONbind (T.DATACON
							{ rep = newrep,
							  name = n,
							  lazyp = false,
							  const = c, typ = t,
							  sign = s }),
				   env),
			 k :: lvars)
		      | _ => bug ("dontPickle 4" ^ A.prAcc a)
		end
	      | binding => (i, StaticEnv.bind (sym, binding, env), lvars)
	val (_,newenv,lvars) = foldl mapbinding (0, StaticEnv.empty, nil) syms
	val hasExports = not (List.null lvars)
    in
	{ newenv = newenv, hash = hash,
	  exportLvars = rev lvars, hasExports = hasExports }
    end
  end
end
