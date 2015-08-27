DMD=dmd

all: bcdgen

bcdgen: bcd/gen/bcdgen.d bcd/gen/kxml.d
	$(DMD) -g bcd/gen/bcdgen.d bcd/gen/kxml.d -ofbcdgen
