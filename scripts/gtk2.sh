#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags gtk+-2.0`"

rm -rf bcd/gtk2

echo gtk
./bcdgen $1/gtk.h gtk2 -C -A \
  -Fbcd.atk.atk \
  -Fbcd.cairo.cairo \
  -Fbcd.pango.pango \
  -Fbcd.gdk.gdk \
  -Fbcd.glib2.glib
