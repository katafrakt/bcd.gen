#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags vorbis`"

rm -rf bcd/vorbis

echo codec
./bcdgen $1/codec.h vorbis -C -Fbcd.ogg.ogg
echo vorbisenc
./bcdgen $1/vorbisenc.h vorbis -C -Fbcd.ogg.ogg
echo vorbisfile
./bcdgen $1/vorbisfile.h vorbis -C -Fbcd.ogg.ogg
