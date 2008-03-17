#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags sdl`"

rm -rf bcd/sdl

echo sdl
./bcdgen $1/SDL.h sdl -C -A -P
