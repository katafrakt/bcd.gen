#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags cairo`"

rm -rf bcd/cairo

echo cairo
./bcdgen $1/cairo.h cairo -C -A
