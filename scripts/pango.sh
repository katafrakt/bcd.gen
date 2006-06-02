#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags pango`"

rm -rf bcd/pango

echo pango
./bcdgen $1/pango.h pango -C -A \
  -Fbcd.glib2.glib
