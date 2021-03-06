#include <signal.h>
#include <sys/types.h>

#include "tags.h"
#include "descriptor.h"
#include "ml.h"

#define refcell(z) int z[2] = {mak_desc(1,tag_array), ML_INT(0)};

refcell(collected0)
refcell(collectedfrom0)
refcell(gcmessages0)
refcell(majorcollections0)
refcell(minorcollections0)

#define collected collected0[1]
#define collectedfrom collectedfrom0[1]
#define gcmessages gcmessages0[1]
#define majorcollections majorcollections0[1]
#define minorcollections minorcollections0[1]

int *control_v[] = {(int*)mak_desc(6,tag_record),
		    &collected, &collectedfrom,
		    &gcmessages,
		    &majorcollections,&minorcollections};

int specialgc;               /* if non-zero, return to this location after gc */
int restart;                 /* points to the restart function if exporting */

int arenabase;               /* bottom of the heap */
int arenasize = 1024 * 1024;  /* default heap size of 1 megabyte */
int arstart;                 /* beginning of main arena */
int arend;                   /* end of main arena, and the heap */
int old_high;                /* marks end of persistent heap */
int new_high;
int new_new_high;
float gamma = 3.0;

int lastbreak=0;

extern char *freestart;
extern int ghandle();
int bottom;                  /* marks collectible data on the stack */
int store_save;              /* holds the ref list between applies; see prim */
int pagesize;                /* system page size, needed by export.c */

#ifdef VAX
extern int gtest();
#endif

init_gc()
{
#ifdef V9
 pagesize = 1024;
#endif
#ifdef MACH
 pagesize = 4096;
#endif
#ifdef BSD
 pagesize = getpagesize();
#endif

 arenabase=findbreak(sbrk(0));
 arenasize = (findbreak(arenabase+arenasize)-arenabase);
 old_high = arenabase;
 arstart = arenabase+arenasize/2;
 freestart = (char *)arstart;

#ifdef VAX
 gtest();
#endif
}

extern int edata;

restart_gc()
{
 arenasize = (old_high-arenabase)*3;
 lastbreak = (int)&edata;
 if (arenasize < 1024 * 200) arenasize = 1024 * 200;
 arenasize = (findbreak(arenabase+arenasize)-arenabase);
 arstart = arenabase+arenasize/2;
 freestart = (char *)arstart;
}    

#ifdef M68
#ifdef BSD
extern char before1[], after1[], before2[], after2[];

/* Segmentation bug on the m68:  an instruction can cause a segmentation
   violation but leave the pc pointing at the next instruction.  The
   offending instruction is never executed since Unix doesn't catch the
   error.  Because of the design of the compiler, this only happens in
   predictable places.  Two places in the runtime code, labelled
   before/after1 and before/after2 can cause it, and they are handled
   in callgc_m68bsd.  The bug is caused in compiled code only when consing
   a cell, and it occurs as the last element (first stored) is put into
   the cell.  The instruction is always a move from d0 indirectly through a6,
   possibly with a displacement, or a move from d6 (the special case of
   adding to the store list).
   The only other segmentation fault occurs when allocating a real with the
   instruction "fmoved fp0,a6@".  In this case the machine faults properly,
   with the pc still pointing at the instruction.

   The opcode for "fmoved fp0,a6@" is binary 1111001000010110 (o171026),
					followed by 0111010000000000 (o72000).
   The opcode for "movl d0,a6@" is binary 0010110010000000 (o26200).
   The opcode for "movl d6,a6@" is binary 0010110010000110 (o26206).
   The opcode for "movl d0,a6@(disp)" is binary 0010110101000000 (o26500),
					followed by the word displacement.
   In addition, the 68020 (but not the 68000) supports longer than word
   displacements.  However, this is not used the current compiler.

   If the opcode pointed to by the pc is not an opcode like this, there has
   been a segmentation fault which has left the pc pointing at the next
   instruction.  In this case callgc_m68bsd backs up the pc until it points
   at the (hopefully) correct instruction.
   Possible problems:
	You could have two of these instructions in a row, and a fault on the
	    first.  This never happens in the current compiler.
	You could have a displacement which looks like the opcode of one
	    of the instructions.  This displacement would be at least
	    8192, or 2000 elements in the cell.  There will be a special case
	    to handle large conses like this, so this particular case should
	    never turn up in code spit out by the current compiler.
*/
/* Wrong unless instruction is
 *  movl d0,a6@		(alloc fault)
 *  movl d0,a6@(disp)	(alloc fault)
 *  movl d6,a6@		(ref store)
 *  fmoved fp0,a6@	(real alloc)
 */
wrongopcode(opcode)
unsigned short opcode;
{
 return (opcode != 026200 && opcode != 026206 &&
	 opcode != 026500 && opcode != 0171026);
}


callgc0(B,A)
	struct {int d0,d1,a0,a1,x0,x1,x2,x3,x4,sp,pc,psl} *A;
	struct {int d2[6],a2[5];} B;
{int *regptrs[17]; int i;
 suspendtimers();
 regptrs[0] = &A->d0;
 regptrs[1] = &A->d1;
 regptrs[8] = &A->a0;
 regptrs[9] = &A->a1;
 for (i=0;i<6;i++) regptrs[i+2] = B.d2+i;
 for (i=0;i<5;i++) regptrs[i+10]= B.a2+i;
 regptrs[15] = &A->sp;
 regptrs[16] = &A->pc;
 if (!specialgc)	/* don't care if exporting */
 if (A->pc == (int)after2) A->pc= (int)before2;
 else  if (A->pc == (int)after1) A->pc= (int)before1;
 else  {if(wrongopcode(*(unsigned short *)(A->pc))) A->pc -= 2;
	if(wrongopcode(*(unsigned short *)(A->pc))) A->pc -= 2;
	if(wrongopcode(*(unsigned short *)(A->pc)))
	    die("Memory fault not related to garbage collection.\n");}
 callgc1(regptrs);
 restarttimers();
}
#endif

callgc1(regptrs) int **regptrs;
{unsigned short **pc = (unsigned short**)(regptrs[16]);
 int *roots[20]; int **rootsptr = roots;
 unsigned short opcode = (*pc)[0];
 int *storeptrs = (int*) (*regptrs[6]);

 *regptrs[6]=0;

 /* fix up in case faulted at a ref-store */
 if (opcode == 026206)  /* movl d6,a6@ */
    {static int a[2];
     a[1] = (int)storeptrs;
     a[0] = *regptrs[8];
     storeptrs = a+1; (*pc)+=5;  /* 5 words, that is */
    }
 else if ( opcode==026500   /* movl d0,a6@(n) */
        || opcode==026200 ) /* movl d0,a6@ */
			    /* are there other possibilities? */
	*rootsptr++ = regptrs[0];
 *rootsptr=0;
 callgc(*regptrs[15],pc,roots,regptrs[14],storeptrs);
}
#endif

#ifdef VAX
int pctest, *sptest;
extern char afterg[];

callgc0(arg) int arg;
{int *regptrs[16]; int i; int *args = (&arg)-1; int sp;
 static  int regloc[16]; static int sp_offset;
 int (*inthandle)();
 suspendtimers();
#ifdef V9
 inthandle = signal(SIGINT,SIG_IGN);
#endif
 if (!sp_offset)
  {sp_offset= sptest-args;
    for(i=0;i<sp_offset;i++)
       if ((args[i] & ~ 0xf) == 0x99000)
          regloc[args[i]&0xf]=i;
        else if (args[i]==pctest) regloc[15]=i;
    for(i=0;i<16;i++)
     if (i!=14 && regloc[i]==0)
	    die("Can't find register r%d\n",i);
   args[regloc[15]] = (int)afterg;
#ifdef V9
   signal(SIGINT,inthandle);
   signal(SIGSEGV, ghandle);
#endif
   restarttimers();
   return;
  }

 for(i=0;i<16;i++) regptrs[i] = args + regloc[i];
 sp = (int)(args+sp_offset);
 regptrs[14] = &sp;
 callgc1(regptrs);
#ifdef V9
 signal(SIGINT,inthandle);
#endif
 restarttimers();
}

callgc1(regptrs) int **regptrs;
{unsigned char **pc = (unsigned char**)(regptrs[15]);
 int *roots[20]; int **rootsptr = roots;
 unsigned char opcode = (*pc)[0], mode = (*pc)[1];
 int *storeptrs = (int*) (*regptrs[11]);

 *regptrs[11]=0;

 /* fix up in case faulted at a ref-store */
 if (opcode == 0xd0 && mode == 0x5b)
    {static int a[2];
     a[1] = (int)storeptrs;
     a[0] = *regptrs[(*pc)[4] & 0xf];
     storeptrs = a+1; (*pc)+=13;
    }
#ifdef CPS
	{int i; for(i=0;i<=8;i++) *rootsptr++ = regptrs[i];}
        *rootsptr++ = regptrs[13];
	if (opcode == 0xd0 && mode == 0x59) *rootsptr++ = regptrs[9];
#else
    else
      if ( (opcode == 0xd0 || opcode == 0xde)
	   && (mode>>4)>4 && (mode & 0xf) < 12 )
	*rootsptr++ = regptrs[(mode & 15)];
#endif
 *rootsptr=0;
 callgc(*regptrs[14],pc,roots,regptrs[12],storeptrs);
}
#endif

int getmore_die()
{die("bug: insufficient to_space\n");
}

int more_amount;


int getmore_increase()
{arenasize += more_amount;
 arenasize = findbreak(arenabase+arenasize)-arenabase;
 if (gcmessages >= ML_INT(2))
	chatting("[Increasing heap to %dk]\n",arenasize/1024);
 return arenabase+arenasize;
}

int getmore_must()
{int oldsize=arenasize;
 getmore_increase();
 if (oldsize==arenasize) die("\nRan out of memory\n");
}

#ifndef SIMPLEGC

callgc(sp,	    /* stack pointer at point of fault */
       pcptr,	    /* pc at point of fault (by ref) */
       misc_roots,  /* vector of ptrs to extra root words */
       arptr,	    /* place to put new freespace pointer */
       store_list   /* list of refs stored into */
      )
    int sp; int *pcptr; int ***misc_roots; int *arptr; int **store_list;
{
 int amount_desired;

 arend = arenabase+arenasize;
 amount_desired = arend-((*arptr) - 4);
 if (gcmessages >= ML_INT(3)) chatting("\n[Minor collection...");
 starttime();
 gc(sp,bottom,
    arstart,arend,
    old_high,arstart,
    old_high,
    &new_high,
    misc_roots,pcptr,store_list,
    getmore_die);
    {int a = new_high-old_high, b = arend-arstart, msec=endtime();
     if (gcmessages >= ML_INT(3))
	chatting("  %d%% used  (%d/%d), %d msec]\n", (int)(100.0*a/b), a, b, msec);
     collected += 2*((a+512)/1024); /* round to nearest k */
     collectedfrom += 2*((b+512)/1024);
     minorcollections+=2;
    }
#ifdef GCDEBUG
 checkup(arstart,new_high);
 clear(new_high,arenabase+arenasize);
#endif
 if (restart || new_high > arenabase+arenasize/2)
    {if (gcmessages >= ML_INT(1)) chatting("[Major collection...");
     starttime();
     more_amount = arenasize/2;
     gc(sp,bottom,
	arenabase,old_high,
	old_high,arenabase+arenasize,
	new_high,
	&new_new_high,
        misc_roots,pcptr,0,
        getmore_must);
     moveback(sp,bottom,
	      old_high,new_new_high,
	      arenabase,
	      misc_roots,pcptr);
    {int a = new_new_high-old_high, b = new_high-arenabase, msec=endtime();
     if (gcmessages >= ML_INT(1))
	chatting("  %d%% used  (%d/%d), %d msec]\n", (int)(100.0*a/b), a, b, msec);
     collected += 2*((a+512)/1024);
     collectedfrom += 2*((b+512)/1024);
    }
     if ( (new_new_high-old_high)*gamma > arenasize)
	    {more_amount = (new_new_high-old_high)*gamma-arenasize;
	     getmore_increase();
	    }
     majorcollections+=2;
     old_high=arenabase+(new_new_high-old_high);
    }
 else {old_high=new_high;
       if (!specialgc && amount_desired > (arend-new_high)/4) 
	{more_amount=amount_desired;
	 if (more_amount<50000) more_amount=50000;
	 getmore_increase();
	}
      }
 store_save = 0;
 if (specialgc) {*pcptr = specialgc; specialgc = 0;
		 if (restart) export(); restart = 0;}
 arend = arenabase+arenasize;
 arstart = (((arend+old_high)/2)+3)&(~3);
 (*arptr) = arstart+4;
 /* freestart is updated for the benefit of exportFn */
 freestart = (char *)arstart;
#ifdef V9
 signal(SIGSEGV, ghandle);
#endif
}

#else /* SIMPLEGC defined... */

callgc(sp,	    /* stack pointer at point of fault */
       pcptr,	    /* pc at point of fault (by ref) */
       misc_roots,  /* vector of ptrs to extra root words */
       arptr,	    /* place to put new freespace pointer */
       store_list   /* list of refs stored into */
      )
    int sp; int *pcptr; int ***misc_roots; int *arptr; int **store_list;
{int arend = arenabase+arenasize; int new_high;
 int arstart = arenabase+arenasize/2;
 if (gcmessages >= ML_INT(1)) chatting("\n[Garbage collection...");
 starttime();
 gc(sp,bottom,
    arstart,arend,
    arenabase,arstart,
    arenabase,
    &new_high,
    misc_roots,pcptr,store_list,
    getmore_die);
 moveback(sp,bottom,
	  arenabase,new_high,
	  arstart,
          misc_roots,pcptr);
 endgc(new_high-arenabase, arend-arstart, endtime());
 minorcollections+=2;
 (*arptr) = new_high+arenasize/2+4;
#ifdef V9
 signal(SIGSEGV, ghandle);
#endif
}

#endif

endgc(a,b,msec)
{
}


#ifdef GCDEBUG
clear(low,high) int *low, *high;
{int *i;
 for(i=low; i<high; i++) *i=0;
}

int *descriptor;
checkup(low,high)
int *low,*high;
{
 int *i,*j;

 chatting("checking to_space...  ");

 i = low;
 while (i < high) {
   descriptor = i;
   switch(get_tag(i)) {
        case tag_backptr:
		chatting("Uncool backpointer at %x in to_space\n",i);
		exit(0);
		break;
	case tag_embedded:
		chatting("Uncool embedded tag at %x in to_space\n",i);
		exit(0);
		break;
	case tag_string:
	case tag_bytearray:
		i += (get_len(i)+7)>>2;
		break;
	case tag_record:
	case tag_array:
	case tag_closure:
		j = i + get_len(i) + 1;
		while(++i < j) {
		 if (*i & 1) continue;
		 else if ((int*)*i > high) {
			 chatting("Uncool pointer %x at %x\n",
				  *i,i);
			 chatting("Descriptor is at %x\n",descriptor);
		      }
		}
		break;
	case tag_forwarded:
		chatting("Uncool forwarding tag at %x in to_space\n",i);
		exit(0);
		break;
	default: /* function pointers */
		chatting("Unexpected even tag %d at %x in to_space\n",
			 get_tag(i),i);
		exit(0);
		break;
	      }
 }
 chatting("done\n");
}
#endif

#include <setjmp.h>

findbreak(p) int p;
{int goal=p;
 if (!lastbreak) lastbreak=sbrk(0);
RESTART:
 p = (p + pagesize-1 ) & ~(pagesize-1);
 if (p<=lastbreak) 
	{chatting("\nWarning: tight memory\n");
	 return lastbreak;}
 else if (brk(p-4)) {p=(lastbreak+(p-pagesize))/2; goto RESTART;}
 lastbreak=p;
 if (goal>p) {p=goal; goto RESTART;}
 return lastbreak;
}


int g_sec,g_usec,t_sec,t_usec;
#ifdef BSD
#include <sys/time.h>
#include <sys/resource.h>
struct rusage r1, r2;

starttime()
{getrusage(0,&r1);}

endtime()
{
 int sec,usec;
 getrusage(0,&r2);
 sec = r2.ru_utime.tv_sec-r1.ru_utime.tv_sec;
 usec = r2.ru_utime.tv_usec-r1.ru_utime.tv_usec;
 if (usec < 0) {sec--; usec += 1000000;}
 return (usec/1000 + sec*1000);
}

struct rusage garbagetime,timestamp,s1,s2;

suspendtimers()
{
 getrusage(0,&s1);
}

restarttimers()
{
 int sec,usec;
 getrusage(0,&s2);
 sec = s2.ru_utime.tv_sec-s1.ru_utime.tv_sec+garbagetime.ru_utime.tv_sec;
 usec = s2.ru_utime.tv_usec-s1.ru_utime.tv_usec+garbagetime.ru_utime.tv_usec;
 if (usec < 0) {sec--; usec += 1000000;}
 else if (usec > 1000000) {sec++; usec -= 1000000;}
 garbagetime.ru_utime.tv_sec = sec;
 garbagetime.ru_utime.tv_usec = usec;
}

resettimers()
{
 garbagetime.ru_utime.tv_sec = 0;
 garbagetime.ru_utime.tv_usec = 0;
 s2.ru_utime.tv_sec = s1.ru_utime.tv_sec = 0;
 s2.ru_utime.tv_usec = s1.ru_utime.tv_usec = 0;
 r2.ru_utime.tv_sec = r1.ru_utime.tv_sec = 0;
 r2.ru_utime.tv_usec = r1.ru_utime.tv_usec = 0;
 collected = collectedfrom = minorcollections = majorcollections = ML_INT(0);
}

timer()
{
 getrusage(0,&timestamp);
 g_usec = garbagetime.ru_utime.tv_usec * 2 + 1;
 g_sec = garbagetime.ru_utime.tv_sec * 2 + 1;
 t_usec = timestamp.ru_utime.tv_usec * 2 + 1;
 t_sec = timestamp.ru_utime.tv_sec * 2 + 1;
}

#endif

#ifdef V9
#include <sys/times.h>
struct tms t1,t2;

starttime()
{times(&t1);}

endtime()
{
 int hzsec;
 times(&t2);
 hzsec = t2.tms_utime-t1.tms_utime;
 return(hzsec*1000/60);
}

struct tms timestamp,s1,s2;
int garbagetime;

suspendtimers()
{
 times(&s1);
}

restarttimers()
{
 times(&s2);
 garbagetime += s2.tms_utime-s1.tms_utime;
}

resettimers()
{
 garbagetime = 0;
 s2.tms_utime = s1.tms_utime = 0;
 t2.tms_utime = t1.tms_utime = 0;
 collected = collectedfrom = minorcollections = majorcollections = ML_INT(0);
}


timer()
{
 times(&timestamp);
 g_usec = garbagetime % 60 * 1000000 / 60 * 2 + 1;
 g_sec = garbagetime / 60 * 2 + 1;
 t_usec = timestamp.tms_utime % 60 * 1000000 / 60 * 2 + 1;
 t_sec = timestamp.tms_utime / 60 * 2 + 1;
}

#endif
