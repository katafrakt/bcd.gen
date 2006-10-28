#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags cairo`"

rm -rf bcd/cairo

echo cairo
./bcdgen $1/cairo.h cairo -C -A
echo cairo-xlib
./bcdgen $1/cairo-xlib.h cairo -C
echo cairo-xlib-xrender
./bcdgen $1/cairo-xlib-xrender.h cairo -C
