#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags sdl`"

echo sdlimage
./bcdgen $1/SDL_image.h sdl -C -P
