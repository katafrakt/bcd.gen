#!/bin/bash
export CFLAGS="$CFLAGS -I$1"

rm -rf bcd/freetds

for i in \
bkpublic cspublic cstypes ctpublic sqldb sqlfront sybdb syberror sybfront \
tds tds_sysdep_public tdsver
do
        echo $i
        
        ./bcdgen $1/${i}.h freetds -C -E \
          -NINTFUNCPTR
done

export CFLAGS="$CFLAGS -include $1/tds.h"

for i in tdsconvert tdssrv
do
        echo $i
        
        ./bcdgen $1/${i}.h freetds -C -E
done
