#SUN3
#MACHINE = M68
#DEFINES = -DM68 -DBSD
#CFLAGS = -g $(DEFINES) -f68881

#VAXBSD
#MACHINE = VAX
#DEFINES = -DVAX -DBSD
#CFLAGS = -g $(DEFINES)

#VAXULTRIX
#MACHINE = VAX
#DEFINES = -DVAX -DBSD -DULTRIX
#CFLAGS = -g $(DEFINES)

#VAXV9
MACHINE = VAX
DEFINES = -DVAX -DV9 -DCPS
CFLAGS = -g $(DEFINES)

# Other possible #define's:
# PROFILE:  for a run which counts allocs.
# GCDEBUG:  print extra information during garbage collection,
#	    examine the to_space after a collection for stray pointers,
#	    and check create_b and create_s for zero allocation.
# SIMPLEGC: for a simpler version of the garbage collector which does a
#           complete copy of the heap each collection rather than keeping
#           a persistent heap.
# GCPROFILE: for a run which prints out cumulative garbage collector
#	     information as it exits.

run: run.o gc.o callgc.o prim.o prof.o export.o objects.o
	cc $(CFLAGS) -o run run.o gc.o callgc.o prim.o prof.o export.o objects.o

prim.s: $(MACHINE).prim.s tags.h prof.h ml.h
	/lib/cpp $(DEFINES) $(MACHINE).prim.s > prim.s

callgc.o objects.o gc.o run.o: descriptor.h tags.h

callgc.o run.o export.o objects.o: ml.h

prof.o: prof.h

clean:
	rm -f *.o lint.out prim.s math.s

lint:
	lint $(DEFINES) run.c gc.c callgc.c prof.c export.c objects.c \
		| tee lint.out

