/* vproc-state.h
 *
 * COPYRIGHT (c) 1992 by AT&T Bell Laboratories.
 *
 * This is the state of a virtual processor.
 */

#ifndef _VPROC_STATE_
#define _VPROC_STATE_

#ifndef _ML_BASE_
#include "ml-base.h"
#endif

#ifndef _ML_SIGNALS_
#include "ml-signals.h"
#endif

#ifndef _SYSTEM_SIGNALS_
#include "system-signals.h"
#endif

#ifndef _ML_TIMER_
#include "ml-timer.h"
#endif

#if defined(MP_SUPPORT) && (! defined(_ML_MP_))
#include "ml-mp.h"
#endif


/** The Virtual processor state vector **
 *
 * The fields that are accessed by the runtime assembly code are allocated at
 * word size to keep the assembly code simpler.
 */
struct vproc_state {
    heap_t	*vp_heap;	    /* The heap for this ML task */
    ml_state_t	*vp_state;	    /* The state of the ML task that is */
				    /* running on this VProc.  Eventually */
				    /* we will support multiple ML tasks */
				    /* per VProc. */
				    /* Signal related fields: */
    Word_t	vp_inMLFlag;		/* True while executing ML code */
    Word_t	vp_handlerPending;	/* Is there a signal handler pending? */
    Word_t	vp_inSigHandler;	/* Is an ML signal handler active? */
    sig_count_t	vp_totalSigCount;	/* summary count for all system signals */
    sig_count_t	vp_sigCounts[SIGMAP_SZ]; /* counts of signals. */
    int		vp_sigCode;		/* the code and count of the next */
    int		vp_sigCount;		/* signal to handle. */
    int		vp_nextPendingSig;	/* the index in sigCounts of the next */
					/* signal to handle. */
    int		vp_gcSigState;		/* The state of the GC signal handler */
    Time_t	*vp_gcTime0;	    /* The cumulative CPU time at the start of */
				    /* the last GC (see kernel/timers.c). */
    Time_t	*vp_gcTime;	    /* The cumulative GC time. */
    Addr_t	vp_limitPtrMask;   /* for raw-C-call interface */
#ifdef MP_SUPPORT
    mp_pid_t	vp_mpSelf;	    /* the owning process's ID */
    vproc_status_t vp_mpState;	    /* proc state (see ml-mp.h) */
#endif
};

#endif /* !_VPROC_STATE_ */

