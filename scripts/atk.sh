#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags atk`"

rm -rf bcd/atk

echo atk
./bcdgen $1/atk.h atk -C -A \
  -Fbcd.glib2.glib
