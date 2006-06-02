#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags ogg`"

rm -rf bcd/ogg

echo ogg
./bcdgen $1/ogg.h ogg -C
