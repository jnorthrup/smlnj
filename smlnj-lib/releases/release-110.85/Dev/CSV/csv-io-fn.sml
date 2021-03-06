(* csv-io-fn.sml
 *
 * COPYRIGHT (c) 2018 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *)

functor CSVIOFn (CSV : CSV) : sig

  (* `load f init ins` loads a comma-separated value file, where `f` is a function
   * for processing a row of the CSV file, `init` is the initial value, and `ins`
   * is the input stream.
   *)
    val load : (string CSV.seq * 'a -> 'a) -> 'a -> TextIO.instream -> 'a

  end = struct

    fun load doRow init ins = let
	  fun lp acc = (case TextIO.inputLine ins
		 of SOME ln => (case CSV.fromString ln
		       of SOME row => lp (doRow (row, acc))
			| NONE => raise Fail(concat[
			      "bad row: \"", String.toString ln, "\"\n"
			    ])
		      (* end case *))
		  | NONE => acc
		(* end case *))
	  in
	    lp init
	  end

  end


