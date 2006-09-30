#!/bin/bash
CFLAGS="-DWIN32_LEAN_AND_MEAN $CFLAGS"

rm -rf bcd/windows

echo windows
./bcdgen $1/windows.h windows -C -A
