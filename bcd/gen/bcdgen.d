/**
 * Generate bindings for C[++] in D
 *
 * Authors:
 *  Gregor Richards
 *  Tomas "MrSunshine" Wilhelmsson
 *
 * License:
 *  Copyright (C) 2006, 2007  Gregor Richards
 *  Copyright (C) 2006  Tomas "MrSunshine" Wilhelmsson
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

module bcd.gen.bcdgen;

version (Windows) {
    import common.path;
} else {
    import std.path;
}

import std.file;
import std.process;
import std.stdio;
import std.stream;
import std.string;
import std.conv;
import kxml.xml;

import std.c.stdlib;
alias std.c.stdlib.free free;
alias std.process.system system;

private import bcd.gen.libxml2;

extern (C) char* getenv(immutable(char)*);

// some global variables (yay)
private {
/** The full path to the current file */
char[] curFile;
/** The include prefix */
char[] incPrefix;
/** The base directory of .h files */
char[] baseDir;
/** The short name of the current .h file (no basename, no .h) */
char[] shortName;
/** The D namespace */
char[] dNamespace;
/** The C++ functions/variables to explicitly ignore */
char[][] ignoreSyms;
}
/** The D output */
string dhead;
string dtail;
/** The C[++] output */
string cout;
private {
/** The base of the D namespace */
string dNamespaceBase;
/** The class currently being processed */
string curClass;
/** Is the current class abstract? */
bool curClassAbstract;
/** Was a constructor made for the current class? */
bool hasConstructor;
/** Was an accessable constructor made for the current class? */
bool hasPublicConstructor;
/** Should we output C instead of C++ */
bool outputC;
/** Should we output symbols provided by any header in the dir? */
bool outputAll;
/** Should we generate default values? */
bool defaultValues = false;
/** Should we generate consts for enums? */
bool outputEnumConst;
/** Should we output reflections? */
bool outputReflections;
/** Other BCD requirements */
bool polluteNamespace = false;
char[][char[]] reqDependencies;
/** The root to the XML tree */
XmlNode gccxml = null;

/** Class currently being reflected into D */
string curReflection;
/** The base of the class currently being reflected (in C++) */
string curReflectionCBase;
/** The base of the class currently being reflected (in D) */
string curReflectionDBase;
/** The initializer for the current reflection */
string curReflectionInit;
/** The C++ code for the class currently being reflected */
string reflectionCode;
/** The C++ code to go after we close the class */
string reflectionPostCode;
/** The functions that have already been reflected */
bool[char[]] reflectedFunctions;

char[][char[]] files;
}


int main(char[][] args)
{
    // figure out what gccxml to use based on the system
    string gccxmlExe;
    version (Windows) {
        char[] dir, bname;
        whereAmI(args[0], dir, bname);
        gccxmlExe = dir ~ "\\gccxml\\gccxml_flags.exe";
    } else {
        gccxmlExe = "gccxml";
    }

    if (args.length < 3) {
        writefln("Use:");
        writefln("bcdgen <.h file> <D namespace> [options]");
        writefln("Options:");
        writefln("  -I<include prefix>");
        writefln("  -C");
        writefln("    Read/write C instead of C++");
        writefln("  -A");
        writefln("    Include all symbols provided by headers in the same");
        writefln("    directory as the provided one, regardless of whether");
        writefln("    they are actually provded by the included file.");
        writefln("  -F<forced import>");
        writefln("  -R<include directory>=<BCD/D namespace>");
        writefln("    Depend upon other BCD namespaces.");
        writefln("  -r");
        writefln("    Reflect C++ classes such that D classes can derive from");
        writefln("    them.");
        writefln("  -E");
        writefln("    Generate const int's for unnamed enum values");
        writefln("  -T<template class>[=<count>]");
        writefln("    Make the given template class accessable from D.  If the");
        writefln("    class has more than one template parameter, also provide");
        writefln("    the count.");
        writefln("  -N<symbol to ignore>");
        writefln("  -P");
        writefln("    Pollute namespaces (make named enum values public)");
        writefln("  -b");
        writefln("    Do not prepend 'bcd.' to the D namespace.");
        writefln("  -DV");
        writefln("    Generate default values for function arguments.");
        return 1;
    }

    char[] forcedImport;
    char[] templates;

    // set the globals
    dNamespaceBase = "bcd.";
    curFile = args[1];
    version (Windows) {
        // get*Name only works with \, but gccxml only works with /
        curFile = replace(curFile, "\\", "/");
        char[] backslashName = replace(args[1], "/", "\\");
        baseDir = replace(dirName(backslashName), "\\", "/");
        shortName = baseName(backslashName);
    } else {
        baseDir = dirName(args[1]);
        shortName = baseName(args[1]);
    }
    if (indexOf(shortName, '.') != -1) {
        shortName = stripExtension(shortName);
    }
    shortName = to!(char[])(safeName(shortName));

    // parse other options
    for (int i = 3; i < args.length; i++) {
        if (args[i][0..2] == "-I") {
            incPrefix = args[i][2..args[i].length];

        } else if (args[i][0..2] == "-N") {
            ignoreSyms ~= args[i][2..args[i].length];

        } else if (args[i] == "-C") {
            outputC = true;

        } else if (args[i][0..2] == "-R") {
            char[] req = args[i][2..args[i].length];
            auto eqloc = indexOf(req, '=');
            if (eqloc == -1) {
                writefln("Argument %s not recognized.", args[i]);
                continue;
            }
            reqDependencies[cast(string)req[0..eqloc]] = req[eqloc + 1 .. req.length];

        } else if (args[i] == "-A") {
            outputAll = true;

        } else if (args[i][0..2] == "-F") {
            forcedImport ~= "public import " ~ args[i][2..args[i].length] ~ ";\n";

        } else if (args[i][0..2] == "-T") {
            char[] temp = args[i][2..args[i].length];
            long count = 1, eqloc;

            eqloc = indexOf(temp, '=');
            if (eqloc != -1) {
                count = to!int(temp[eqloc + 1 .. temp.length]);
                temp = temp[0..eqloc];
            }

            templates ~= temp ~ "<DReflectedClass";

            for (int j = 1; i < count; i++)
                templates ~= ", DReflectedClass";

            templates ~= "> __IGNORE_" ~ temp ~ ";\n";
        } else if (args[i] == "-P") {
            polluteNamespace = true;
        } else if (args[i] == "-E") {
            outputEnumConst = true;

        } else if (args[i] == "-r") {
            outputReflections = true;

        } else if (args[i] == "-b") {
            dNamespaceBase = "";
        } else if (args[i] == "-DV") {
            defaultValues = true;
        } else {
            writefln("Argument %s not recognized.", args[i]);
        }
    }

    // the header to attach to all generated files
    auto genhead = "/* THIS FILE GENERATED BY bcd.gen */\n";

    dNamespace = args[2];

    // some buffers
    dhead = genhead; // the D header (extern (C)'s)
    dhead ~= "module " ~ dNamespaceBase ~ dNamespace ~ "." ~ shortName ~ ";\nalign(4):\n";
    if (!outputC) dhead ~= "public import bcd.bind;\n";
    dhead ~= forcedImport;

    cout = genhead; // the C++ output (to name.cc)
    cout ~= "#include <stdlib.h>\n";
    cout ~= "#include <string.h>\n";
    cout ~= "#include \"../bind.h\"\n";
    cout ~= "#include \"" ~ incPrefix ~ baseName(args[1]) ~ "\"\n";
    if (!outputC) cout ~= "extern \"C\" {\n";

    // make the directories
    try {
        mkdir("bcd");
    } catch (FileException e) {} // ignore errors
    try {
        mkdir("bcd/" ~ dNamespace);
    } catch (FileException e) {} // ignore errors

    // make the template file if requested
    if (templates != "") {
        std.file.write("bcd/" ~ dNamespace ~ "/template_D.h",
              "#include \"../bind.h\"\n" ~
              "#include \"" ~ incPrefix ~ baseName(args[1]) ~ "\"\n" ~
              templates);
        templates = "-include bcd/" ~ dNamespace ~ "/template_D.h ";
    }

    // gccxml options
    char[] gccxmlopts = templates ~
    to!string(getenv(toStringz(outputC ? "CFLAGS" : "CXXFLAGS")));

    // preprocess it
    auto command = gccxmlExe ~ " -E -dD " ~ gccxmlopts ~ args[1] ~ " > out.i";
    auto result = executeShell(command);
    if (result.status) {
        if(result.status == 127) {
            writeln("No gccxml found!");
        } else {
            writeln("Command: " ~ command ~ " failed");
        }
        return 2;
    }

    parse_Defines();

    // xml-ize it
    result = executeShell(gccxmlExe ~ " " ~ gccxmlopts ~
               " -fxml=out.xml " ~ args[1]);
    if (result.status) {
        return 2;
    }

    XmlNode doc = null;
    XmlNode *rootElement = null;

    xmlCheckVersion(20621); // the version bcdgen's XML was ported from

    // and read it in
    doc = readDocument(readText("out.xml"));

    if (doc is null) {
        writefln("Failed to parse the GCCXML-produced XML file!");
        return 3;
    }

    // Get the root element node
    gccxml = doc.parseXPath("//GCC_XML")[0];

    parse_GCC_XML();

    xmlCleanupParser();

    if (!outputC) cout ~= "}\n";

    // write out the files
    std.file.write("bcd/" ~ dNamespace ~ "/" ~ shortName ~ ".d",
          dhead ~ dtail);
    if (!outputC) {
        std.file.write("bcd/" ~ dNamespace ~ "/" ~ shortName ~ ".cc",
              cout);
    }

    // get rid of the files we no longer need
    if (templates != "") {
        std.file.remove("bcd/" ~ dNamespace ~ "/template_D.h");
    }
    //std.file.remove("out.i");
    //std.file.remove("out.xml");

    return 0;
}

/**
 * Is this numeric?
 */
bool isNumeric(char[] str)
{
    bool hase, hasdot, ishex;

    for (int i = 0; i < str.length; i++) {
        char c = str[i];
        if (c >= '0' && c <= '9') continue;
        if (ishex &&
            ((c >= 'a' && c <= 'f') ||
             (c >= 'A' && c <= 'F'))) continue;


        if (c == 'e' || c == 'E') {
            if (hase) return false;
            hase = true;
        } else if (c == 'x' || c == 'X') {
            ishex = true;
            if (i != 1) return false;
            if (str[0] != '0') return false;
        } else if (c == '-') {
            if (i != 0) return false;
        } else if (c == '.') {
            if (hasdot) return false;
            hasdot = true;
        } else if (c == 'L') {
            if (i != str.length - 1) return false;
        } else {
            return false;
        }
    }

    return true;
}

string safeName(string name) {
    return safeName(to!(char[])(name));
}
/**
 * Return a name that doesn't stomp on any D keywords
 */
string safeName(char[] name)
{
    string ret = to!string(name[0..name.length]);
    if (name == "alias" ||
        name == "align" ||
        name == "body" ||
        name == "debug" ||
        name == "final" ||
        name == "function" ||
        name == "in" ||
        name == "int" ||
        name == "inout" ||
        name == "long" ||
        name == "module" ||
        name == "out" ||
        name == "override" ||
        name == "package" ||
        name == "scope" ||
        name == "short" ||
        name == "uint" ||
        name == "ulong" ||
        name == "ushort" ||
        name == "version" ||
        name == "with") {
        ret ~= "_";
    }

    ret = replace(ret, ".", "_");
    ret = replace(ret, "-", "_");

    // drop any template info
    auto tloc = indexOf(ret, '<');
    if (tloc != -1) {
        ret = ret[0..tloc] ~ "_D";
    }

    return ret;
}

auto stringToPtr(string str) {
    return (to!(char[])(str)).ptr;
}

/**
 * Return name unless it's anonymous, in which case return mangled
 */
string getNName(XmlNode node)
{
    auto name = node.getAttribute("name");
    if (name == "") name = node.getAttribute("mangled");
    if (name == "") {
        auto id = node.getAttribute("id");
        if (id != "")
            name = "_BCD_" ~ id;
    }
    return name;
}

/**
 * Convert a char * to a char[] and free it
 */
char[] toStringFree(char* from)
{
    char[] ret;
    ret ~= to!string(from);
    free(from);
    return ret;
}

/**
 * Return mangled unless it's not mangled
 */
auto getMangled(XmlNode node)
{
    auto mangled = node.getAttribute("mangled");
    if (!mangled && outputC) mangled = node.getAttribute("name");
    return mangled;
}

/**
 * Return demangled unless it's not mangled
 */
auto getDemangled(XmlNode node)
{
    auto demangled = node.getAttribute("demangled");
    if (!demangled && outputC) demangled = node.getAttribute("name");
    return demangled;
}

/**
 * Do we need to parse this node?
 */
bool parseThis(XmlNode node, bool allowNameless = false)
{
    // only parse it if it's in the file we're parsing and it's demanglable
    auto file = node.getAttribute("file");
    auto demangled = getDemangled(node);
    auto incomplete = node.getAttribute("incomplete");
    //if (incomplete) free(incomplete);

    if (file && (demangled || allowNameless) && !incomplete) {
        //char[] sfile = toStringFree(file);
        //char[] sdemangled = toStringFree(demangled);

        // if it's not in a file we should be parsing, don't output it
        if (outputAll) {
            if (files[file].length <= baseDir.length ||
                !globMatch(files[file][0..baseDir.length], baseDir)) return false;
        } else {
            if (files[file] != curFile) return false;
        }

        // if it's builtin, don't do it
        auto name = node.getAttribute("name");
        if (name) {
            if (name.length >= 9 &&
                name[0..9] == "__builtin") {
                return false;
            }
        }

        // if access is private, don't do it
        auto access = node.getAttribute("access");
        if (access && access != "public") {
            return false;
        }

        // if we were told to ignore it, do so
        if (demangled.length >= 8 &&
            demangled[0..8] == "__IGNORE") return false;
        foreach (i; ignoreSyms) {
            if (demangled == i) {
                return false;
            }
        }

        return true;
    } else {
        return false;
    }
}

/**
 * Parse the members of a node
 */
void parseMembers(XmlNode node, bool inclass, bool types, bool reflection = false)
{
    auto members = node.getAttribute("members");
    if (!members) return;

    string[] memberList = split(members);

    // parse each member in the memberList
    foreach (m; memberList) {
        parse_GCC_XML_for(m, inclass, types, reflection);
    }
}

/**
 * Parse a GCC_XML node
 */
void parse_GCC_XML()
{
    int xmlrret;

    // first parse for files and fundamental types
    foreach (XmlNode curNode; gccxml.getChildren()) {
        if (curNode.isCData() || curNode.isXmlComment() || curNode.isXmlPI())
            continue;

        auto nname = curNode.getName();
        //writefln("  %s", nname);

        if (nname == "File") {
            parse_File(curNode);
        }
    }

    // then parse for namespaces, typedefs, enums (all of which can be top-level)
    foreach (XmlNode curNode; gccxml.getChildren()) {
        if (curNode.isCData() || curNode.isXmlComment() || curNode.isXmlPI())
            continue;

        auto nname = curNode.getName();

        if (nname == "Namespace") {
            parse_Namespace(curNode);
        } else if (nname == "Typedef") {
            parse_Typedef(curNode);
        } else if (nname == "Enumeration") {
            parse_Enumeration(curNode);
        } else if (nname == "Class") {
            // special case for template classes
            auto sname = curNode.getAttribute("name");
            if (indexOf (sname, "<DReflectedClass>") != -1) {
                parse_Class(curNode);
            }
        }
    }
}

/**
 * Parse a GCC_XML node for a specified ID
 */
void parse_GCC_XML_for(string parseFor, bool inclass, bool types, bool reflection = false)
{
    int xmlrret;

    foreach (XmlNode curNode; gccxml.getChildren()) {
        if (curNode.isCData() || curNode.isXmlComment())
            continue;

        auto nname = curNode.getName();

        auto id = curNode.getAttribute("id");
        if (parseFor != id) continue;

        if (nname == "Constructor") {
            // this may be private or otherwise unparsable, but we do have one
            hasConstructor = true;
        }

        // types that can be nameless:
        if (!parseThis(curNode, true)) continue;

        if (nname == "Struct" || nname == "Class") {
            // structs and classes are the same in C[++]
            if (outputC) {
                if (types) parse_Struct(curNode);
            } else {
                if (types) parse_Class(curNode);
            }
            continue;
        } else if (nname == "Union") {
            if (types) parse_Struct(curNode);
            continue;
        }

        // types that cannot be nameless:
        if (!parseThis(curNode)) continue;

        writefln("::  %s", nname);

        if (nname == "Variable" || nname == "Field") {
            if (!types && !reflection) parse_Variable(curNode, inclass);
        } else if (nname == "Method") {
            if (!types) parse_Method(curNode, reflection);
        } else if (nname == "OperatorMethod") {
            if (!types) parse_OperatorMethod(curNode, reflection);
        } else if (nname == "Function") {
            if (!types && !reflection) parse_Function(curNode);
        } else if (nname == "Constructor") {
            if (!types) parse_Constructor(curNode, reflection);
        } else if (nname == "Destructor") {
            // this code is automatic :)
        } else if (nname == "Typedef") {
            if (types && !reflection) parse_Typedef(curNode);
        } else if (nname == "Enumeration") {
            if (types && !reflection) parse_Enumeration(curNode);
        } else {
            writefln("I don't know how to parse %s!", nname);
        }
    }
}

/**
 * Parse a File node
 */
void parse_File(XmlNode node)
{
    auto id = node.getAttribute("id");
    auto name = node.getAttribute("name");
    if (id && name) {
        auto sname = to!(char[])(name);

        files[id] = sname;

        // import it in D

        // first try our own namespace if we didn't use -A
        if (!outputAll && dirName(sname) == baseDir) {
            char[] baseName = sname[baseDir.length + 1 .. sname.length];
            if (indexOf(baseName, '.') != -1) {
                baseName = stripExtension(baseName);
            }

            if (baseName != shortName)
                dhead ~= "public import " ~ dNamespaceBase ~ dNamespace ~ "." ~ safeName(baseName) ~ ";\n";
        }

        // then others
        foreach (req; reqDependencies.keys) {
            if (dirName(sname) == req) {
                string baseName = name[req.length + 1 .. sname.length];
                if (indexOf(baseName, '.') != -1) {
                    baseName = stripExtension(baseName);
                }

                baseName = safeName(baseName);

                if (baseName != shortName)
                    dhead ~= "public import " ~ dNamespaceBase ~ reqDependencies[req] ~ "." ~ safeName(baseName) ~ ";\n";
            }
        }
    }
}

/**
 * Parse a Namespace node
 */
void parse_Namespace(XmlNode node)
{
    parseMembers(node, false, true);
    parseMembers(node, false, false);
}

/**
 * Parse a Class or Struct node to C++
 */
void parse_Class(XmlNode node)
{
    auto name = getNName(node);
    auto mangled = getMangled(node);
    auto demangled = getDemangled(node);
    auto prevCurClass = curClass;
    auto isabstract = node.getAttribute("abstract");

    curClass = demangled;
    curClassAbstract = isabstract ? true : false;
    hasConstructor = false;
    hasPublicConstructor = false;

    parseMembers(node, true, true);

    // parse for base classes
    auto base = "bcd.bind.BoundClass";

    foreach (XmlNode curNode; node.getChildren()) {
        if (curNode.getName() == "Base") {
            ParsedType pt = parseType(curNode.getAttribute("type"));
            base = to!string(pt.DType);
            break;
        }
    }

    // if this is derived from a template, the derivation is worthless from D
    if (indexOf(base, '<') != -1) base = "bcd.bind.BoundClass";

    dtail ~= "class " ~ safeName(name) ~ " : " ~ base ~ " {\n";

    dtail ~= "this(ifloat ignore) {\n";
    dtail ~= "super(ignore);\n";
    dtail ~= "}\n";

    dtail ~= "this(ifloat ignore, void *x) {\n";
    dtail ~= "super(ignore);\n";
    dtail ~= "__C_data = x;\n";
    dtail ~= "__C_data_owned = false;\n";
    dtail ~= "}\n";

    cout ~= "void _BCD_delete_" ~ mangled ~ "(" ~ demangled ~ " *This) {\n";
    cout ~= "delete This;\n";
    cout ~= "}\n";

    dhead ~= "extern (C) void _BCD_delete_" ~ mangled ~ "(void *);\n";

    dtail ~= "~this() {\n";
    dtail ~= "if (__C_data && __C_data_owned) _BCD_delete_" ~ mangled ~ "(__C_data);\n";
    dtail ~= "__C_data = null;\n";
    dtail ~= "}\n";

    parseMembers(node, true, false);

    // if the constructor is implicit, replicate it here
    if (!hasConstructor && !isabstract) {
        dhead ~= "extern (C) void *_BCD_new_" ~ mangled ~ "();\n";
        dtail ~= "this() {\n";
        dtail ~= "super(cast(ifloat) 0);\n";
        dtail ~= "__C_data = _BCD_new_" ~ mangled ~ "();\n";
        dtail ~= "__C_data_owned = true;\n";
        dtail ~= "}\n";
        cout ~= curClass ~ " *_BCD_new_" ~ mangled ~ "() {\n";
        cout ~= "return new " ~ curClass ~ "();\n";
        cout ~= "}\n";
    }

    dtail ~= "}\n";

    // now make the reflected class
    curClass = prevCurClass;
    if (!outputReflections) return;
    if (isabstract) return; // not for abstract classes yet
    curClass = demangled;
    curReflectionCBase = demangled;
    curReflectionDBase = safeName(name);
    curReflection = curReflectionDBase ~ "_R";
    curReflectionInit = "_BCD_RI_" ~ mangled;

    dhead ~= "extern (C) void " ~ curReflectionInit ~ "(void *cd, void *dd);\n";

    dtail ~= "class " ~ curReflection ~ " : " ~ curReflectionDBase ~ " {\n";

    dhead ~= "extern (C) void _BCD_delete_" ~ mangled ~ "__" ~ curReflection ~ "(void *This);\n";

    dtail ~= "~this() {\n";
    dtail ~= "if (__C_data && __C_data_owned) _BCD_delete_" ~ mangled ~ "__" ~ curReflection ~ "(__C_data);\n";
    dtail ~= "__C_data = null;\n";
    dtail ~= "}\n";

    reflectionPostCode = "";

    reflectionCode = "}\n"; // close the extern "C"
    reflectionCode ~= "class " ~ curReflection ~ " : " ~ curReflectionCBase ~ " {\n";
    reflectionCode ~= "public:\n";
    reflectionCode ~= "void *__D_data;\n";

    hasConstructor = false;
    hasPublicConstructor = false;
    parseBaseReflections(node);

    reflectionCode ~= "};\n";
    reflectionCode ~= "extern \"C\" {\n";

    cout ~= reflectionCode ~ reflectionPostCode;

    reflectionCode = "";
    reflectedFunctions = null;

    cout ~= "void _BCD_delete_" ~ mangled ~ "__" ~ curReflection ~ "(" ~ curReflection ~ " *This) {\n";
    cout ~= "delete This;\n";
    cout ~= "}\n";

    // if the constructor is implicit, make it here
    if (!hasConstructor) {
        dhead ~= "extern (C) void *_BCD_new_" ~ mangled ~ "__" ~ curReflection ~ "();\n";
        dtail ~= "this() {\n";
        dtail ~= "super(cast(ifloat) 0);\n";
        dtail ~= "__C_data = _BCD_new_" ~ mangled ~ "__" ~ curReflection ~ "();\n";
        dtail ~= "__C_data_owned = true;\n";
        dtail ~= "}\n";
        cout ~= curReflection ~ " *_BCD_new_" ~ mangled ~ "__" ~ curReflection ~ "() {\n";
        cout ~= "return new " ~ curReflection ~ "();\n";
        cout ~= "}\n";
    } else if (!hasPublicConstructor) {
        dtail ~= "this() { super(cast(ireal) 0); }\n";
    }

    dtail ~= "}\n";

    // then make the initializer
    cout ~= "void _BCD_RI_" ~ mangled ~ "(" ~ curReflection ~ " *cd, void *dd) {\n";
    cout ~= "cd->__D_data = dd;\n";
    cout ~= "}\n";

    curClass = prevCurClass;
}

/**
 * Recursively and reflectively parse a class' bases
 */
void parseBaseReflections(XmlNode node)
{
    foreach (XmlNode curNode; node.getChildren()) {
        if (curNode.getName() == "Base") {

            // find the base class
            auto type = curNode.getAttribute("type");
            
            foreach (XmlNode curBCNode; gccxml.getChildren()) {
                if (type == curBCNode.getAttribute("id")) {
                    // parse this one too
                    parseBaseReflections(curBCNode);
                }
            }

        }
    }

    // then parse this level
    parseMembers(node, true, false, true);
}

/**
 * Parse a Struct or Union node to C
 */
void parse_Struct(XmlNode node)
{
    char[] type = to!(char[])(node.getAttribute("name"));
    auto name = getNName(node);
    auto mangled = getMangled(node);
    auto demangled = getDemangled(node);
    auto prevCurClass = curClass;

    parseMembers(node, true, true);

    if (type == "Union") {
        dtail ~= "union ";
    } else {
        dtail ~= "struct ";
    }
    dtail ~= safeName(name) ~ " {\n";

    curClass = demangled;

    parseMembers(node, true, false);
    dtail ~= "}\n";

    curClass = prevCurClass;
}

/**
 * Parse a Variable or Field node
 */
void parse_Variable(XmlNode node, bool inclass)
{
    auto stype = node.getAttribute("type");
    ParsedType type;
    auto name = getNName(node);
    auto mangled = getMangled(node);

    if (outputC) {
        type = parseType(stype);
        if (!inclass) {
            dtail ~= "extern (C) extern ";
        }
        dtail ~= type.DType ~ " " ~ safeName(name) ~ ";\n";
    } else {
        type = parseTypeReturnable(stype);
        if (inclass) {
            // if it's a const, don't make the set
            if (stype[stype.length - 1] != 'c') {
                dhead ~= "extern (C) void _BCD_set_" ~ mangled ~ "(void *, " ~ type.DType ~ ");\n";

                dtail ~= "void set_" ~ safeName(name) ~ "(" ~ type.DType ~ " x) {\n";
                dtail ~= "_BCD_set_" ~ mangled ~ "(__C_data, x);\n";
                dtail ~= "}\n";

                cout ~= "void _BCD_set_" ~ mangled ~ "(" ~ curClass ~ " *This, " ~ type.CType ~ " x) {\n";
                if (!type.isClass) {
                    cout ~= "This->" ~ name ~ " = x;\n";
                } else {
                    cout ~= "memcpy(&This->" ~ name ~ ", x, sizeof(" ~ type.className ~ "));\n";
                }
                cout ~= "}\n";
            }

            dhead ~= "extern (C) " ~ type.DType ~ " _BCD_get_" ~ mangled ~ "(void *);\n";

            dtail ~= type.DType ~ " get_" ~ safeName(name) ~ "() {\n";
            dtail ~= "return _BCD_get_" ~ mangled ~ "(__C_data);\n";
            dtail ~= "}\n";

            cout ~= type.CType ~ " _BCD_get_" ~ mangled ~ "(" ~ curClass ~ " *This) {\n";
            cout ~= "return ";
            if (type.isClass) cout ~= "&";
            cout ~= "This->" ~ name ~ ";\n";
            cout ~= "}\n";
        } else {
            auto demangled = getDemangled(node);

            // if it's a const, don't make the set
            if (stype[stype.length - 1] != 'c') {
                dhead ~= "extern (C) void _BCD_set_" ~ mangled ~ "(" ~ type.DType ~ ");\n";

                dtail ~= "void set_" ~ safeName(name) ~ "(" ~ type.DType ~ " x) {\n";
                dtail ~= "_BCD_set_" ~ mangled ~ "(x);\n";
                dtail ~= "}\n";

                cout ~= "void _BCD_set_" ~ mangled ~ "(" ~ type.CType ~ " x) {\n";
                if (!type.isClass) {
                    cout ~= demangled ~ " = x;\n";
                } else {
                    cout ~= "memcpy(&" ~ demangled ~ ", x, sizeof(" ~ type.className ~ "));\n";
                }
                cout ~= "}\n";
            }

            dhead ~= "extern (C) " ~ type.DType ~ " _BCD_get_" ~ mangled ~ "();\n";

            dtail ~= type.DType ~ " get_" ~ safeName(name) ~ "() {\n";
            dtail ~= "return _BCD_get_" ~ mangled ~ "();\n";
            dtail ~= "}\n";

            cout ~= type.CType ~ " _BCD_get_" ~ mangled ~ "() {\n";
            cout ~= "return ";
            if (type.isClass) cout ~= "&";
            cout ~= demangled ~ ";\n";
            cout ~= "}\n";
        }
    }
}

/**
 * Parse Argument nodes
 */
void parse_Arguments(XmlNode node, char[] Dargs, char[] Deargs,
                     char[] Cargs, char[] Dcall,
                     char[] Ccall, bool reflection = false,
                     int *argc = null)
{
    int onParam = 0;

    foreach (XmlNode curNode; node.getChildren()) {
        auto nname = curNode.getName();
        auto def = curNode.getAttribute("default");

        if(def == "NULL")
            def = "null";

        if (nname == "Argument") {
            ParsedType atype = parseType(curNode.getAttribute("type"));
            auto aname = getNName(curNode);
            if (aname == "") aname = to!(char[])("_" ~ to!string(onParam));
            aname = safeName(aname);

            if(def == "0" &&
               (indexOf(atype.DType, "*") != -1 ||
                atype.isFunctionPtr))
                def = "null";

            if (Dargs != "") {
                Dargs ~= ", ";
            }

            if (!reflection || (!atype.isClass && !atype.isClassPtr)) {
                if(def != "" && defaultValues)
                    Dargs ~= atype.DType ~ " " ~ aname ~ " = " ~ def;
                else
                    Dargs ~= atype.DType ~ " " ~ aname;
            } else {
                Dargs ~= "void *" ~ aname;
            }

            if (!reflection && (atype.isClass || atype.isClassPtr)) {
                // this becomes a void * in D's view
                if (Deargs != "") {
                    Deargs ~= ", ";
                }
                Deargs ~= "void *";
            } else {
                if (Deargs != "") {
                    Deargs ~= ", ";
                }
                Deargs ~= atype.DType;
            }

            if (Cargs != "") {
                Cargs ~= ", ";
            }
            Cargs ~= atype.CType ~ " " ~ aname;

            if (Dcall != "") {
                Dcall ~= ", ";
            }
            if (!reflection) {
                Dcall ~= aname;
                if (atype.isClass || atype.isClassPtr) {
                    // turn this into the real info
                    Dcall ~= ".__C_data";
                }
            } else {
                if (atype.isClass) {
                    Dcall ~= "new " ~ atype.className ~ "(cast(ifloat) 0, " ~ aname ~ ")";
                } else if (atype.isClassPtr) {
                    Dcall ~= "cast(" ~ atype.DType ~ ") new " ~ replace(atype.DType, " *", "") ~ "(cast(ifloat) 0, " ~ aname ~ ")";
                } else {
                    Dcall ~= aname;
                }
            }

            if (atype.isClass) {
                // need to dereference
                if (Ccall != "") {
                    Ccall ~= ", ";
                }
                if (!reflection) {
                    Ccall ~= "*" ~ aname;
                } else {
                    Ccall ~= "&" ~ aname;
                }
            } else {
                if (Ccall != "") {
                    Ccall ~= ", ";
                }
                Ccall ~= aname;
            }

            if (argc) (*argc)++;

        } else if (outputC && nname == "Ellipsis") {
            if (Dargs != "") {
                Dargs ~= ", ";
            }
            Dargs ~= "...";

            if (Deargs != "") {
                Deargs ~= ", ";
            }
            Deargs ~= "...";

            if (Cargs != "") {
                Cargs ~= ", ";
            }
            Cargs ~= "...";

            if (Dcall != "") {
                Dcall ~= ", ";
            }
            Dcall ~= "...";

            if (Ccall != "") {
                Ccall ~= ", ";
            }
            Ccall ~= "...";

        } else {
            writefln("I don't know how to parse %s!", nname);
        }

        onParam++;
    }
}

void parse_Function_body(XmlNode node, string name, string mangled, string demangled, ParsedType type,
                         char[] Dargs, char[] Deargs, char[] Cargs, char[] Dcall, char[] Ccall,
                         bool isStatic = false)
{
    // make sure it's not already defined (particularly problematic for overrides that aren't overrides in D)
    static bool[char[]] handledFunctions;
    char[] fid = curClass ~ "::" ~ demangled ~ "(" ~ Deargs ~ ")";
    if (fid in handledFunctions) return;
    handledFunctions[to!string(fid)] = true;

    if (outputC) {
        dhead ~= "extern (C) " ~ type.DType ~ " " ~ demangled ~ "(" ~ Deargs ~ ");\n";
        return;
    }

    dhead ~= "extern (C) " ~ type.DType ~ " _BCD_" ~ mangled ~ "(" ~ Deargs ~ ");\n";

    if (!type.isClass) {
        dtail ~= (isStatic ? "static " : "") ~
            type.DType ~ " " ~ name ~ "(" ~ Dargs ~ ") {\n";
        if (type.DType != "void") {
            dtail ~= "return ";
        }
        dtail ~= "_BCD_" ~ mangled ~ "(" ~ Dcall ~ ");\n";
        dtail ~= "}\n";

        cout ~= type.CType ~ " _BCD_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
        if (type.DType != "void") {
            cout ~= "return ";
        }
        cout ~= "(" ~ demangled ~ "(" ~ Ccall ~ "));\n";
        cout ~= "}\n";
    } else {
        // if it's a class, we need to dup it in C, and un-dup it in D
        dtail ~= type.DType ~ " " ~ name ~ "(" ~ Dargs ~ ") {\n";
        dtail ~= "void *cret = _BCD_" ~ mangled ~ "(" ~ Dcall ~ ");\n";
        dtail ~= type.DType ~ " dret = new " ~ type.DType ~ "(cast(ireal) 0);\n";
        dtail ~= "dret.__C_data = cret;\n";
        dtail ~= "return dret;\n";
        dtail ~= "}\n";

        cout ~= type.CType ~ " _BCD_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
        cout ~= "return new " ~ type.className ~ "(" ~ demangled ~ "(" ~ Ccall ~ "));\n";
        cout ~= "}\n";
    }
}

void parse_Function_reflection(XmlNode node, string name, string cname,
                               string mangled, ParsedType type,
                               char[] Dargs, char[] Deargs, char[] Cargs, char[] Dcall, char[] Ccall)
{
    // tie to the particular class being reflected
    mangled ~= "__" ~ curReflection;

    // make sure it's not already reflected
    char[] fid = name ~ "(" ~ Deargs ~ ")";
    if (fid in reflectedFunctions) return;
    reflectedFunctions[to!string(fid)] = true;

    // make sure it's virtual
    auto isvirtual = node.getAttribute("virtual");
    if (isvirtual is null) return;

    // the C++ interface to the reflection
    cout ~= "int _BCD_R_" ~ mangled ~ "_CHECK(void *);\n";

    if (Cargs != "")
        cout ~= type.CType ~ " _BCD_R_" ~ mangled ~ "(void *, " ~ Cargs ~ ");\n";
    else
        cout ~= type.CType ~ " _BCD_R_" ~ mangled ~ "(void *);\n";

    reflectionCode ~= type.CType ~ " " ~ name ~ "(" ~ Cargs ~ ") {\n";

    reflectionCode ~= "if (_BCD_R_" ~ mangled ~ "_CHECK(__D_data))\n";
    if (type.CType != "void") reflectionCode ~= "return ";

    reflectionCode ~= "_BCD_R_" ~ mangled ~ "(__D_data";
    if (Ccall != "") reflectionCode ~= ", ";
    reflectionCode ~= Ccall ~ ");\n";

    reflectionCode ~= "else\n";
    if (type.CType != "void") reflectionCode ~= "return ";
    reflectionCode ~= curReflectionCBase ~ "::" ~ cname ~ "(" ~ Ccall ~ ");\n";
    reflectionCode ~= "}\n";

    // and the D interface
    dhead ~= "extern (C) int _BCD_R_" ~ mangled ~ "_CHECK(" ~ curReflection ~ " x) {\n";
    dhead ~= "union dp {\n";
    dhead ~= type.DType ~ " delegate(" ~ Deargs ~ ") d;\n";
    dhead ~= "struct { void *o; void *f; }\n";
    dhead ~= "}\n";
    dhead ~= "dp d; d.d = &x." ~ name ~ ";\n";
    dhead ~= "return cast(int) (d.f != &" ~ curReflectionDBase ~ "." ~ name ~ ");\n";
    dhead ~= "}\n";

    dhead ~= "extern (C) " ~ type.DType ~ " _BCD_R_" ~ mangled ~ "(" ~ curReflection ~ " __D_class, " ~
    Dargs ~ ") {\n";
    if (type.DType != "void") dhead ~= "return ";
    dhead ~= "__D_class." ~ name ~ "(" ~ Dcall ~ ");\n";
    dhead ~= "}\n";
}

/**
 * Parse a Method node
 */
void parse_Method(XmlNode node, bool reflection)
{
    /* If it's static, it's for all intents and purposes a function */
    if (node.getAttribute("static") == "1") {
        if (!reflection)
            parse_Function(node, true);
        return;
    }

    auto name = getNName(node);
    auto mangled = getMangled(node);
    ParsedType type = parseTypeReturnable(node.getAttribute("returns"));
    char[] Dargs;
    char[] Deargs;
    if (!reflection) Deargs = to!(char[])("void *This");
    char[] Cargs;
    if (!reflection) Cargs = to!(char[])(curClass ~ " *This");
    char[] Dcall;
    if (!reflection) Dcall = to!(char[])("__C_data");
    char[] Ccall;

    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall, reflection);
    if (!reflection)
        parse_Function_body(node, safeName(name), mangled, "This->" ~ name, type,
                            Dargs, Deargs, Cargs, Dcall, Ccall);
    else
        parse_Function_reflection(node, safeName(name), name, mangled, type,
                                  Dargs, Deargs, Cargs, Dcall, Ccall);
}

/**
 * Parse an OperatorMethod node
 */
void parse_OperatorMethod(XmlNode node, bool reflection)
{
    auto name = node.getAttribute("name");
    auto mangled = getMangled(node);
    ParsedType type = parseTypeReturnable(node.getAttribute("returns"));
    char[] Dargs;
    char[] Deargs;
    if (!reflection) Deargs = to!(char[])("void *This");
    char[] Cargs;
    if (!reflection) Cargs = to!(char[])(curClass ~ " *This");
    char[] Dcall;
    if (!reflection) Dcall = to!(char[])("__C_data");
    char[] Ccall;
    int argc;

    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall, reflection, &argc);

    // get the D name
    string dname;
    switch (name) {
        case "-":
            if (argc == 0) {
                dname = "opNeg";
            } else {
                dname = "opSub";
            }
            break;

        case "+":
            if (argc == 0) {
                dname = "opPos";
            } else {
                dname = "opAdd";
            }
            break;

        case "++":
            if (argc == 0) {
                dname = "opPostInc";
            } else {
                // not a real operator, but accessable
                dname = "opPreInc";
            }
            break;

        case "--":
            if (argc == 0) {
                dname = "opPostDec";
            } else {
                // not a real operator, but accessable
                dname = "opPreDec";
            }
            break;

        case "*":
            dname = "opMul";
            break;

        case "/":
            dname = "opDiv";
            break;

        case "%":
            dname = "opMod";
            break;

        case "&":
            dname = "opAnd";
            break;

        case "|":
            dname = "opOr";
            break;

        case "^":
            dname = "opXor";
            break;

        case "<<":
            dname = "opShl";
            break;

        case ">>":
            dname = "opShr";
            break;

        case "==":
            dname = "opEquals";
            break;

        case "!=":
            // not a real operator, but accessable
            dname = "opNotEquals";
            break;

        case "<":
            // not a real operator, but accessable
            dname = "opLT";
            break;

        case "<=":
            // not a real operator, but accessable
            dname = "opLE";
            break;

        case ">":
            // not a real operator, but accessable
            dname = "opGT";
            break;

        case ">=":
            // not a real operator, but accessable
            dname = "opGE";
            break;

        case "+=":
            dname = "opAddAssign";
            break;

        case "-=":
            dname = "opSubAssign";
            break;

        case "*=":
            dname = "opMulAssign";
            break;

        case "/=":
            dname = "opDivAssign";
            break;

        case "%=":
            dname = "opModAssign";
            break;

        case "&=":
            dname = "opAndAssign";
            break;

        case "|=":
            dname = "opOrAssign";
            break;

        case "^=":
            dname = "opXorAssign";
            break;

        case "<<=":
            dname = "opShlAssign";
            break;

        case ">>=":
            dname = "opShrAssign";
            break;

        default:
    }

    if (dname == "") return;

    if (!reflection)
        parse_Function_body(node, to!(char[])(dname), mangled, "This->operator" ~ name, type,
                            Dargs, Deargs, Cargs, Dcall, Ccall);
    else
        parse_Function_reflection(node, to!(char[])(dname), "operator" ~ name, mangled, type,
                                  Dargs, Deargs, Cargs, Dcall, Ccall);
}

/**
 * Parse a Function node
 */
void parse_Function(XmlNode node, bool isStatic = false)
{
    auto name = getNName(node);
    writefln("func %s", name);
    auto mangled = getMangled(node);
    auto demangled = getDemangled(node);
    ParsedType type = parseTypeReturnable(node.getAttribute("returns"));
    char[] Dargs;
    char[] Deargs;
    char[] Cargs;
    char[] Dcall;
    char[] Ccall;

    // the demangled name includes ()
    auto demparen = indexOf(demangled, '(');
    if (demparen != -1) {
        demangled = demangled[0..demparen];
    }

    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall);
    parse_Function_body(node, safeName(name), mangled, demangled, type,
                        Dargs, Deargs, Cargs, Dcall, Ccall, isStatic);
}

/**
 * Parse a Constructor node
 */
void parse_Constructor(XmlNode node, bool reflection)
{
    if (outputC) return; // no constructors in C
    if (curClassAbstract) return; // no constructors for virtual classes

    auto name = getNName(node);
    auto mangled = getMangled(node);
    if (reflection) mangled ~= "_R";

    while (indexOf(mangled, "*INTERNAL*") != -1) {
        mangled = replace(mangled, " *INTERNAL* ", "");
    }

    // no artificial constructors
    auto artificial = node.getAttribute("artificial");
    if (artificial) {
        return;
    }

    char[] Dargs;
    char[] Deargs;
    char[] Cargs;
    char[] Dcall;
    char[] Ccall;

    if (reflection) {
        // only reflect one level of constructors
        if (name != curReflectionDBase) return;
    }

    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall, false);

    // make sure it's not already defined (particularly problematic for overrides that aren't overrides in D)
    if (!reflection) {
        static bool[char[]] handledCtors;
        char[] fid = curClass ~ "(" ~ Deargs ~ ")";
        if (fid in handledCtors) return;
        handledCtors[to!string(fid)] = true;
    } else if (reflection) {
        // make sure it's not already reflected
        char[] sfid = name ~ "(" ~ Deargs ~ ")";
        if (sfid in reflectedFunctions) return;
        reflectedFunctions[to!string(sfid)] = true;
    }

    dhead ~= "extern (C) void *_BCD_new_" ~ mangled ~ "(" ~ Deargs ~ ");\n";

    dtail ~= "this(" ~ Dargs ~ ") {\n";
    dtail ~= "super(cast(ifloat) 0);\n";
    dtail ~= "__C_data = _BCD_new_" ~ mangled ~ "(" ~ Dcall ~ ");\n";
    dtail ~= "__C_data_owned = true;\n";
    if (reflection) {
        dtail ~= curReflectionInit ~ "(__C_data, cast(void *) this);\n";
    }
    dtail ~= "}\n";

    if (!reflection) {
        cout ~= curClass ~ " *_BCD_new_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
        cout ~= "return new ";
        cout ~= curClass;
        cout ~= "(" ~ Ccall ~ ");\n";
        cout ~= "}\n";
    } else {
        reflectionCode ~= curReflection ~ "(" ~ Cargs ~ ") : " ~ curReflectionCBase ~ "(" ~ Ccall ~ ") {}\n";
        reflectionPostCode ~= curReflection ~ " *_BCD_new_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
        reflectionPostCode ~= "return new ";
        reflectionPostCode ~= curReflection;
        reflectionPostCode ~= "(" ~ Ccall ~ ");\n";
        reflectionPostCode ~= "}\n";
    }

    hasPublicConstructor = true;
}

/**
 * Parse a Typedef node
 */
void parse_Typedef(XmlNode node)
{
    static bool[char[]] handledTypedefs;
    auto type = node.getAttribute("id");
    auto deftype = node.getAttribute("type");

    if(type == null || deftype == null) {
        return;
    }

    ParsedType pt = parseType(deftype);
    auto aname = getNName(node);
    if (!(type in handledTypedefs)) {
        handledTypedefs[type] = true;

        cout ~= "typedef " ~ pt.CType ~ " _BCD_" ~ type ~ "_" ~ aname ~ ";\n";

        if (parseThis(node, true)) dhead ~= "alias " ~ pt.DType ~ " " ~ safeName(aname) ~ ";\n";
    }
}

/**
 * Parse an Enumeration node
 */
void parse_Enumeration(XmlNode node)
{
    static bool[char[]] handledEnums;

    if (!parseThis(node, true)) return;

    auto aname = getNName(node);
    if (aname == "") return;

    auto realName = node.getAttribute("name");
    if (realName && realName[0] == '.') {
        // this is artificial, no real name
        realName = null;
    }

    auto type = node.getAttribute("id");

    // make an enum in D as well
    if (!(type in handledEnums)) {
        handledEnums[to!string(type)] = true;

        if (aname[0] != '.') {
            dhead ~= "enum " ~ safeName(aname) ~ " {\n";


            foreach (XmlNode curNode; node.getChildren()) {
                auto nname = to!string(curNode.getName());

                if (nname == "EnumValue") {
                    dhead ~= safeName(getNName(curNode)) ~ "=" ~
                    curNode.getAttribute("init") ~ ",\n";
                } else {
                    writefln("I don't know how to parse %s!", nname);
                }
            }

            dhead ~= "}\n";

            if(polluteNamespace) {
                foreach (XmlNode curNode; node.getChildren()) {
                    auto nname = curNode.getName();

                    if (nname == "EnumValue") {
                        dhead ~= "alias " ~ safeName(aname) ~ "." ~ safeName(getNName(curNode)) ~ " " ~
                        safeName(getNName(curNode)) ~ ";\n";
                    } else {
                        writefln("I don't know how to parse %s!", nname);
                    }
                }
            }
            }
    }
        
    // then generate consts for it
    if (outputEnumConst && !realName) {
        foreach (XmlNode curNode; node.getChildren()) {
            auto nname = curNode.getName();

            if (nname == "EnumValue") {
                dhead ~= "const int " ~ safeName(getNName(curNode)) ~ " = " ~
                curNode.getAttribute("init") ~ ";\n";
            } else {
                writefln("I don't know how to parse %s!", nname);
            }
        }
    }
}

/**
 * A type in both C[++] and D
 */
class ParsedType {
    this(char[] sCType, char[] sDType)
    {
        CType ~= sCType;
        DType ~= sDType;
    }

    this(ParsedType copy)
    {
        CType ~= copy.CType;
        DType ~= copy.DType;
    }

    this(string sCType, string sDType)
    {
        CType ~= to!(char[])(sCType);
        DType ~= to!(char[])(sDType);
    }

    ParsedType dup()
    {
        ParsedType pt = new ParsedType(this);
        pt.className ~= className;
        pt.isClass = isClass;
        pt.isClassPtr = isClassPtr;
        pt.isFunction = isFunction;
        pt.isFunctionPtr = isFunctionPtr;
        pt.isStaticArray = isStaticArray;
        return pt;
    }

    char[] CType;
    char[] DType;
    char[] className;
    bool isClass;
    bool isClassPtr;
    bool isFunction;
    bool isFunctionPtr;
    bool isStaticArray;
}

/**
 * Get the type of a node in C[++] and D, in a way which can be a D return type
 */
ParsedType parseTypeReturnable(string type)
{
    ParsedType t = parseType(type);
    if (t.isStaticArray) {
        // can't return a static array, convert it into a pointer
        auto bloc = lastIndexOf(t.DType, '[');
        if (bloc != -1) {
            // cut off the [...]
            t.DType = t.DType[0..bloc] ~ "*";
            t.isStaticArray = false;
        }
    }

    return t;
}

version (Windows) {} else {
    extern (C) int getpid();
    extern (C) int kill(int, int);
}
/**
 * Get the type of a node in C[++] and D
 */
ParsedType parseType(char[] type) {
    return parseType(to!string(type));
}

ParsedType parseType(string type)
{
    static ParsedType[char[]] parsedCache;

    int xmlrret;

    version (Windows) {} else {
        if (type == "") return null;
    }

    // first find the element matching the type
    if (!(type in parsedCache)) {

        foreach (XmlNode curNode; gccxml.getChildren()) {
            auto nname = curNode.getName();

            auto id = curNode.getAttribute("id");
            if (id != type) continue;

            if (nname == "FundamentalType") {
                auto ctype = getNName(curNode);

                switch (ctype) {
                    case "void":
                        parsedCache[type] = new ParsedType("void", "void");
                        break;

                    case "long long int":
                        parsedCache[type] = new ParsedType("long long int", "long");
                        break;

                    case "long long unsigned int":
                        parsedCache[type] = new ParsedType("long long unsigned int", "ulong");
                        break;


                    case "long int":
                        parsedCache[type] = new ParsedType("long int", "int");
                        break;

                    case "long unsigned int":
                        parsedCache[type] = new ParsedType("long unsigned int", "uint");
                        break;


                    case "int":
                        parsedCache[type] = new ParsedType("int", "int");
                        break;

                    case "unsigned int":
                        parsedCache[type] = new ParsedType("unsigned int", "uint");
                        break;


                    case "short int":
                        parsedCache[type] = new ParsedType("short int", "short");
                        break;

                    case "short unsigned int":
                        parsedCache[type] = new ParsedType("short unsigned int", "ushort");
                        break;


                    case "char":
                        parsedCache[type] = new ParsedType("char", "char");
                        break;

                    case "signed char":
                        parsedCache[type] = new ParsedType("signed char", "char");
                        break;

                    case "unsigned char":
                        parsedCache[type] = new ParsedType("unsigned char", "char");
                        break;

                    case "wchar_t":
                        parsedCache[type] = new ParsedType("wchar_t", "wchar");
                        break;

                    case "bool":
                        parsedCache[type] = new ParsedType("bool", "bool");
                        break;


                    case "long double":
                        parsedCache[type] = new ParsedType("long double", "real");
                        break;


                    case "double":
                        parsedCache[type] = new ParsedType("double", "double");
                        break;


                    case "float":
                        parsedCache[type] = new ParsedType("float", "float");
                        break;

                    default:
                        parsedCache[type] = new ParsedType("void", "void");
                        writefln("I don't know how translate %s to D.", ctype);
                }

            } else if (nname == "PointerType") {
                ParsedType baseType =
                    parseType(curNode.getAttribute("type"));

                // functions and classes are already pointers
                if (!baseType.isClass && !baseType.isFunction) {
                    baseType.CType ~= " *";
                    baseType.DType ~= " *";
                    parsedCache[type] = new ParsedType(baseType);
                } else if (baseType.isClass) {
                    ParsedType pt = new ParsedType(baseType);
                    pt.DType ~= " *";
                    pt.isClassPtr = true;

                    // if this is a const, our const will be on the wrong side!
                    if (pt.CType.length >= 7 &&
                        pt.CType[pt.CType.length - 7 .. pt.CType.length] == "* const") {
                        pt.CType[pt.CType.length - 7 .. pt.CType.length] = "const *";
                    }

                    parsedCache[type] = pt;
                } else if (baseType.isFunction) {
                    ParsedType pt = new ParsedType(baseType);
                    pt.isFunctionPtr = true;
                    parsedCache[type] = pt;
                }

            } else if (nname == "ArrayType") {
                ParsedType baseType =
                    parseType(curNode.getAttribute("type"));
                auto max = curNode.getAttribute("max");
                
                string size = "";
                if (max.length > 0)
                    size = to!string(std.conv.parse!int(max) + 1);

                // make a typedef and an alias
                static bool[char[]] handledArrays;

                if (!(type in handledArrays)) {
                    handledArrays[type] = true;

                    cout ~= "typedef " ~ baseType.CType ~ " _BCD_array_" ~ type ~
                    "[" ~ size ~ "];\n";
                }

                baseType.CType = to!(char[])("_BCD_array_" ~ type);
                baseType.DType ~= to!(char[])(" [" ~ size ~ "]");

                ParsedType pt = new ParsedType(baseType);
                pt.isStaticArray = true;
                parsedCache[type] = pt;

            } else if (nname == "ReferenceType") {
                ParsedType baseType =
                    parseType(curNode.getAttribute("type"));

                if (!baseType.isClass) {
                    if (outputC) {
                        baseType.CType ~= " *";
                    } else {
                        baseType.CType ~= " &";
                    }
                    baseType.DType ~= " *";

                    parsedCache[type] = new ParsedType(baseType);
                } else {
                    // we need to treat this as a pointer in D, but a reference in C

                    // 1) cut off the *
                    auto l = lastIndexOf(baseType.CType, '*');
                    if (l != -1) baseType.CType[l] = ' ';

                    // 2) add the &
                    if (outputC) {
                        baseType.CType ~= " *";
                    } else {
                        baseType.CType ~= " &";
                    }

                    ParsedType pt = new ParsedType(baseType);
                    pt.isClassPtr = true;
                    parsedCache[type] = pt;
                }

            } else if (nname == "Struct" || nname == "Class") {
                string className = getDemangled(curNode);
                string snname = getNName(curNode);

                if (outputC) {
                    auto incomplete = curNode.getAttribute("incomplete");

                    if (incomplete) {
                        parsedCache[type] = new ParsedType("struct " ~ className,
                                                           "void");
                    } else {
                        parsedCache[type] = new ParsedType("struct " ~ className,
                                                           snname);
                    }
                } else {
                    ParsedType pt;

                    // special case for DReflectedClass
                    if (className == "DReflectedClass") {
                        parsedCache[type] = new ParsedType("DReflectedClass",
                                                           "CXXReflectedClass");
                        break;
                    }

                    // can't have incomplete types in D, so call it a BoundClass in D
                    auto incomplete = curNode.getAttribute("incomplete");

                    if (incomplete) {
                        pt = new ParsedType(className ~ " *",
                                            "bcd.bind.BoundClass");
                    } else {
                        pt = new ParsedType(className ~ " *",
                                            to!string(safeName(getNName(curNode))));
                    }

                    pt.className = to!(char[])(className);
                    pt.isClass = true;
                    parsedCache[type] = pt;
                }

            } else if (nname == "Union") {
                string className = getDemangled(curNode);
                string snname = getNName(curNode);

                auto incomplete = curNode.getAttribute("incomplete");

                if (incomplete) {
                    parsedCache[type] = new ParsedType("union " ~ className,
                                                       "void");
                } else {
                    parsedCache[type] = new ParsedType("union " ~ className,
                                                       snname);
                }

            } else if (nname == "CvQualifiedType") {
                // this is just a const
                ParsedType pt = parseType(curNode.getAttribute("type"));

                /*if (pt.CType.length >= 2) {
                    char[] pfix = pt.CType[pt.CType.length - 2 .. pt.CType.length];
                    if (pfix == " *" ||
                        pfix == " &") {
                        pt.CType = pt.CType[0 .. pt.CType.length - 2] ~
                        " const" ~ pfix;
                        parsedCache[type] = pt;
                        break;
                    }
                }*/

                /*if (pt.CType.length < 6 ||
                    pt.CType[0..6] != "const ")
                    pt.CType = "const " ~ pt.CType;*/
                pt.CType ~= " const";

                parsedCache[type] = pt;

            } else if (nname == "Typedef") {
                // this is also an alias, but we should replicate it in D
                ParsedType pt = parseType(curNode.getAttribute("type"));
                auto aname = getNName(curNode);

                parse_Typedef(curNode);

                ParsedType rpt = new ParsedType(to!(char[])("_BCD_") ~ type ~ "_" ~ aname, pt.DType);
                rpt.isClass = pt.isClass;
                rpt.isFunction = pt.isFunction;
                rpt.isStaticArray = pt.isStaticArray;
                parsedCache[type] = rpt;

            } else if (nname == "FunctionType" || nname == "MethodType") {
                // make a typedef and an alias
                static bool[char[]] handledFunctions;

                char[] base = to!(char[])("");
                if (nname == "MethodType") {
                    base = parseType(curNode.getAttribute("basetype")).CType;
                    base = base[0 .. base.length - 2] ~ "::*";
                }

                if (!(type in handledFunctions)) {
                    handledFunctions[type] = true;

                    ParsedType pt = parseType(curNode.getAttribute("returns"));
                    char[] couta, dheada;

                    bool first = true;
                    couta = "typedef " ~ pt.CType ~
                    " (*" ~ base ~ "_BCD_func_" ~ type ~ ")(";
                    dheada = "alias " ~ pt.DType ~ " function(";

                    // now look for arguments
                    foreach (XmlNode curArg; curNode.getChildren()) {
                        auto aname = curArg.getName();

                        if (aname == "Argument") {
                            ParsedType argType =
                                parseType(curArg.getAttribute("type"));

                            if (!first) {
                                couta ~= ", ";
                                dheada ~= ", ";
                            } else {
                                first = false;
                            }

                            couta ~= argType.CType;
                            dheada ~= argType.DType;
                        } else if (aname == "Ellipsis" && outputC) {
                            if (!first) {
                                couta ~= ", ";
                                dheada ~= ", ";
                            } else {
                                first = false;
                            }

                            couta ~= "...";
                            dheada ~= "...";
                        }
                    }

                    cout ~= couta ~ ");\n";
                    dhead ~= dheada ~ ") _BCD_func_" ~ type ~ ";\n";
                }

                ParsedType pt;
                if (nname != "MethodType") {
                    pt = new ParsedType("_BCD_func_" ~ type, "_BCD_func_" ~ type);
                    pt.isFunction = true;
                } else {
                    writefln("WARNING: method types/delegates are not yet supported");
                    pt = new ParsedType("_BCD_func_" ~ type, "bcd.bind.CXXDelegate");
                    pt.isFunction = true;
                }

                parsedCache[type] = pt;

            } else if (nname == "Enumeration") {
                if (parseThis(curNode, true)) parse_Enumeration(curNode);

                // if this is fake, ignore it
                auto aname = getNName(curNode);

                if (aname[0] == '.') {
                    parsedCache[type] = new ParsedType("int", "int");
                    break;
                }

                /* we need the demangled name in C, but there is no demangled
                 * for enumerations, so we need the parent */
                if (!outputC) {
                    auto context = curNode.getAttribute("context");
                    if (context != "") {
                        ParsedType pt = parseType(context);

                        pt.CType = replace(pt.CType, " *", "");

                        if (pt.CType == "") {
                            pt.CType = to!(char[])("enum " ~ aname);
                        } else {
                            pt.CType = "enum " ~ pt.CType ~ "::" ~ aname;
                        }
                        pt.DType = to!(char[])("int");

                        parsedCache[type] = new ParsedType(pt);
                        break;
                    }
                }

                parsedCache[type] = new ParsedType("enum " ~ aname, to!(char[])("int"));

            } else if (nname == "Namespace") {
                auto aname = curNode.getAttribute("name");
                if (aname == "::") aname = to!(char[])("");
                parsedCache[type] = new ParsedType(aname, to!(char[])(""));

            } else {
                parsedCache[type] = new ParsedType("void", "void");
                writefln("I don't know how to parse the type %s.", nname);
            }

            break;
        }

        if (!(type in parsedCache)) {
            parsedCache[type] = new ParsedType("void", "void");
            writefln("Type %s not found!", type);
        }
    }

    return parsedCache[type].dup();
}

/**
 * Parse out.i for simple defines
 */
void parse_Defines()
{
    std.stream.File f = new std.stream.File("out.i", FileMode.In);
    bool inOurFile = false;

    bool[char[]] curDefines;

    while (!f.eof()) {
        char[] ln = f.readLine();
        char[][] lns = split(ln);

        if (lns.length >= 1 &&
            lns[0].length >= 1 &&
            lns[0][0] == '#') {
            if (lns[0] == "#") {
                // this is a file specification
                if (lns.length >= 3 &&
                    lns[2].length >= 2) {
                    char[] fname = lns[2][1 .. lns[2].length - 1];

                    // if it's not in a file we should be parsing, don't output it
                    inOurFile = true;
                    if (outputAll) {
                        if (fname.length <= baseDir.length ||
                            !globMatch(fname[0..baseDir.length], baseDir)) inOurFile = false;
                    } else {
                        if (fname != curFile) inOurFile = false;
                    }
                }

            } else if (lns[0] == "#define" && inOurFile) {
                // turn the #define into a const int or const double
                if (lns.length >= 3) {
                    if (isNumeric(lns[2])) {
                        curDefines[to!string(lns[1])] = true;

                        /* isNumeric can accept ending with 'L', but long is
                         * (usually) int, so strip it */
                        if (lns[2][$-1] == 'L') lns[2] = lns[2][0..$-1];

                        // int or double?
                        if (indexOf(lns[2], '.') != -1 ||
                            indexOf(lns[2], 'e') != -1 ||
                            indexOf(lns[2], 'E') != -1) {
                            dhead ~= "const double " ~ safeName(lns[1]) ~
                                " = " ~ lns[2] ~ ";\n";
                        } else {
                            dhead ~= "const int " ~ safeName(lns[1]) ~
                                " = " ~ lns[2] ~ ";\n";
                        }

                    } else if (lns[2].length >= 2 &&
                               lns[2][0] == '"' && lns[2][$-1] == '"') {
                        curDefines[to!string(lns[1])] = true;

                        // a constant string
                        dhead ~= "const char[] " ~ safeName(lns[1]) ~
                            " = " ~ lns[2] ~ ";\n";

                    } else if (lns[2] in curDefines) {
                        curDefines[to!string(lns[1])] = true;

                        // could be #define'ing to something already #defined
                        dhead ~= "alias " ~ safeName(lns[2]) ~ " " ~ safeName(lns[1]) ~ ";\n";
                    }
                }
            }
        }
    }

    f.close();
}
