(*
 * This is the new "generic" unpickle utility.  It replaces Andrew Appel's
 * original "shareread" module.  The main difference is that instead of
 * using a "universal" type together with numerous injections and projections
 * it uses separate maps.  This approach proves to be a lot more light-weight.
 *
 * The benefits are:
 *   - no projections, hence no "match nonexhaustive" warnings and...
 *   - ...no additional run-time overhead (all checking is done during
 *     the map membership test which is common to both implementations)
 *   - no necessity for those many tiny "fn"-functions that litter the
 *        original code, resulting in...
 *   - ...a more "natural" style for writing the actual unpickling code
 *        that makes for shorter source code
 *   - ...a lot less generated machine code (less than 50% of the original
 *        version)
 *   - ...slightly faster operation (around 15% speedup)
 *        (My guess is that it is a combination of fewer projections and
 *         fewer generated thunks that make the code run faster.)
 *
 * July 1999, Matthias Blume
 *)
signature UNPICKLE_UTIL = sig

    exception Format

    type 'v map				(* one for each type *)
    type session			(* encapsulates unpickling state *)

    (* Make a type-specific sharing map using "mkMap".
     *
     * Be sure to create such maps only locally, otherwise you have a
     * space leak.
     *
     * The ML type system will prevent you from accidentially using the
     * same map for different types, so don't worry.  But using TOO MANY
     * maps (i.e., more than one map for the same type) will likely
     * cause problems because the unpickler might try to look for a
     * back reference that is in a different map than the one where the
     * value is actually registered.
     *
     * By the way, this warning is not unique to the many-maps approach.
     * The same thing would happen with the original "universal domain"
     * unpickler if you declare two different constructors for the
     * same type.  Given that there are about 100 types (and thus
     * 100 constructors or maps) in the SML/NJ environment pickler,
     * the possibility for such a mistake is not to be dismissed. *)
    val mkMap : unit -> 'v map

    type 'v reader = unit -> 'v

    (* A "charGetter" is the mechanism that gets actual characters from
     * the pickle.  For ordinary pickles, the unpickler will never call
     * "seek".  Moreover, the same is true if you read the pickles created
     * by pickleN sequentially from the first to the last (i.e., not
     * "out-of-order"). "cur" determines the current position and must be
     * implemented. *)
    type charGetter =
	{ read: char reader, seek: int -> unit, cur: unit -> int }

    (* the string is the pickle string *)
    val stringGetter : string -> charGetter

    (* open the unpickling session - everything is parameterized by this;
     * the charGetter provides the bytes of the pickle *)
    val mkSession : charGetter -> session

    (* The typical style is to write a "reader" function for each type
     * The reader function uses a local helper function which takes the
     * first character of a pickle (this is usually the discriminator that
     * was given to $ or % in the pickler) and returns the unpickled
     * value.  The function recursively calls other "reader" functions.
     * To actually get the value from the pickle, pass the helper
     * to "share" -- together with the current session and the
     * type-specific map.  "share" will take care of back-references
     * (using the map) and pass the first character to your helper
     * when necessary.  The standard pattern for writing a "t reader"
     * therefore is:
     *
     * val session = UnpickleUtil.mkSession pickle
     * fun share m f = UnpickleUtil.share session m f
     * ...
     * val t_map = Unpickleutil.mkMap ()
     * ...
     * fun r_t () = let
     *     fun t #"a" = ... (* case a *)
     *       | t #"b" = ... (* case b *)
     *       ...
     *       | _ = raise UnpickleUtil.Format
     * in
     *     share t_map t
     * end
     *)
    val share : session -> 'v map -> (char -> 'v) -> 'v

    (* If you know that you don't need a map because there can be no
     * sharing (typically if you didn't use any $ but only % for pickling
     * your type), then you can use "nonshare" instead of "share". *)
    val nonshare : session -> (char -> 'v) -> 'v

    (* making readers for some common types *)
    val r_int : session -> int reader
    val r_int32 : session -> Int32.int reader
    val r_word : session -> word reader
    val r_word32 : session -> Word32.word reader
    val r_bool : session -> bool reader
    val r_string : session -> string reader

    (* readers for parametric types need their own map *)
    val r_list : session -> 'v list map -> 'v reader -> 'v list reader
    val r_option : session -> 'v option map -> 'v reader -> 'v option reader

    (* pairs are not shared, so we don't need a map here *)
    val r_pair : 'a reader * 'b reader -> ('a * 'b) reader

    (* The laziness generated here is in the unpickling.  In other words
     * unpickling state is not discarded until the last lazy value has been
     * forced. *)
    val r_lazy : session -> 'a reader -> (unit -> 'a) reader
end

structure UnpickleUtil :> UNPICKLE_UTIL = struct

    exception Format

    type 'v map = ('v * int) IntBinaryMap.map ref
    type state = string map

    type 'v reader = unit -> 'v

    type charGetter =
	{ read: char reader, seek: int -> unit, cur: unit -> int }

    type session = { state: state, getter: charGetter }

    fun mkMap () = ref IntBinaryMap.empty

    fun stringGetter pstring = let
	val pos = ref 0
	fun rd () = let
	    val p = !pos
	in
	    pos := p + 1;
	    String.sub (pstring, p) handle Subscript => raise Format
	end
	fun sk p = pos := p
	fun cur () = !pos
    in
	{ read = rd, seek = sk, cur = cur }
    end

    local
	fun f_anyint rd () = let
	    val & = Word8.andb
	    infix &
	    val large = Word8.toLargeWord
	    fun loop n = let
		val w8 = Byte.charToByte (rd ())
	    in 
		if (w8 & 0w128) = 0w0 then
		    (n * 0w64 + large (w8 & 0w63), (w8 & 0w64) <> 0w0)
		else loop (n * 0w128 + large (w8 & 0w127))
	    end
	in
	    loop 0w0
	end

	fun f_largeword cvt rd () =
	    case f_anyint rd () of
		(w, false) => (cvt w handle _ => raise Format)
	      | _ => raise Format

	fun f_largeint cvt rd () = let
	    val (w, negative) = f_anyint rd ()
	    val i = LargeWord.toLargeInt w handle _ => raise Format
	in
	    (if negative then cvt (~i) else cvt i)
	    handle _ => raise Format
	end
    in
	val f_int = f_largeint Int.fromLarge
	val f_int32 = f_largeint Int32.fromLarge
	val f_word = f_largeword Word.fromLargeWord
	val f_word32 = f_largeword Word32.fromLargeWord
    end

    fun mkSession charGetter =
	({ state = mkMap (), getter = charGetter }: session)

    fun share { state, getter = { read, seek, cur } } m r = let
	fun firsttime (pos, c) = let
	    val v = r c
	    val pos' = cur ()
	in
	    m := IntBinaryMap.insert (!m, pos, (v, pos'));
	    v
	end
    in
	case read () of
	    #"\255" => let
		val pos = f_int read ()
	    in
		case IntBinaryMap.find (!m, pos) of
		    SOME (v, _) => v
		  | NONE => let
			val here = cur ()
		    in
			seek pos;
			(* It is ok to use "read" here because
			 * there won't be back-references that jump
			 * to other back-references. *)
			firsttime (pos, read())
			before seek here
		    end
	    end
	  | c => let
		(* Must subtract one to get back in front of c. *)
		val pos = cur () - 1
	    in
		case IntBinaryMap.find (!m, pos) of
		    SOME (v, pos') => (seek pos'; v)
		  | NONE => firsttime (pos, c)
	    end
    end

    (* "nonshare" gets around backref detection.  Certain integer
     * encodings may otherwise be mis-identified as back references.
     * Moreover, unlike in the case of "share" we don't need a map
     * for "nonshare".  This could be used as an optimization for
     * types that are known to never be shared anyway (bool, etc.). *)
    fun nonshare (s: session) f = f (#read (#getter s) ())

    local
	fun f2r f_x (s: session) = f_x (#read (#getter s))
    in
	val r_int = f2r f_int
	val r_int32 = f2r f_int32
	val r_word = f2r f_word
	val r_word32 = f2r f_word32
    end

    fun r_lazy session r () = let
	val memo = ref (fn () => raise Fail "UnpickleUtil.r_lazy")
	val { getter = { cur, seek, ... }, ... } = session
	(* the size may have leading 0s because of padding *)
	fun getSize () = let
	    val sz = r_int session ()
	in
	    if sz = 0 then getSize () else sz
	end
	val sz = getSize ()		(* size of v *)
	val start = cur ()		(* start of v *)
	fun thunk () = let
	    val wherever = cur ()	(* remember where we are now *)
	    val _ = seek start		(* go to start of v *)
	    val v = r ()		(* read v *)
	in
	    seek wherever;		(* go back to where we were *)
	    memo := (fn () => v);	(* memoize *)
	    v
	end
    in
	memo := thunk;
	seek (start + sz);		(* as if we had read the value *)
	(fn () => !memo ())
    end

    fun r_list session m r () = let
	fun r_chops () = let
	    fun rcl #"N" = []
	      | rcl #"C" = r () :: r () :: r () :: r () :: r () :: r_chops ()
	      | rcl _ = raise Format
	in
	    share session m rcl
	end
	fun rl #"0" = []
	  | rl #"1" = [r ()]
	  | rl #"2" = [r (), r ()]
	  | rl #"3" = [r (), r (), r ()]
	  | rl #"4" = [r (), r (), r (), r ()]
	  | rl #"5" = r_chops ()
	  | rl #"6" = r () :: r_chops ()
	  | rl #"7" = r () :: r () :: r_chops ()
	  | rl #"8" = r () :: r () :: r () :: r_chops ()
	  | rl #"9" = r () :: r () :: r () :: r () :: r_chops ()
	  | rl _ = raise Format
    in
	share session m rl
    end

    fun r_option session m r () = let
	fun ro #"n" = NONE
	  | ro #"s" = SOME (r ())
	  | ro _ = raise Format
    in
	share session m ro
    end

    fun r_pair (r_a, r_b) () = (r_a (), r_b ())

    fun r_bool session () = let
	fun rb #"t" = true
	  | rb #"f" = false
	  | rb _ = raise Format
    in
	nonshare session rb
    end

    fun r_string session () = let
	val { state = m, getter } = session
	val { read, ... } = getter
	fun rs c = let
	    fun loop (l, #"\"") = String.implode (rev l)
	      | loop (l, #"\\") = loop (read () :: l, read ())
	      | loop (l, c) = loop (c :: l, read ())
	in
	    loop ([], c)
	end
    in
	share session m rs
    end
end
