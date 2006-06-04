#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags libglade-2.0`"

rm -rf bcd/libglade2

for i in \
glade-build glade glade-init glade-parser glade-xml
do
        echo $i
        
        ./bcdgen $1/${i}.h libglade2 -C -Iglade/ \
          -Fbcd.atk.atk \
          -Fbcd.cairo.cairo \
          -Fbcd.pango.pango \
          -Fbcd.gdk.gdk \
          -Fbcd.glib2.glib \
          -Fbcd.gtk2.gtk
done

