(* profile.sml
 *
 * Copyright 1989 by AT&T Bell Laboratories
 *)
(* This should be duplicated in runtime/prof.h *)

structure Profile =
struct
  val ARRAYS =		0
  val ARRAYSIZE =	1
  val STRINGS =		2
  val STRINGSIZE =	3
  val REFCELLS =	4
  val REFLISTS =	5
  val CLOSURES =	6
  val CLOSURESLOTS =	11
  val CLOSUREOVFL =	(CLOSURES + CLOSURESLOTS)
  val KCLOSURES =	(CLOSUREOVFL + 1)
  val KCLOSURESLOTS =	11
  val KCLOSUREOVFL =	(KCLOSURES + KCLOSURESLOTS)
  val CCLOSURES =	(KCLOSUREOVFL + 1)
  val CCLOSURESLOTS =	11
  val CCLOSUREOVFL =	(CCLOSURES + CCLOSURESLOTS)
  val LINKS =		(CCLOSUREOVFL + 1)
  val LINKSLOTS =	11
  val LINKOVFL =	(LINKS + LINKSLOTS)
  val SPLINKS =		(LINKOVFL + 1)
  val SPLINKSLOTS =	11
  val SPLINKOVFL =	(SPLINKS + SPLINKSLOTS)
  val RECORDS =		(SPLINKOVFL + 1)
  val RECORDSLOTS =	11
  val RECORDOVFL =	(RECORDS + RECORDSLOTS)
  val SPILLS =		(RECORDOVFL + 1)
  val SPILLSLOTS =	21
  val SPILLOVFL =	(SPILLS + SPILLSLOTS)
  val KNOWNCALLS =	(SPILLOVFL + 1)
  val STDKCALLS =	(KNOWNCALLS + 1)
  val STDCALLS =	(STDKCALLS + 1)
  val CNTCALLS =	(STDCALLS + 1)
  val ARITHOVH =	(CNTCALLS+1)
  val ARITHSLOTS =	5
  val PROFSIZE =	(ARITHOVH+ARITHSLOTS)
end

