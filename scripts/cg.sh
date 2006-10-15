#!/bin/bash
export CFLAGS="$CFLAGS -I$1/.."

rm -rf bcd/cg

echo cg
./bcdgen $1/cg.h cg -C -A
