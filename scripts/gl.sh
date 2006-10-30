#!/bin/bash
rm -rf bcd/gl

echo gl
./bcdgen $1/gl.h gl -C -A

echo glx
./bcdgen $1/glx.h gl -C \
  -Fbcd.gl.gl \
  -Fbcd.xlib.Xutil

