#!/bin/bash
export CFLAGS="$CFLAGS -I$1/.."

rm -rf bcd/cg

echo cgGL
./bcdgen $1/cgGL.h cg -C -A
