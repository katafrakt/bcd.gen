DMD=dmd

all: bcdgen

bcdgen: bcd/gen/bcdgen.d bcd/gen/libxml2.d
	$(DMD) -g bcd/gen/bcdgen.d bcd/gen/libxml2.d -ofbcdgen -L-lxml2
