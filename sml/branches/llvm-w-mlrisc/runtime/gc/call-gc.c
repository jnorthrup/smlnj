/*! \file call-gc.c
 *
 * The main interface between the GC and the rest of the run-time system.
 * These are the routines used to invoke the GC.
 *
 * \author John Reppy
 */

/*
 * COPYRIGHT (c) 2021 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 */

#ifdef PAUSE_STATS		/* GC pause statistics are UNIX dependent */
#  include "ml-unixdep.h"
#endif

#include <stdarg.h>
#include "ml-base.h"
#include "ml-limits.h"
#include "memory.h"
#include "ml-state.h"
#include "ml-values.h"
#include "ml-objects.h"
#include "cntr.h"
#include "heap.h"
#include "heap-monitor.h"
#include "ml-globals.h"
#include "ml-timer.h"
#include "gc-stats.h"
#include "vproc-state.h"
#include "profile.h"

#ifdef C_CALLS
/* This is a list of pointers into the C heap locations that hold
 * pointers to ML functions. This list is not part of any ML data
 * structure(s).  (also see gc/major-gc.c and c-libs/c-calls/c-calls-fns.c)
 */
extern ml_val_t		CInterfaceRootList;
#endif


/* InvokeGC:
 *
 * Invoke a garbage collection.  A garbage collection always involves
 * collecting the allocation space.  In addition, if level is greater than
 * 0, or if the first generation is full after the minor collection, then
 * a major collection of one or more generations is performed (at least
 * level generations are collected).
 */
void InvokeGC (ml_state_t *msp, int level)
{
    ml_val_t	*roots[NUM_GC_ROOTS];	/* registers and globals */
    ml_val_t	**rootsPtr = roots;
    heap_t	*heap;
    int		i;
#ifdef MP_SUPPORT
    int		nProcs;
#endif

    ASSIGN(ProfCurrent, PROF_MINOR_GC);

#ifdef MP_SUPPORT
#ifdef MP_DEBUG
    SayDebug ("igc %d\n", msp->ml_mpSelf);
#endif
    if ((nProcs = MP_StartCollect (msp)) == 0) {
      /* a waiting proc */
	ASSIGN(ProfCurrent, PROF_RUNTIME);
	return;
    }
#endif

    START_GC_PAUSE(msp->ml_heap);

#ifdef C_CALLS
    *rootsPtr++ = &CInterfaceRootList;
#endif

#ifdef MP_SUPPORT
  /* get extra roots from procs that entered through InvokeGCWithRoots */
    for (i = 0;  mpExtraRoots[i] != NIL(ml_val_t *); i++)
	*rootsPtr++ = mpExtraRoots[i];
#endif

  /* Gather the roots */
    for (i = 0;  i < NumCRoots;  i++)
	*rootsPtr++ = CRoots[i];
#ifdef MP_SUPPORT
    {
	vproc_state_t   *vsp;
	ml_state_t	*msp;
	int		j;

	for (j = 0; j < MAX_NUM_PROCS; j++) {
	    vsp = VProc[j];
	    msp = vsp->vp_state;
#ifdef MP_DEBUG
	SayDebug ("msp[%d] alloc/limit was %x/%x\n",
	    j, msp->ml_allocPtr, msp->ml_limitPtr);
#endif
	    if (vsp->vp_mpState == MP_PROC_RUNNING) {
		*rootsPtr++ = &(msp->ml_arg);
		*rootsPtr++ = &(msp->ml_cont);
		*rootsPtr++ = &(msp->ml_closure);
		*rootsPtr++ = &(msp->ml_exnCont);
		*rootsPtr++ = &(msp->ml_varReg);
		*rootsPtr++ = &(msp->ml_calleeSave[0]);
		*rootsPtr++ = &(msp->ml_calleeSave[1]);
		*rootsPtr++ = &(msp->ml_calleeSave[2]);
	    }
	} /* for */
    }
#else /* !MP_SUPPORT */
    *rootsPtr++ = &(msp->ml_linkReg);
    *rootsPtr++ = &(msp->ml_arg);
    *rootsPtr++ = &(msp->ml_cont);
    *rootsPtr++ = &(msp->ml_closure);
    *rootsPtr++ = &(msp->ml_exnCont);
    *rootsPtr++ = &(msp->ml_varReg);
    *rootsPtr++ = &(msp->ml_calleeSave[0]);
    *rootsPtr++ = &(msp->ml_calleeSave[1]);
    *rootsPtr++ = &(msp->ml_calleeSave[2]);
#endif /* MP_SUPPORT */
    *rootsPtr = NIL(ml_val_t *);

    MinorGC (msp, roots);

    heap = msp->ml_heap;

  /* Check for major GC */
    if (level == 0) {
	gen_t	*gen1 = heap->gen[0];
	Word_t	sz = msp->ml_allocArenaSzB;

	for (i = 0;  i < NUM_ARENAS;  i++) {
	    arena_t *arena = gen1->arena[i];
	    if (isACTIVE(arena) && (AVAIL_SPACE(arena) < sz)) {
		level = 1;
		break;
	    }
	}
    }

    if (level > 0) {
#ifdef MP_SUPPORT
	vproc_state_t   *vsp;
	ml_state_t	*msp;

	for (i = 0; i < MAX_NUM_PROCS; i++) {
	    vsp = VProc[i];
	    msp = vsp->vp_state;
	    if (vsp->vp_mpState == MP_PROC_RUNNING)
		*rootsPtr++ = &(msp->ml_linkReg);
	}
#else
	ASSIGN(ProfCurrent, PROF_MAJOR_GC);
#endif
	*rootsPtr = NIL(ml_val_t *);
	MajorGC (msp, roots, level);
    }
    else {
	HeapMon_UpdateHeap (heap, 1);
    }

  /* reset the allocation space */
    msp->ml_allocPtr	= heap->allocBase;
    msp->ml_limitPtr    = HEAP_LIMIT(heap);

    STOP_GC_PAUSE();

    ASSIGN(ProfCurrent, PROF_RUNTIME);

} /* end of InvokeGC */


/* InvokeGCWithRoots:
 *
 * Invoke a garbage collection with possible additional roots.  The list of
 * additional roots should be NIL terminated.  A garbage collection always
 * involves collecting the allocation space.  In addition, if level is greater
 * than 0, or if the first generation is full after the minor collection, then
 * a major collection of one or more generations is performed (at least level
 * generations are collected).
 *
 * NOTE: the MP version of this may be broken, since if a processor calls this
 * but isn't the collecting process, then the extra roots are lost.
 */
void InvokeGCWithRoots (ml_state_t *msp, int level, ...)
{
    ml_val_t	*roots[NUM_GC_ROOTS+NUM_EXTRA_ROOTS];	/* registers and globals */
    ml_val_t	**rootsPtr = roots, *p;
    heap_t	*heap;
    int		i;
    va_list	ap;

    ASSIGN(ProfCurrent, PROF_MINOR_GC);

    START_GC_PAUSE(msp->ml_heap);

#ifdef C_CALLS
    *rootsPtr++ = &CInterfaceRootList;
#endif

  /* record extra roots from param list */
    va_start (ap, level);
    while ((p = va_arg(ap, ml_val_t *)) != NIL(ml_val_t *)) {
	*rootsPtr++ = p;
    }
    va_end(ap);

  /* Gather the roots */
    for (i = 0;  i < NumCRoots;  i++)
	*rootsPtr++ = CRoots[i];
    *rootsPtr++ = &(msp->ml_arg);
    *rootsPtr++ = &(msp->ml_cont);
    *rootsPtr++ = &(msp->ml_closure);
    *rootsPtr++ = &(msp->ml_exnCont);
    *rootsPtr++ = &(msp->ml_varReg);
    *rootsPtr++ = &(msp->ml_calleeSave[0]);
    *rootsPtr++ = &(msp->ml_calleeSave[1]);
    *rootsPtr++ = &(msp->ml_calleeSave[2]);
    *rootsPtr = NIL(ml_val_t *);

    MinorGC (msp, roots);

    heap = msp->ml_heap;

  /* Check for major GC */
    if (level == 0) {
	gen_t	*gen1 = heap->gen[0];
	Word_t	sz = msp->ml_allocArenaSzB;

	for (i = 0;  i < NUM_ARENAS;  i++) {
	    arena_t *arena = gen1->arena[i];
	    if (isACTIVE(arena) && (AVAIL_SPACE(arena) < sz)) {
		level = 1;
		break;
	    }
	}
    }

    if (level > 0) {
	ASSIGN(ProfCurrent, PROF_MAJOR_GC);
	*rootsPtr++ = &(msp->ml_linkReg);
	*rootsPtr++ = &(msp->ml_pc);
	*rootsPtr = NIL(ml_val_t *);
	MajorGC (msp, roots, level);
    }
    else {
	HeapMon_UpdateHeap (heap, 1);
    }

  /* reset the allocation space */
    msp->ml_allocPtr	= heap->allocBase;
    msp->ml_limitPtr    = HEAP_LIMIT(heap);

    STOP_GC_PAUSE();

    ASSIGN(ProfCurrent, PROF_RUNTIME);

} /* end of InvokeGCWithRoots */

/* NeedGC:
 *
 * Check to see if a GC is required, or if there is enough heap space for
 * nbytes worth of allocation.  Return TRUE, if GC is required, FALSE
 * otherwise.
 */
bool_t NeedGC (ml_state_t *msp, Word_t nbytes)
{
    if (((Addr_t)(msp->ml_allocPtr)+nbytes) >= (Addr_t)HEAP_LIMIT(msp->ml_heap))
	return TRUE;
    else
	return FALSE;

} /* end of NeedGC */
