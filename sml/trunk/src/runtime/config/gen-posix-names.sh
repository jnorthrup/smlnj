#!/bin/sh
#
# gen-posix-names.sh
#
# COPYRIGHT (c) 1996 AT&T Research.
#
# Generate string-to-int tables for run-time POSIX values
# queried using sysconf and (f)pathconf.
#
# Usage: gen-posix-names.sh <prefix> <outfile>
#

# redefine PATH so that we get the right versions of the various tools
#
PATH=/bin:/usr/bin

CPP=${CPP:-/lib/cpp}

PFIX=$1      # prefix: _SC_ or _PC_
OUTF=$2      # name of output file

# linux uses enums for the _SC_ constants. 
# In this case, we cannot use the #ifdef check to avoid symbols
# that are not really defined in unistd.h.
case "$VERSION" in
  *linux*) USED_ENUMS=TRUE ;;
  *) USED_ENUMS="" ;;
esac

if [ "$USED_ENUMS" = "TRUE" ]; then
  INCLFILE=tmp$$
  SRCFILE=tmp$$.c
  echo "#include <unistd.h>" > $SRCFILE
  $CPP $SRCFILE > $INCLFILE
  rm -f $SRCFILE
elif [ -r "/usr/include/sys/unistd.h" ]; then
  INCLFILE=/usr/include/sys/unistd.h
elif [ -r "/usr/include/confname.h" ]; then
  INCLFILE=/usr/include/confname.h
elif [ -r "/usr/include/unistd.h" ]; then
  INCLFILE=/usr/include/unistd.h
elif [ -r "/usr/include/bsd/unistd.h" ]; then
  INCLFILE=/usr/include/bsd/unistd.h
else
  echo "gen-posix-names.sh: unable to find <unistd.h>"
  exit 1
fi

echo "/* $OUTF" >> $OUTF
echo " *"       >> $OUTF
echo " * This file is generated by gen-posix-names.sh"       >> $OUTF
echo " */"       >> $OUTF

if [ "$USED_ENUMS" = "TRUE" ]; then
  for i in `sed -n "s/.*$PFIX\([0-9A-Z_]*\).*/\1/p" $INCLFILE | sort -u`
  do
    echo "  {\"$i\",  $PFIX$i}," >> $OUTF
  done
else
  for i in `sed -n "s/.*$PFIX\([0-9A-Z_]*\).*/\1/p" $INCLFILE | sort -u`
  do
    echo "#ifdef $PFIX$i" >> $OUTF
    echo "  {\"$i\",  $PFIX$i}," >> $OUTF
    echo "#endif" >> $OUTF
  done
fi

if [ "$USED_ENUMS" = "TRUE" ]; then
  rm -f $INCLFILE
fi

exit 0
