#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags pango` `pkg-config --cflags pangocairo`"

rm -rf bcd/pango

echo pango
./bcdgen $1/pango.h pango -C -A \
  -Fbcd.glib2.glib

echo pangocairo
./bcdgen $1/pangocairo.h pango -C \
  -Fbcd.glib2.glib \
  -Fbcd.cairo.cairo

