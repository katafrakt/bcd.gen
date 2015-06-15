DMD=dmd

all: bcdgen

bcdgen: bcd/gen/bcdgen.d bcd/gen/libxml2.d bcd/gen/kxml.d
	$(DMD) -g bcd/gen/bcdgen.d bcd/gen/libxml2.d bcd/gen/kxml.d -ofbcdgen
