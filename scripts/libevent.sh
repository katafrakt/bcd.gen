#!/bin/bash
export CFLAGS="$CFLAGS -include $1/sys/time.h -Du_char=\"unsigned char\""

rm -rf bcd/libevent

echo libevent
./bcdgen $1/event.h libevent -C
