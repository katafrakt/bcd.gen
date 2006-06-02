#!/bin/bash
export CFLAGS="$CFLAGS `pkg-config --cflags libxml-2.0`"

rm -rf bcd/libxml2

for i in c14n catalog chvalid DOCBparser encoding entities \
globals hash HTMLparser HTMLtree list nanoftp nanohttp parser parserInternals \
pattern relaxng SAX2 SAX schemasInternals schematron threads tree uri \
xinclude xlink xmlerror xmlexports xmlIO xmlmemory xmlmodule \
xmlreader xmlregexp xmlsave xmlschemas xmlschemastypes xmlstring xmlunicode \
xmlversion xmlwriter xpath xpathInternals xpointer
do
        echo $i
        
        ./bcdgen $1/${i}.h libxml2 -C -Ilibxml/
done

echo valid
CFLAGS="$CFLAGS -include $1/parser.h" ./bcdgen $1/valid.h libxml2 -C -Ilibxml/

touch bcd/libxml2/dict.d
touch bcd/libxml2/xmlautomata.d
