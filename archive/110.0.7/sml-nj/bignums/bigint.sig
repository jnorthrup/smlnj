(* Copyright 1989 by AT&T Bell Laboratories *)
signature BIGINT =
  sig type bigint			(* non-negative *)
      val bigint : int -> bigint
      val getbit : bigint * int -> bool  (* get the i'th bit; low-order
				            bit is numbered 0 *)
      val size : bigint -> int	(* size 0 = 0; size i = 1+floor(log2(i)) *)
      val + : bigint * bigint -> bigint
      val * : bigint * bigint -> bigint
      val >> : bigint * int -> bigint    (* shift right *)
  end

(*
 * $Log: bigint.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:37  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:12  george
 *   Version 109.24
 *
 *)
