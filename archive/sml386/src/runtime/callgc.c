/* callgc.c      (MS-Windows version)
 *
 * COPYRIGHT (c) 1990 by AT&T Laboratories.
 *
 * Altered 20 Dec. 1991 by:   Yngvi S. Guttesen
 *                            Department of Computer Science
 *			      The Technical University of Denmark
 *			      DK-2800 Lyngby
 */

#include "sml.h"
#include "ml_os.h"
#include "ml_state.h"
#include "ml_types.h"
#include "tags.h"
#include "cause.h"
#include "request.h"

EXTASM(collected0)
EXTASM(collectedfrom0)
EXTASM(current0)
EXTASM(gcmessages0)
EXTASM(majorcollections0)
EXTASM(minorcollections0)
EXTASM(pstruct0)
EXTASM(ratio0)
EXTASM(sighandler0)
EXTASM(softmax0)

#define collected (collected0[1])
#define collectedfrom (collectedfrom0[1])
#define current (current0[1])
#define gcmessages (gcmessages0[1])
#define majorcollections (majorcollections0[1])
#define minorcollections (minorcollections0[1])
#define pstruct (pstruct0[1])
#define ratio (ratio0[1])
#define softmax (softmax0[1])

long arenabase;                 /* bottom of the heap */
long arenasize = 0;             /* heap starts empty */
long new_size = 1024L * 1024L;	/* default heap size of 1M */
long arstart;                   /* beginning of allocation arena */
long arend;                     /* end of main arena, and the heap */
long old_high;                  /* marks end of persistent heap */
long lastbreak;
long new_high ;
long new_new_high ;
int preserving = 0;

EXTASM(store_preserve) ;

static long  pagesize;

/* function prototypes */

void init_gc();
void restart_gc();
int check_heap(long);
long check_gc_timer(void);
void callgc0 (long, long);
int  gc(ML_val_t, ML_val_t, ML_val_t, ML_val_t, ML_val_t,
        ML_val_t, ML_val_t, ML_val_t, ML_val_t, ML_val_t, );
static void callgc (long, ML_val_t, BRSP, ML_val_t);
static long getmore_die ();
static long getmore_must ();
long increase_heapsize();
long decrease_heapsize();
long compute_new_size();
static long brk(long);
static long sbrk(long);

/* init_gc:
 */
void init_gc ()
{
    pagesize             = 4*1024 ; /* getpagesize() 4k */
    arenabase		 = sbrk(0);
    lastbreak		 = arenabase;
    increase_heapsize();
    old_high		 = arenabase;
    arstart              = ((arenabase+arenasize/2)+3)&(~3);
    collected		 = INT_CtoML(0);
    collectedfrom	 = INT_CtoML(0);
    minorcollections	 = INT_CtoML(0);
    majorcollections	 = INT_CtoML(0);
    MLState->ml_allocptr = arstart;
    MLState->ml_limitptr = arenabase+arenasize-4096;
}


/* restart_gc:
 */
void restart_gc()
{
    long                 live_size = old_high - arenabase;
    long                 a = 0;
    ML_val_t             x = gcmessages;
    extern long edata;

    resettimers();
    lastbreak = edata;
    gcmessages = INT_CtoML(0);
    new_size = compute_new_size(live_size);
    do {
	increase_heapsize();
	if (arenasize == a)
	    die("Can't get enough memory to start ML\n");
	a = arenasize;
    } while (arenasize < 3*live_size);
    gcmessages = x;
    MLState->ml_allocptr = arstart;
    MLState->ml_limitptr = lastbreak-4096;

} /* end of restart_gc */


/* check_heap:
 * Check the heap to insure that there is a sufficient amount of available
 * memory in the allocation arena.  If not, then do a garbage collection and
 * return 1, otherwise return 0.
 * NOTE: if a garbage collection is done, then any roots in C variables (other
 * than the ML state vector) are obsolete.
 */
int check_heap (amount)
    long        amount;
{
    register long   top = (arenabase + arenasize) - 4096;

    if ((MLState->ml_allocptr + amount) >= top) {
        register long   i;
	if (gcmessages >= INT_CtoML(3))
            chatting("[check_heap: %ld bytes available, %ld required]\n",
		(top + 4096) - MLState->ml_allocptr, amount+4096);

	callgc0 (CAUSE_GC, STD_ARGS_MASK);
	return 1;
    }
    else
	return 0;

} /* end of check_heap */


/* callgc0:
 */
void callgc0 (cause, mask)
    long      cause, mask;
{
    int        i,j;
    EXTASM(roots)
    EXTASM(currentsave)
    EXTASM(gcprof)

    *currentsave = current ;
    current = PTR_CtoML(LOWORD(gcprof+1));

    start_gc_timer();

    roots[0] = LOWORD(&pstruct);
    roots[1] = LOWORD(currentsave);
    roots[2] = LOWORD(store_preserve);
    roots[3] = LOWORD(sighandler0+1);
    roots[4] = LOWORD(&(MLState->ml_pc));
    roots[5] = LOWORD(&(MLState->ml_exncont));

    for (i = 0, j=6;  mask != 0; i++, mask >>= 1)
        if ((mask & 1) != 0)
            roots[j++] = LOWORD(&(MLState->ml_roots[ArgRegMap[i]]));

    roots[j] = 0;

    callgc ( cause,
            LOWORD(roots),
            (BRSP)LOWORD(&(MLState->ml_allocptr)),
            MLState->ml_storeptr);

    MLState->ml_limitptr = (arend - 4096);
    MLState->ml_storeptr = (long)STORLST_nil;
    current = *currentsave;

    stop_gc_timer();

} /* end of callgc0 */



/* callgc:
 */
static void callgc (cause, misc_roots, arptr, store_list)
    long        cause;             /* the reason for doing GC            */
    ML_val_t   misc_roots;        /* vector of ptrs to extra root words */
    BRSP       arptr;             /* place to put new freespace pointer */
    ML_val_t   store_list;        /* list of refs stored into           */
{
    long amount_desired;

    arend = arenabase+arenasize;
    if ((cause == CAUSE_GC) || (cause == CAUSE_BLAST))
 	amount_desired = 4 + arend - (*arptr);
    else
	amount_desired = 0;
    if (arstart == *arptr)
        new_high = old_high; /* no minor needed */
    else  {
	if (gcmessages >= INT_CtoML(3))
	    chatting("\n[Minor collection...");
        gc (arstart,
            arend,
            old_high,
            arstart,
            old_high,
            LOWORD(&new_high),
            misc_roots,
            store_list,
            LOWORD(getmore_die),  /* remember this is a USE16 func */
            0);
	{
            long a = new_high-old_high, b =(*arptr)-arstart;
	    if (gcmessages >= INT_CtoML(3))
                chatting(" %ld%% used (%ld/%ld), %ld msec]\n",
		    a/((b+50)/100), a, b, check_gc_timer());
	    collected = INT_incr(collected, (a+512)/1024); /* round to nearest K */
	    collectedfrom = INT_incr(collectedfrom, (b+512)/1024);
	    minorcollections = INT_incr(minorcollections, 2);
	}
    }

    {
        long need_major = 0;
        long was_preserving;
        long gamma = INT_MLtoC(ratio);

	if (gamma < 3) gamma = 3;

	if ((cause == CAUSE_EXPORT) || (cause == CAUSE_BLAST) || (cause == CAUSE_MAJOR))
	    need_major = 1;
	else {
            long cut = arenasize-arenasize/gamma;
            long max = INT_MLtoC(softmax);
            long halfmax = max/2;
            long halfsize = arenasize/2;
	    cut = (cut<halfmax ? cut : halfmax);
	    cut = (cut>halfsize ? cut : halfsize);
            if (new_high+amount_desired > arenabase+cut)
		need_major = 1;
	    else {
                long live_size = amount_desired+new_high-old_high;
		new_size = compute_new_size(live_size);
		if (new_size > arenasize
                && (increase_heapsize()-new_high)/2 <= amount_desired)
		    need_major = 1;
	   }
	}
	if (cause == CAUSE_BLAST)
            old_high = new_high;
	if (need_major) {
            long        msec0;
	    if (gcmessages >= INT_CtoML(1)) {
		chatting("\n[Major collection...");
		msec0 = check_gc_timer();
	    }
            was_preserving=preserving; preserving=0;
            if (gc(arenabase,
                   old_high,
                   old_high,
                   arenabase+arenasize,
                   new_high,
                   LOWORD(&new_new_high),
                   misc_roots,
                   1,
                   LOWORD(getmore_must),
                   (cause == CAUSE_BLAST) ? LOWORD(&(MLState->ml_arg)) : 0))
	    {
                moveback (old_high,
                          new_new_high,
                          arenabase,
                          misc_roots);
		{
                    long a = new_new_high-new_high, b = new_high-arenabase;
		    if (gcmessages >= INT_CtoML(1))
                        chatting(" %ld%% used (%ld/%ld), %ld msec]\n",
			    a/((b+50)/100), a, b, check_gc_timer()-msec0);
		    collected += 2*((a+512)/1024);
		    collectedfrom += 2*((b+512)/1024);
		    majorcollections += 2;
		}
		{
                    long live_size = amount_desired+new_new_high-old_high;
                    old_high = arenabase+new_new_high-old_high;
		    new_size = compute_new_size(live_size);
		    if (new_size > arenasize) {
                        long end = increase_heapsize();
			if ((end-old_high)/2 <= amount_desired)
			    die("\nRan out of memory\n");
		    }
		    else if (new_size < (arenasize/4)*3)
			decrease_heapsize();
		}
	    }
	    else {
		if (gcmessages >= INT_CtoML(1))
		    chatting("abandoned]\n");
	    }
            preserving=was_preserving;
	}
	else
            old_high=new_high;
    }
    arend = arenabase+arenasize;
    arstart = (((arend+old_high)/2)+3)&(~3);
    (*arptr) = arstart;

} /* end of callgc */


/* getmore_die:
 */
static long getmore_die ()
{
    die("bug: insufficient to_space\n");
}

long amount_desired;

/* decrease_heapsize:
 */
long decrease_heapsize ()
{
    long         p = arenabase+new_size;
    p = (p + pagesize-1 ) & ~(pagesize-1);
    if (p < lastbreak) {
	brk(p);
	arenasize = p-arenabase;
	if (gcmessages >= INT_CtoML(2))
	    chatting ("\n[Decreasing heap to %dk]\n",arenasize/1024);
	lastbreak = p;
    }
    return lastbreak;
}

/* increase_heapsize:
 * Assume that new_size > arenasize.
 */
long increase_heapsize ()
{
    long         p = arenabase+new_size;

  RESTART:;
    p = (p + pagesize-1 ) & ~(pagesize-1);
    if (p == lastbreak) {
	if (gcmessages >= INT_CtoML(2))
	    chatting("\nWarning: can't increase heap\n");
	return p;
    }
    else if (brk(p)) {
	if (gcmessages >= INT_CtoML(3))
	    chatting("\nWarning: must reduce heap request\n");
	p = (lastbreak+(p-pagesize))/2;
	goto RESTART;
    }
    else {
	lastbreak=p;
	arenasize = p-arenabase;
	if (gcmessages >= INT_CtoML(2))
            chatting("\n[Increasing heap to %dk]\n",arenasize/1024);
        return p;
    }
}

long compute_new_size (live_size)
    long         live_size;
{
    long         new_size;
    long         gamma = INT_MLtoC(ratio);
    long         max = INT_MLtoC(softmax);

    if (gamma < 3)
	gamma = 3;
    if (0x20000000L / gamma < live_size)
        new_size = 0x20000000L;
    else
	new_size = live_size*gamma;
    if (max < new_size) {
        long new = 3*live_size;
	new_size = ((new > max) ? new : max);
    }
    return new_size;
}

/* getmore_must:
 */
static long getmore_must ()
{
    long         oldsize = arenasize;
    long         live_size = amount_desired+arenasize+arenabase-old_high;
    long         r;

    new_size = compute_new_size(live_size);
    r = increase_heapsize();
    if (oldsize == arenasize)
	die("\nRan out of memory");
    return r;

} /* end of getmore_must */


/* simulations of the UNIX brk() and sbrk() */

static long sbrk(long incr)
{
    extern long Use32HeapSize ;

    if (incr)
        die("sbrk called with nonzero value");
    else
        return Use32HeapSize ;
} /* end of sbrk */

static long brk(long pos)
{
    extern long Use32HeapSize ;

//  Windows has trouble handling Global32Realloc !
//    if (Global32Realloc(wsUse32Data,pos,0))
//        return -1 ;
//    /* the aliases are updated automatically */

    if (pos>0xF00000L)
        return -1;

    Use32HeapSize = pos;

    return 0;
} /* end of brk */
