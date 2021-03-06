(* dump.sml
 *
 * COPYRIGHT (c) 2020 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 *
 * Dump a CFG comp_unit
 *)

structure Dump =
  struct

    val dump = ASDLFilePickle.toFile CFGFilePickle.write_comp_unit

    fun dumpAll () = List.app dump [
	    ("triv.pkl", Triv.cu),
	    ("ex0.pkl", Ex0.cu),
	    ("ex1.pkl", Ex1.cu),
	    ("ex2.pkl", Ex2.cu),
	    ("ex3.pkl", Ex3.cu),
	    ("ex4.pkl", Ex4.cu),
	    ("ex5.pkl", Ex5.cu),
	    ("ex6.pkl", Ex6.cu),
	    ("ex8.pkl", Ex8.cu),
	    ("ex9.pkl", Ex9.cu)
	  ]

  end
