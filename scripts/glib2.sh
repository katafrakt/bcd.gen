#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags glib-2.0`"

rm -rf bcd/glib2

echo glib-object
./bcdgen $1/glib-object.h glib2 -C -A
echo gmodule
./bcdgen $1/gmodule.h glib2 -C
