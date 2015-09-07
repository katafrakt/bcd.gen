# bcd.gen

**Current status:** does not work ;)

This repository contains a modified version of [original bcd.gen](http://www.dsource.org/projects/bcd). It's supposed to generate C or C++ bindings from .h files. Generated C++ bindings replicate the API of the underlying C++ code, but have a C layer as a gobetween, and therefore require both a D compiler and a C++ compiler. Generated C bindings are simply extern (C)'s and structs, and therefore only require a D compiler.

## What's changed

First of all, it works with D2. Second, it uses [kxml](http://code.dlang.org/packages/kxml) instead of `libxml` (I had hard time using libxml to work, it segfaulted etc. Probably bindings included in original bcd were incompatible with my libxml version).

## TODO

* Windows Makefile
* Test C++ generation (only needed C)
* ...

## Compilation

Clone the project, go into it's directory and type `make`.

## Usage

Any variables in CXXFLAGS (or CFLAGS for generating C bindings) will be picked up by gccxml in the bcd.gen process. So, you will probably need to add the flags for your tool to the environment variable. In bash, for example, you can do that like so:

```
export CXXFLAGS="$CXXFLAGS `some-config --cxxflags`"
```

To create a binding, do:

```
./bcdgen <header file> <D namespace> [-C] [-A] [-I<include prefix>] [other options]
```

The D namespace is under `bcd.`, so if you use the namespace `fltk2`, for example, the D interfaces will be in `bcd.fltk2.*`.

`-C` puts bcd.gen in C mode instead of C++ mode.

`-A` causes bcd.gen to output all symbols, not just those in the header file specified, which is most useful for metaheaders which `#include` a number of other ones.

`-I` changes the `#include` line in the output C++ file (if you're using C++) to put the specified prefix before the filename.

Note that the generated bindings rarely work immediately, but will require some minor tweaking. Most notably:

* If the header uses structs that are never actually defined, you will need to add the definition. If it only uses pointers, you can add an empty stub definition.
* If the header uses struct timeval, you'll have to import std.socket
* If you use `-A`, it may generate unnecessary import lines which will need to be removed
