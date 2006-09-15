#!/bin/bash
export CFLAGS="$CFLAGS"

rm -rf bcd/curses

echo curses
./bcdgen $1/curses.h curses -C -A
