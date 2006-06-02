DMD=dmd

all: bcdgen

bcdgen: bcd/gen/bcdgen.d bcd/gen/libxml2.d
	$(DMD) -g bcd/gen/bcdgen.d bcd/gen/libxml2.d -ofbcdgen -L-lxml2

fltk2exa: test/fltk2.d bcd/bind.d
	sh test/fltk2.sh ${DMD}

libxml2exa: test/libxml2.d
	sh test/libxml2.sh ${DMD}

vorbisexa: test/vorbis.d
	sh test/vorbis.sh ${DMD}

gtk2exa: test/gtk2.d
	sh test/gtk2.sh ${DMD}
