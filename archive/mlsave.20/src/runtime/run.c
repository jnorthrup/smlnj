#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <signal.h>
#include "tags.h"
#include "descriptor.h"
#include "ml.h"
#include "prof.h"
extern double atof();

extern int ghandle();

extern int runvec[];

extern int profvec[];

char *freestart;

int *c_alloc(siz) int siz;
{char *s=freestart;
 freestart+= 4*siz;
 return (int *)s;
}

int openread(s) char *s;
{int fd= -1; char *p, *q; int i;
#ifdef V9
	fd = open(s,0);
#endif
#ifdef BSD
	fd = open(s,O_RDONLY,0666);
#endif
	if (fd<0) die("cannot open %s\n",s);
  p=freestart;
  freestart += sizeof(int);
  while (i=read(fd,freestart,4096)) freestart+=i;
  q=freestart;
  while ((int)freestart & 3) freestart++;
  *(int*)p = mak_desc(q-p-sizeof(int),tag_string);
  return (int)p;
}

closure(x) int x;
{int *p = (int *)mak_obj(1,tag_closure);
 p[0] = x;
 return (int)p;
}

extern int arenasize;
extern float gamma;
extern int resettimers();
#ifdef M68
extern int math_functor;
#endif

char *pervfunc = "mo/PervFunc.mo";
char *loadername = "mo/Loader.mo";
char *mathfunc = "mo/Math.mo";
int xflag=0;
extern int gcmessages0[];
int pstruct_v;

main(argc,argv)
int argc; 
char *argv[];
{
	int perv, math, loader, *pervl, *mathl, *argrec;
	char *argname;
	char **p = argv+1;

	gcmessages0[1] = ML_INT(2);
	while (*p && **p == '-')
	  switch (p[0][1])
	    {case 'h': if (p[1])
			 {arenasize = 512*atoi(p[1]); p+=2;}
		       else die("no -h value");
		       break;
	     case 'r': if (p[1]) {gamma = atof(p[1]); p+=2;
				  if (gamma<2.1) gamma=2.1;
				 }
		       else die("no -r value");
		       break;
	     case 'g': if (p[1])
			 {gcmessages0[1] = ML_INT(atoi(p[1])); p+=2;}
		       else die("no -g value");
		       break;
	     case 'x': if (p[1])
			 {xflag=1; pervfunc = p[1]; p+=2;}
		       else die("no -x value");
		       break;
	     case 'y': if (p[1])
			 {xflag=2; pervfunc = p[1]; p+=2;}
		       else die("no -y value");
		       break;
	     case 'z': if (p[1])
			 {xflag=3; loadername = p[1]; p+=2;}
		       else die("no -z value");
		       break;
             case 't': if (p[1])
			 {mathfunc = p[1]; p+=2;}
		       else die("no -t value");
		       break;
	    }

	    if (*p) argname= *p;
	    else if (xflag==0) die("no file to execute\n");

	setupsignals();
	resettimers();
	init_gc();

#ifdef PROFILE
{int i;
 for(i=0; i<PROFSIZE; i++) profvec[i] = ML_INT(0);
}
#endif

#ifdef M68
	math = (int)&math_functor;
#else
	math = closure(openread(mathfunc)+12);
	math = apply(math,ML_UNIT);
	math = *(int*)math;
	math = apply(math,ML_NIL);
#endif
	mathl = (int *)mak_obj(2,tag_record);
	mathl[0]=math; mathl[1]=ML_NIL;
	perv = closure(openread(pervfunc)+12);
	perv = apply(perv,ML_UNIT);
	perv = *(int*)perv;
	perv = apply(perv,mathl);
	if (xflag==1) {chatting("Result is %d\n",(*(int*) perv)>>1); _exit(0);}
	perv = pstruct_v = apply(perv,runvec);
	if (xflag==2) {chatting("Result is %d\n",(*(int*) perv)>>1); _exit(0);}

	pervl = (int *)mak_obj(2,tag_record);
	pervl[0]=perv; pervl[1]=ML_NIL;

	loader = closure(openread(loadername)+12);
	loader = apply(loader,ML_UNIT);
	loader = *(int*)loader;
	loader = apply(loader,pervl);
	if (xflag==3) {chatting("Result is %d\n", (*(int*) loader)>>1); _exit(0);}
	argrec = (int *)mak_obj(1,tag_record);
	argrec[0] = mak_str(argname);
	apply(loader,argrec);
#ifdef PROFILE
	print_profile_info();
#endif
#ifdef GCPROFILE
	print_gcprof();
#endif
	exit(0);
}

extern int *mak_str_lst();
extern int restart;
int func;                  /* function to be applied; setup by exportFn in prim */
restartFn(argc,argv,envp)
int argc;
char **argv,**envp;
{int *arg;
 setupsignals();
 resettimers();
 restart = 0;
 arg = (int *)mak_obj(2,tag_record);
 arg[0] = (int)mak_str_lst(argv);
 arg[1] = (int)mak_str_lst(envp);
 apply(func,arg);
#ifdef PROFILE
	print_profile_info();
#endif
#ifdef GCPROFILE
 print_gcprof();
#endif
 exit(0);
}

make_system_errstring(exitval)
int exitval;
{char buf[100];
 sprintf(buf,"system exited with %d",exitval);
 return mak_str(buf);
}

extern int errno;
char *sys_errlist[];
make_errstring()
{char *message;
 return mak_str(sys_errlist[errno]);
}

struct exception {
	mlstring val; 
	mlstring *name;
};

uncaught(e) struct exception *e;
{int descr;

 if ((int)e->val & 1)
 chatting("Uncaught exception %.*s with %d\n",
	  (((int *)*e->name)[-1])>>width_tags,
	  e->name[0],
	  (int)e->val);
 else if (((descr=((int*)e->val)[-1])&mask_tags) == tag_string
	  || (descr&mask_tags) == tag_embedded) /* possible bug on reals */
      chatting("uncaught exception %.*s with \"%.*s\"\n",
	       (((int *)*e->name)[-1])>>width_tags,
	       e->name[0],
	       descr>>width_tags,
	       e->val);
 else chatting("uncaught exception %.*s with <unknown>\n",
	       (((int *)*e->name)[-1])>>width_tags,
	       e->name[0]);
 exit(1);
}


char dbuf[1024];

die(s, a, b, c, d, e, f)
char *s;
{
	sprintf(dbuf, s, a, b, c, d, e, f);
	write(2, dbuf, strlen(dbuf));
	abort();
}

chatting(s, a, b, c, d, e, f, g)
char *s;
{
	sprintf(dbuf, s, a, b, c, d, e, f, g);
	write(2, dbuf, strlen(dbuf));
}

/* This next define is needed by ultrix systems */
#ifndef sigmask
#define sigmask(X) (1<<((X)-1))
#endif

#ifdef M68
extern handleemt();
#endif
extern handleinterrupt(), handlefpe();
setupsignals()
{
#ifdef BSD
  struct sigvec a;
  a.sv_handler = ghandle;
  a.sv_mask = sigmask(SIGINT);
  a.sv_onstack=0;
  sigvec(SIGSEGV,&a,0);
  a.sv_handler = handleinterrupt;
  a.sv_mask = 0;
  sigvec(SIGINT,&a,0);
  a.sv_handler = handlefpe;
  sigvec(SIGFPE,&a,0);
  a.sv_handler = SIG_IGN;
  sigvec(SIGPIPE,&a,0);
#ifdef M68
  a.sv_handler = handleemt; /* in case 68881 is not present */
  sigvec(SIGEMT,&a,0);
#endif
#endif
#ifdef V9
  signal(SIGSEGV,ghandle);
  signal(SIGINT,handleinterrupt);
  signal(SIGFPE,handlefpe);
  signal(SIGPIPE,SIG_IGN);
#endif
}


