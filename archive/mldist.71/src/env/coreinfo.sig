(* Copyright 1989 by AT&T Bell Laboratories *)
(* coreinfo.sig *)

signature COREINFO =
sig
    val exnBind : Basics.datacon ref
    val exnMatch : Basics.datacon ref

    val exnOrd : Basics.datacon ref
    val exnSubscript : Basics.datacon ref
    val exnFpSubscript : Basics.datacon ref
    val exnRange : Basics.datacon ref
     
    val stringequalPath : int list ref
    val polyequalPath : int list ref
    val currentPath : int list ref
    val toplevelPath : int list ref
    val getDebugVar : Basics.var ref
    val resetCore: unit -> unit
    val setCore : Basics.structureVar -> unit
    val forcerPath : int list ref
end

