#!/bin/bash
rm -rf bcd/xlib

for i in X Xlib Xutil extensions/Xrender
do
        echo $i
        
        ./bcdgen $1/${i}.h xlib -C -IX11/
done

