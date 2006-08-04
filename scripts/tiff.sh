#!/bin/bash
export CFLAGS="$CFLAGS -I$1"

rm -rf bcd/tiff

for i in tiff tiffio tiffvers
do
    echo $i
    ./bcdgen $1/$i.h tiff -C
done

