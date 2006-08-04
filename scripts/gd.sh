#!/bin/bash
export CFLAGS="$CFLAGS -I$1"

rm -rf bcd/gd2

for i in gd gdcache gdfontg gdfontl gdfontmb gdfonts gdfontt
do
    echo $i
    ./bcdgen $1/$i.h gd2 -C -A
done

