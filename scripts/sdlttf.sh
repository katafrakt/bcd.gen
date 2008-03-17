#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags sdl`"

echo sdlttf
./bcdgen $1/SDL_ttf.h sdl -C -P
