#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags gdk-2.0`"

rm -rf bcd/gdk

echo gdk
./bcdgen $1/gdk.h gdk -C -A \
  -Fbcd.cairo.cairo \
  -Fbcd.pango.pango \
  -Fbcd.glib2.glib

echo gdkx
./bcdgen $1/gdkx.h gdk -C \
  -Fbcd.cairo.cairo \
  -Fbcd.pango.pango \
  -Fbcd.glib2.glib \
  -Fbcd.xlib.Xlib \
  -Fbcd.xlib.Xutil

