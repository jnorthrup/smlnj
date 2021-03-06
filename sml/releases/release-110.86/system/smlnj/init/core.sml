(* core.sml
 *
 * COPYRIGHT (c) 2018 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *
 * Core assumes that the following bindings are already in the static
 * environment:
 *
 *   1. Built-in structures, defined in PrimTypes (env/prim.sml):
 *        PrimTypes InLine
 *
 *   2. Built-in type constructors, defined in PrimTypes (env/prim.sml):
 *        int string bool unit real list array ref exn
 *
 *   3. Built-in data constructors, also from PrimTypes (env/prim.sml):
 *        :: nil ref true false
 *
 *   4. Built-in primitive operators, defined in InLine (env/prim.sml).
 *      The InLine structure is not typed (all values have type alpha, this
 *      will change in the future though !).
 *
 *   5. The Assembly structure: its static semantics is defined by elaborating
 *      the boot/dummy.sml file, and its dynamic semantics is directly coming
 *      the implementation module provided by the runtime system.
 *
 * In addition, all matches in this file should be exhaustive; the match and
 * bind exceptions are not defined at this stage of bootup, so any uncaught
 * match will cause an unpredictable error.
 *
 *)

structure Core =
  struct
  (*
   * We build an Assembly structure from the implementation module provided
   * from the runtime systems. The coercions are implemented via InLine.cast,
   * a primitive operator hardwired inside the compiler. In the future, the
   * linkage should be done safely without using cast (ZHONG).
   *
   * Note: in the future, the Assembly.A substructure will be replaced by
   * a dynamic run vector (JHR).
   *)
    structure Assembly : ASSEMBLY =
      struct
	open Assembly

	val cast : 'a -> 'b = InLine.cast
        datatype ('a, 'b) pair = PAIR of 'a * 'b

        structure A =
          struct
	    structure AA = Assembly.A

	    type c_function = AA.c_function
	    type word8array = AA.word8array
	    type real64array = AA.word8array
	    type spin_lock = AA.spin_lock

            val arrayP : (int, 'a) pair -> 'a array = cast AA.array
	    val array : int * 'a -> 'a array = fn x => arrayP(PAIR x)

            val bind_cfunP : (string, string) pair -> c_function =
                     cast AA.bind_cfun
	    val bind_cfun : (string * string) -> c_function =
                     fn x => bind_cfunP (PAIR x)

            val callcP : (c_function, 'a) pair -> 'c = cast AA.callc
	    val callc : (c_function * 'a) -> 'c = fn x => callcP (PAIR x)

	    val create_b : int -> word8array = cast AA.create_b
	    val create_r : int -> real64array = cast AA.create_r
	    val create_s : int -> string = cast AA.create_s
            val create_vP : (int, 'a list) pair -> 'a vector = cast AA.create_v
	    val create_v : int * 'a list -> 'a vector =
                     fn x => create_vP(PAIR x)

	    val floor : real -> int = cast AA.floor
	    val logb : real -> int = cast AA.logb
            val scalbP : (real, int) pair -> real = cast AA.scalb
	    val scalb : real * int -> real = fn x => scalbP(PAIR x)

	    val try_lock : spin_lock -> bool = cast AA.try_lock
	    val unlock : spin_lock -> unit = cast AA.unlock

	  end (* structure A *)

	  val vector0 : 'a vector = cast vector0

      end (* structure Assembly *)

    infix 7  * / quot mod rem div
    infix 6 ^ + -
    infix 3 := o
    infix 4 > < >= <=
    infixr 5 :: @
    infix 0 before

    exception Bind
    exception Match

    exception Range      	(* for word8array update *)
    exception Subscript  	(* for all bounds checking *)
    exception Size

    local exception NoProfiler
    in val profile_register =
      ref(fn s:string => (raise NoProfiler):int*int array*int ref)
    end

    local val ieql : int * int -> bool = InLine.i31eq
          val peql : 'a * 'a -> bool = InLine.ptreql
          val ineq : int * int -> bool = InLine.i31ne
	  val i32eq : int32 * int32 -> bool = InLine.i32eq
          val boxed : 'a -> bool = InLine.boxed
          val op + : int * int -> int = InLine.i31add
          val op - : int * int -> int = InLine.i31sub
          val op * : int * int -> int = InLine.i31mul
	  val op := : 'a ref * 'a -> unit = InLine.:=
          val ordof : string * int -> int = InLine.ordof
          val cast : 'a -> 'b = InLine.cast
          val getObjTag : 'a -> int = InLine.gettag
          val getObjLen : 'a -> int = InLine.objlength
	  val getData : 'a -> 'b = InLine.getSeqData
	  val recSub : ('a * int) -> 'b = InLine.recordSub
          val vecLen : 'a -> int = InLine.length
          val vecSub : 'a vector * int -> 'a = InLine.vecSub
          val andb : int * int -> int = InLine.i31andb

	  val width_tags = 0w7  (* 5 tag bits plus "10" *)

        (* the type annotation is just to work around an bug - sm *)
          val ltu : int * int -> bool = InLine.i31ltu

    in

     (* limit of array, string, etc. element count is one greater than
      * the maximum length field value (sign should be 0).
      *)
       val max_length =
	   let val op - = InLine.w31sub
	       infix << val op << = InLine.w31lshift
	       val int = InLine.copy_31_31_wi
	   in
	       int ((0w1 << (0w31 - width_tags)) - 0w1)
	   end

       fun mkNormArray (n, init) =
             if ieql(n, 0) then InLine.newArray0()
             else if ltu(max_length, n) then raise Size
                  else Assembly.A.array (n, init)

       val mkrarray : int -> real array = InLine.cast Assembly.A.create_r
       fun mkRealArray (n : int, v : real) : real array =
             if ieql(n, 0) then InLine.newArray0()
             else if ltu(max_length, n) then raise Size
                  else let val x = mkrarray n
                           fun init i =
                             if ieql(i,n) then x
    			     else (InLine.f64Update(x,i,v);
                                   init ((op +) (i, 1)))
                        in init 0
                       end

       val vector0 = Assembly.vector0  (* needed to compile ``#[]'' *)


      (* LAZY: The following definitions are essentially stolen from
       *  SMLofNJ.Susp.  Unfortunately, they had to be copied here in
       *  order to implement lazyness (in particular, in order to be
       *  able to compute pids for them.) *)

       local
	   structure Susp :> sig
	       type 'a susp
	       val delay : (unit -> 'a) -> 'a susp
	       val force : 'a susp -> 'a
	   end = struct
	   (* LAZY:  The following is hard-wired and needs to track the object
	    * descriptor definitions.
	    *)
	   val TSUS = 0;  (* == ObjectDesc.special_unevaled_susp *)
	   val TSES = 1;  (* == ObjectDesc.special_evaled_susp *)

	   (* Just a hack for bootstrapping: *)
	   datatype 'a susp = Something of 'a

	   fun delay (f : unit -> 'a) = InLine.mkspecial(TSUS,f): 'a susp
	   fun force (x : 'a susp) =
	       if InLine.i31eq((InLine.getspecial x),TSUS)
	       then let val y : 'a = recSub (InLine.cast x, 0) ()
		    in InLine.cast x := y;
		       InLine.setspecial(InLine.cast x, TSES);
		       y
		    end
	       else recSub (InLine.cast x, 0)
	   end
       in
       open Susp
       end

       (* equality primitives *)

    fun stringequal (a : string, b : string) =
	  if peql(a,b)
	    then true
            else let
	      val len = vecLen a
              in
	        if ieql(len, vecLen b)
                  then let
		    fun f 0 = true
		      | f i = let
			  val j = i-1
			  in
			    ieql(ordof(a,j),ordof(b,j)) andalso f j
			  end
	            in
		      f len
                    end
	          else false
	      end

    fun polyequal (a : 'a, b : 'a) = peql(a,b)
	  orelse (boxed a andalso boxed b
	    andalso let
	    (* NOTE: since GC may strip the header from the pair in question,
	     * we must fetch the length before getting the tag, whenever we
	     * might be dealing with a pair.
	     *)
	      val aLen = getObjLen a
	      val aTag = getObjTag a
	      fun pairEq () = let
		    val bLen = getObjLen b
		    val bTag = getObjTag b
		    in
		      ((ieql(bTag, 0x02) andalso ieql(bLen, 2))
		        orelse ineq(andb(bTag, 0x3),0x2))
		      andalso polyequal(recSub(a, 0), recSub(b, 0))
		      andalso polyequal(recSub(a, 1), recSub(b, 1))
		    end
	      fun eqVecData (len, a, b) = let
		    fun f i = ieql(i, len)
			  orelse (polyequal(recSub(a, i), recSub(b, i))
			    andalso f(i+1))
		    in
		      f 0
		    end
	      in
		case aTag
		 of 0x02 (* tag_record *) =>
		      (ieql(aLen, 2) andalso pairEq())
		      orelse (
			ieql(getObjTag b, 0x02) andalso ieql(getObjLen b, aLen)
			andalso eqVecData(aLen, a, b))
		  | 0x06 (* tag_vec_hdr *) => (
		    (* length encodes element type *)
		      case (getObjLen a)
		       of 0 (* seq_poly *) => let
			    val aLen = vecLen a
			    val bLen = vecLen b
			    in
			      ieql(aLen, bLen)
				andalso eqVecData(aLen, getData a, getData b)
			    end
			| 1 (* seq_word8 *) => stringequal(cast a, cast b)
			| _ => raise Match (* shut up compiler *)
		      (* end case *))
		  | 0x0a (* tag_arr_hdr *) => peql(getData a, getData b)
		  | 0x0e (* tag_arr_data and tag_ref *) => false
(* 64BIT: FIXME *)
		  | 0x12 (* tag_raw *) => i32eq(cast a, cast b)
		  | _ (* tagless pair *) => pairEq()
		(* end case *)
	      end)

        (* trace/debug/profile generation hooks *)
        type tdp_plugin =
	     { name     : string,	(* name identifying plugin *)
	       save     : unit -> unit -> unit,
	       push     : int * int -> unit -> unit,
	       nopush   : int * int -> unit,
	       enter    : int * int -> unit,
	       register : int * int * int * string -> unit }

        local
	    val next = ref 0
	    val hook = ref [] : tdp_plugin list ref

	    val ! = InLine.!
	    infix :=
	    val op := = InLine.:=

	    fun runwith a f = f a

	    fun map f = let
		fun loop [] = []
		  | loop (h :: t) = f h :: loop t
	    in
		loop
	    end

	    fun app f = let
		fun loop [] = ()
		  | loop (h :: t) = (f h; loop t)
	    in
		loop
	    end

	    fun revmap f l = let
		fun loop ([], a) = a
		  | loop (h :: t, a) = loop (t, f h :: a)
	    in
		loop (l, [])
	    end

	    fun onestage sel () =
		let val fns = map sel (!hook)
		in
		    fn arg => app (runwith arg) fns
		end

	    fun twostage sel () =
		let val stage1_fns = map sel (!hook)
		in
		    fn arg =>
		       let val stage2_fns = revmap (runwith arg) stage1_fns
		       in
			   fn () => app (runwith ()) stage2_fns
		       end
		end
	in
	    fun tdp_reserve n = let val r = !next in next := r + n; r end
	    fun tdp_reset () = next := 0

	    (* pre-defined kinds of IDs (to be passed to "register") *)
	    val tdp_idk_entry_point = 0
	    val tdp_idk_non_tail_call = 1
	    val tdp_idk_tail_call = 2

	    val tdp_save = twostage #save
	    val tdp_push = twostage #push
	    val tdp_nopush = onestage #nopush
	    val tdp_enter = onestage #enter
	    val tdp_register = onestage #register

	    val tdp_active_plugins = hook
	end

	val assign = ( InLine.:= )
        val deref = ( InLine.! )
	val unboxedupdate = InLine.unboxedupdate
	val subscript = InLine.arrSub
	val iadd = InLine.i31add

	val testInf = CoreIntInf.testInf
	val truncInf = CoreIntInf.truncInf
	val finToInf = CoreIntInf.finToInf
	val makeNegInf = CoreIntInf.makeNegInf
	val makePosInf = CoreIntInf.makePosInf
	val makeSmallNegInf = CoreIntInf.makeSmallNegInf
	val makeSmallPosInf = CoreIntInf.makeSmallPosInf
	val infLowValue = CoreIntInf.lowValue
    end (* local *)

    val profile_sregister = ref(fn (x:Assembly.object,s:string)=>x)

  end
