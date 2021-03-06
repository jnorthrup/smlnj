(* stringhash.sml
 *
 * Copyright 1989 by AT&T Bell Laboratories
 *)

structure StrgHash =
  struct

    val prime = 8388593 (* largest prime less than 2^23 *)
    val base = 128

    fun hashString (str: string) : int = let
	  val l = size str
	  fun ordof i = Char.ord(String.sub(str, i))
          in
	    case l
	     of 0 => 0
	      | 1 => ordof 0
	      | 2 => ordof 0 + base * ordof 1
	      | 3 => ordof 0 + base * (ordof 1 + base * ordof 2)
	      | _ => let
		  fun loop (0,n) = n
		    | loop (i,n) = let
			val i = i-1
			val n' = ordof i + (base * n) 
			in
			  loop (i, (n' - prime * Int.quot(n', prime)))
			end
		  in
		    loop (l,0)
		  end
	    (* end case *)
	  end

  end (* structure StrgHash *)




(*
 * $Log: strghash.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:49  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:50  george
 *   Version 109.24
 *
 *)
