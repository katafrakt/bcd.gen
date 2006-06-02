/**
 * Generate bindings for C[++] in D
 * 
 * Authors: Gregor Richards
 * 
 * License:
 *  Copyright (C) 2006  Gregor Richards
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

private import std.file;
private import std.path;
private import std.process;
private import std.stdio;
private import std.stream;
private import std.string;

import std.c.stdlib;
alias std.string.atoi atoi;
alias std.c.stdlib.free free;

private import bcd.gen.libxml2;

extern (C) char* getenv(char*);

// some global variables (yay)
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
/** The D output */
char[] dhead;
char[] dtail;
/** The C[++] output */
char[] cout;
char[] curClass;
/** Should we output C instead of C++ */
bool outputC;
/** Should we output symbols provided by any header in the dir? */
bool outputAll;
/** Should we generate consts for enums? */
bool outputEnumConst;
/** Other BCD requirements */
char[][char[]] reqDependencies;
/** The root to the XML tree */
xmlNode *gccxml = null;

char[][char[]] files;


int main(char[][] args)
{
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
        writefln("  -E");
        writefln("    Generate const int's for unnamed enum values");
        writefln("  -T<template class>[=<count>]");
        writefln("    Make the given template class accessable from D.  If the");
        writefln("    class has more than one template parameter, also provide");
        writefln("    the count.");
        writefln("  -N<symbol to ignore>");
        return 1;
    }
    
    char[] forcedImport;
    char[] templates;
    
    // set the globals
    curFile = args[1];
    baseDir = getDirName(args[1]);
    shortName = getBaseName(args[1]);
    if (find(shortName, '.') != -1) {
        shortName = getName(shortName);
    }
    shortName = safeName(shortName);
    
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
            int eqloc = find(req, '=');
            if (eqloc == -1) {
                writefln("Argument %s not recognized.", args[i]);
                continue;
            }
            reqDependencies[req[0..eqloc]] = req[eqloc + 1 .. req.length];
            
        } else if (args[i] == "-A") {
            outputAll = true;
            
        } else if (args[i][0..2] == "-F") {
            forcedImport ~= "import " ~ args[i][2..args[i].length] ~ ";\n";
            
        } else if (args[i][0..2] == "-T") {
            char[] temp = args[i][2..args[i].length];
            int count = 1, eqloc;
            
            eqloc = find(temp, '=');
            if (eqloc != -1) {
                count = atoi(temp[eqloc + 1 .. temp.length]);
                temp = temp[0..eqloc];
            }
            
            templates ~= temp ~ "<DReflectedClass";
            
            for (int i = 1; i < count; i++)
                templates ~= ", DReflectedClass";
            
            templates ~= "> __IGNORE_" ~ temp ~ ";\n";
            
        } else if (args[i] == "-E") {
            outputEnumConst = true;
            
        } else {
            writefln("Argument %s not recognized.", args[i]);
        }
    }
    
    // the header to attach to all generated files
    const char[] genhead = "/* THIS FILE GENERATED BY bcd.gen */\n";
    
    dNamespace = args[2];
    
    // some buffers
    dhead = genhead; // the D header (extern (C)'s)
    dhead ~= "module bcd." ~ dNamespace ~ "." ~ shortName ~ ";\n";
    if (!outputC) dhead ~= "import bcd.bind;\n";
    dhead ~= forcedImport;
    
    cout = genhead; // the C++ output (to name.cc)
    cout ~= "#include <stdlib.h>\n";
    cout ~= "#include <string.h>\n";
    cout ~= "#include \"../bind.h\"\n";
    cout ~= "#include \"" ~ incPrefix ~ getBaseName(args[1]) ~ "\"\n";
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
        write("bcd/" ~ dNamespace ~ "/template_D.h",
              "#include \"../bind.h\"\n" ~
              "#include \"" ~ incPrefix ~ getBaseName(args[1]) ~ "\"\n" ~
              templates);
        templates = "-include bcd/" ~ dNamespace ~ "/template_D.h ";
    }
    
    // gccxml options
    char[] gccxmlopts = templates ~ 
    toString(getenv(outputC ? "CFLAGS" : "CXXFLAGS"));
    
    // preprocess it
    if (system("gccxml -E -dD " ~ gccxmlopts ~ " -o out.i " ~ args[1])) {
        return 2;
    }
    
    parse_Defines();
    
    // xml-ize it
    if (system("gccxml " ~ gccxmlopts ~
               " -fxml=out.xml " ~ args[1])) {
        return 2;
    }
    
    // then initialize libxml2
    xmlDoc *doc = null;
    xmlNode *rootElement = null;
    
    xmlCheckVersion(20621); // the version bcdgen's XML was ported from
    
    // and read it in
    doc = xmlReadFile("out.xml", null, 0);
    
    if (doc == null) {
        writefln("Failed to parse the GCCXML-produced XML file!");
        return 3;
    }
    
    // Get the root element node
    gccxml = xmlDocGetRootElement(doc);
    
    parse_GCC_XML();
    
    xmlCleanupParser();
    
    if (!outputC) cout ~= "}\n";
    
    // write out the files
    write("bcd/" ~ dNamespace ~ "/" ~ shortName ~ ".d",
          dhead ~ dtail);
    if (!outputC) {
        write("bcd/" ~ dNamespace ~ "/" ~ shortName ~ ".cc",
              cout);
    }
    
    // get rid of the files we no longer need
    if (templates != "") {
        std.file.remove("bcd/" ~ dNamespace ~ "/template_D.h");
    }
    std.file.remove("out.i");
    std.file.remove("out.xml");
    
    return 0;
}

/**
 * Is this numeric?
 */
bool isNumeric(char[] str)
{
    bool hase;
    bool hasdot;
    
    for (int i = 0; i < str.length; i++) {
        char c = str[i];
        if (c >= '0' && c <= '9') continue;
        
        if (c == 'e' || c == 'E') {
            if (hase) return false;
            hase = true;
        } else if (c == 'x' || c == 'X') {
            if (i != 1) return false;
            if (str[0] != '0') return false;
        } else if (c == '-') {
            if (i != 0) return false;
        } else if (c == '.') {
            if (hasdot) return false;
            hasdot = true;
        } else {
            return false;
        }
    }
    
    return true;
}

/**
 * Return a name that doesn't stomp on any D keywords
 */
char[] safeName(char[] name)
{
    char[] ret = name[0..name.length];
    if (name == "alias" ||
        name == "align" ||
        name == "body" ||
        name == "final" ||
        name == "function" ||
        name == "in" ||
        name == "inout" ||
        name == "module" ||
        name == "out" ||
        name == "override" ||
        name == "scope" ||
        name == "version") {
        ret ~= "_";
    }
    
    ret = replace(ret, ".", "_");
    ret = replace(ret, "-", "_");
    ret = replace(ret, "<DReflectedClass>", "_D");
    
    return ret;
}

/**
 * Return name unless it's anonymous, in which case return mangled
 */
char[] getNName(xmlNode *node)
{
    char[] name = toStringFree(xmlGetProp(node, "name"));
    if (name == "") name = toStringFree(xmlGetProp(node, "mangled"));
    if (name == "") {
        char[] id = toStringFree(xmlGetProp(node, "id"));
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
    ret ~= toString(from);
    free(from);
    return ret;
}

/**
 * Return mangled unless it's not mangled
 */
char *getMangled(xmlNode *node)
{
    char *mangled = xmlGetProp(node, "mangled");
    if (!mangled && outputC) mangled = xmlGetProp(node, "name");
    return mangled;
}

/**
 * Return demangled unless it's not mangled
 */
char *getDemangled(xmlNode *node)
{
    char *demangled = xmlGetProp(node, "demangled");
    if (!demangled && outputC) demangled = xmlGetProp(node, "name");
    return demangled;
}

/**
 * Do we need to parse this node?
 */
bool parseThis(xmlNode *node, bool allowNameless = false)
{
    // only parse it if it's in the file we're parsing and it's demanglable
    char* file = xmlGetProp(node, "file");
    char* demangled = getDemangled(node);
    char* incomplete = xmlGetProp(node, "incomplete");
    if (incomplete) free(incomplete);
    
    if (file && (demangled || allowNameless) && !incomplete) {
        char[] sfile = toStringFree(file);
        char[] sdemangled = toStringFree(demangled);
        
        // if it's not in a file we should be parsing, don't output it
        if (outputAll) {
            if (files[sfile].length <= baseDir.length ||
                files[sfile][0..baseDir.length] != baseDir) return false;
        } else {
            if (files[sfile] != curFile) return false;
        }
        
        // if it's builtin, don't do it
        char* name = xmlGetProp(node, "name");
        if (name) {
            char[] sname = toStringFree(name);
            if (sname.length >= 9 &&
                sname[0..9] == "__builtin") {
                return false;
            }
        }
        
        // if access is private, don't do it
        char* access = xmlGetProp(node, "access");
        if (access &&
            toStringFree(access) != "public") {
            return false;
        }
        
        // if we were told to ignore it, do so
        if (sdemangled.length >= 8 &&
            sdemangled[0..8] == "__IGNORE") return false;
        foreach (i; ignoreSyms) {
            if (sdemangled == i) {
                return false;
            }
        }
        
        return true;
    } else {
        if (file) free(file);
        if (demangled) free(demangled);
        return false;
    }
}

/**
 * Parse the members of a node
 */
void parseMembers(xmlNode *node, bool inclass, bool types)
{
    char *members = xmlGetProp(node, "members");
    if (!members) return;
    
    char[] smembers = toStringFree(members);
    char[][] memberList = split(smembers);
    
    // parse each member in the memberList
    foreach (m; memberList) {
        parse_GCC_XML_for(m, inclass, types);
    }
}

/**
 * Parse a GCC_XML node
 */
void parse_GCC_XML()
{
    xmlNode *curNode = null;
    int xmlrret;
    
    // first parse for files and fundamental types
    for (curNode = gccxml.children; curNode; curNode = curNode.next) {
        if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
            char[] nname = toString(curNode.name);
            
            //writefln("  %s", nname);
            
            if (nname == "File") {
                parse_File(curNode);
            }
        }
    }
    
    // then parse for namespaces, typedefs, enums (all of which can be top-level)
    for (curNode = gccxml.children; curNode; curNode = curNode.next) {
        if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
            char[] nname = toString(curNode.name);
            
            //writefln("  %s", nname);
            
            if (nname == "Namespace") {
                parse_Namespace(curNode);
            } else if (nname == "Typedef") {
                parse_Typedef(curNode);
            } else if (nname == "Enumeration") {
                parse_Enumeration(curNode);
            } else if (nname == "Class") {
                // special case for template classes
                char[] sname = toStringFree(xmlGetProp(curNode, "name"));
                if (find(sname, "<DReflectedClass>") != -1) {
                    parse_Class(curNode);
                }
            }
        }
    }
}

/**
 * Parse a GCC_XML node for a specified ID
 */
void parse_GCC_XML_for(char[] parseFor, bool inclass, bool types)
{
    xmlNode *curNode = null;
    int xmlrret;
    
    for (curNode = gccxml.children; curNode; curNode = curNode.next) {
        if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
            char[] nname = toString(curNode.name);
            
            char *id = xmlGetProp(curNode, "id");
            if (parseFor != toStringFree(id)) continue;
            
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
            
            //writefln("  %s", nname);
            
            if (nname == "Variable" || nname == "Field") {
                if (!types) parse_Variable(curNode, inclass);
            } else if (nname == "Method") {
                if (!types) parse_Method(curNode);
            } else if (nname == "OperatorMethod") {
                if (!types) parse_OperatorMethod(curNode);
            } else if (nname == "Function") {
                if (!types) parse_Function(curNode);
            } else if (nname == "Constructor") {
                if (!types) parse_Constructor(curNode);
            } else if (nname == "Destructor") {
                // this code is automatic :)
            } else if (nname == "Typedef") {
                if (types) parse_Typedef(curNode);
            } else if (nname == "Enumeration") {
                if (types) parse_Enumeration(curNode);
            } else {
                writefln("I don't know how to parse %s!", nname);
            }
        }
    }
}

/**
 * Parse a File node
 */
void parse_File(xmlNode *node)
{
    // associate the id with the filename
    char* id, name;
    id = xmlGetProp(node, "id");
    name = xmlGetProp(node, "name");
    if (id && name) {
        char[] sname = toString(name);
        
        files[toStringFree(id)] = sname;
        
        // import it in D
        
        // first try our own namespace
        if (getDirName(sname) == baseDir) {
            char[] baseName = sname[baseDir.length + 1 .. sname.length];
            if (find(baseName, '.') != -1) {
                baseName = getName(baseName);
            }
            
            if (baseName != shortName)
                dhead ~= "import bcd." ~ dNamespace ~ "." ~ safeName(baseName) ~ ";\n";
        }
        
        // then others
        foreach (req; reqDependencies.keys) {
            if (getDirName(sname) == req) {
                char[] baseName = sname[req.length + 1 .. sname.length];
                if (find(baseName, '.') != -1) {
                    baseName = getName(baseName);
                }
                
                baseName = safeName(baseName);
                
                if (baseName != shortName)
                    dhead ~= "import bcd." ~ reqDependencies[req] ~ "." ~ safeName(baseName) ~ ";\n";
            }
        }
    } else {
        if (id) free(id);
        if (name) free(name);
    }
}

/**
 * Parse a Namespace node
 */
void parse_Namespace(xmlNode *node)
{
    parseMembers(node, false, true);
    parseMembers(node, false, false);
}

/**
 * Parse a Class or Struct node to C++
 */
void parse_Class(xmlNode *node)
{
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    char[] demangled = toStringFree(getDemangled(node));
    
    parseMembers(node, true, true);
    
    // parse for base classes
    char[] base = "bcd.bind.BoundClass";
    xmlNode *curNode = null;
    for (curNode = node.children; curNode; curNode = curNode.next) {
        if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
            if (toString(curNode.name) == "Base") {
                ParsedType pt = parseType(toStringFree(xmlGetProp(curNode, "type")));
                base = pt.DType;
                break;
            }
        }
    }
    
    // if this is derived from a template, the derivation is worthless from D
    if (find(base, '<') != -1) base = "bcd.bind.BoundClass";
    
    dtail ~= "class " ~ safeName(name) ~ " : " ~ base ~ " {\n";
    
    dtail ~= "this(ifloat ignore) {\n";
    dtail ~= "super(ignore);\n";
    dtail ~= "}\n";
    
    cout ~= "void _BCD_delete_" ~ mangled ~ "(" ~ demangled ~ " *This) {\n";
    cout ~= "delete This;\n";
    cout ~= "}\n";
    
    dhead ~= "extern (C) void _BCD_delete_" ~ mangled ~ "(void *);\n";
    
    dtail ~= "~this() {\n";
    dtail ~= "if (__C_data) _BCD_delete_" ~ mangled ~ "(__C_data);\n";
    dtail ~= "__C_data = null;\n";
    dtail ~= "}\n";
    
    curClass = demangled;
    
    parseMembers(node, true, false);
    dtail ~= "}\n";
}

/**
 * Parse a Struct or Union node to C
 */
void parse_Struct(xmlNode *node)
{
    char[] type = toString(node.name);
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    char[] demangled = toStringFree(getDemangled(node));
    
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
}

/**
 * Parse a Variable or Field node
 */
void parse_Variable(xmlNode *node, bool inclass)
{
    char[] stype = toStringFree(xmlGetProp(node, "type"));
    ParsedType type = parseType(stype);
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    
    if (outputC) {
        if (!inclass) {
            dtail ~= "extern (C) ";
        }
        dtail ~= type.DType ~ " " ~ safeName(name) ~ ";\n";
    } else {
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
            cout ~= "return (" ~ type.CType ~ ") ";
            if (type.isClass) cout ~= "&";
            cout ~= "This->" ~ name ~ ";\n";
            cout ~= "}\n";
        } else {
            char[] demangled = toStringFree(getDemangled(node));
        
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
            cout ~= "return (" ~ type.CType  ~ ") ";
            if (type.isClass) cout ~= "&";
            cout ~= demangled ~ ";\n";
            cout ~= "}\n";
        }
    }
}

/**
 * Parse Argument nodes
 */
void parse_Arguments(xmlNode *node, inout char[] Dargs, inout char[] Deargs,
                     inout char[] Cargs, inout char[] Dcall,
                     inout char[] Ccall,
                     int *argc = null)
{
    int onParam = 0;
    xmlNode *curNode = null;
    
    for (curNode = node.children; curNode; curNode = curNode.next) {
        if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
            char[] nname = toString(curNode.name);
            
            if (nname == "Argument") {
                ParsedType atype = parseType(toStringFree(xmlGetProp(curNode, "type")));
                char[] aname = getNName(curNode);
                if (aname == "") aname = "_" ~ toString(onParam);
                aname = safeName(aname);
                
                if (Dargs != "") {
                    Dargs ~= ", ";
                }
                Dargs ~= atype.DType ~ " " ~ aname;
                
                if (atype.isClass || atype.isClassPtr) {
                    // this becomes a void * in D's view
                    if (Deargs != "") {
                        Deargs ~= ", ";
                    }
                    Deargs ~= "void *" ~ aname;
                } else {
                    if (Deargs != "") {
                        Deargs ~= ", ";
                    }
                    Deargs ~= atype.DType ~ " " ~ aname;
                }
                
                if (Cargs != "") {
                    Cargs ~= ", ";
                }
                Cargs ~= atype.CType ~ " " ~ aname;
                
                if (Dcall != "") {
                    Dcall ~= ", ";
                }
                Dcall ~= aname;
                if (atype.isClass || atype.isClassPtr) {
                    // turn this into the real info
                    Dcall ~= ".__C_data";
                }
                
                if (atype.isClass) {
                    // need to dereference
                    if (Ccall != "") {
                        Ccall ~= ", ";
                    }
                    Ccall ~= "*" ~ aname;
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
}

void parse_Function_body(xmlNode *node, char[] name, char[] mangled, char[] demangled, ParsedType type,
                         char[] Dargs, char[] Deargs, char[] Cargs, char[] Dcall, char[] Ccall)
{
    if (outputC) {
        dhead ~= "extern (C) " ~ type.DType ~ " " ~ demangled ~ "(" ~ Deargs ~ ");\n";
        return;
    }
    
    dhead ~= "extern (C) " ~ type.DType ~ " _BCD_" ~ mangled ~ "(" ~ Deargs ~ ");\n";
    
    if (!type.isClass) {
        dtail ~= type.DType ~ " " ~ name ~ "(" ~ Dargs ~ ") {\n";
        if (type.DType != "void") {
            dtail ~= "return ";
        }
        dtail ~= "_BCD_" ~ mangled ~ "(" ~ Dcall ~ ");\n";
        dtail ~= "}\n";
    
        cout ~= type.CType ~ " _BCD_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
        if (type.DType != "void") {
            cout ~= "return (" ~ type.CType ~ ") ";
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

/**
 * Parse a Method node
 */
void parse_Method(xmlNode *node)
{
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    ParsedType type = parseType(toStringFree(xmlGetProp(node, "returns")));
    char[] Dargs;
    char[] Deargs = "void *This";
    char[] Cargs = curClass ~ " *This";
    char[] Dcall = "__C_data";
    char[] Ccall;
    
    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall);
    parse_Function_body(node, safeName(name), mangled, "This->" ~ name, type,
                        Dargs, Deargs, Cargs, Dcall, Ccall);
}

/**
 * Parse an OperatorMethod node
 */
void parse_OperatorMethod(xmlNode *node)
{
    char[] name = toStringFree(xmlGetProp(node, "name"));;
    char[] mangled = toStringFree(getMangled(node));
    ParsedType type = parseType(toStringFree(xmlGetProp(node, "returns")));
    char[] Dargs;
    char[] Deargs = "void *This";
    char[] Cargs = curClass ~ " *This";
    char[] Dcall = "__C_data";
    char[] Ccall;
    int argc;
    
    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall, &argc);
    
    // get the D name
    char[] dname;
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
    
    parse_Function_body(node, dname, mangled, "This->" ~ name, type,
                        Dargs, Deargs, Cargs, Dcall, Ccall);
}

/**
 * Parse a Function node
 */
void parse_Function(xmlNode *node)
{
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    char[] demangled = toStringFree(getDemangled(node));
    ParsedType type = parseType(toStringFree(xmlGetProp(node, "returns")));
    char[] Dargs;
    char[] Deargs;
    char[] Cargs;
    char[] Dcall;
    char[] Ccall;
    
    // the demangled name includes ()
    int demparen = find(demangled, '(');
    if (demparen != -1) {
        demangled = demangled[0..demparen];
    }
    
    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall);
    parse_Function_body(node, safeName(name), mangled, demangled, type,
                        Dargs, Deargs, Cargs, Dcall, Ccall);
}

/**
 * Parse a Constructor node
 */
void parse_Constructor(xmlNode *node)
{
    if (outputC) return; // no constructors in C
    
    char[] name = getNName(node);
    char[] mangled = toStringFree(getMangled(node));
    
    while (find(mangled, "*INTERNAL*") != -1) {
        mangled = replace(mangled, " *INTERNAL* ", "");
    }
    
    char[] Dargs;
    char[] Deargs = "void *This";
    char[] Cargs;
    if (outputC) {
        Cargs = "struct " ~ curClass ~ " *This";
    } else {
        Cargs = curClass ~ " *This";
    }
    char[] Dcall = "__C_data";
    char[] Ccall;
    
    parse_Arguments(node, Dargs, Deargs, Cargs, Dcall, Ccall);
    
    dhead ~= "extern (C) void *_BCD_new_" ~ mangled ~ "(" ~ Deargs ~ ");\n";
    
    dtail ~= "this(" ~ Dargs ~ ") {\n";
    dtail ~= "super(cast(ifloat) 0);\n";
    dtail ~= "__C_data = _BCD_new_" ~ mangled ~ "(" ~ Dcall ~ ");\n";
    dtail ~= "}\n";
    
    cout ~= curClass ~ " *_BCD_new_" ~ mangled ~ "(" ~ Cargs ~ ") {\n";
    cout ~= "return new " ~ curClass ~ "(" ~ Ccall ~ ");\n";
    cout ~= "}\n";
}

/**
 * Parse a Typedef node
 */
void parse_Typedef(xmlNode *node)
{
    static bool[char[]] handledTypedefs;
    
    char[] type = toStringFree(xmlGetProp(node, "id"));
    char[] deftype = toStringFree(xmlGetProp(node, "type"));
    
    ParsedType pt = parseType(deftype);
    char[] aname = getNName(node);
    
    if (!(type in handledTypedefs)) {
        handledTypedefs[type] = true;
        
        cout ~= "typedef " ~ pt.CType ~ " _BCD_" ~ aname ~ ";\n";
        
        if (parseThis(node, true)) dhead ~= "alias " ~ pt.DType ~ " " ~ safeName(aname) ~ ";\n";
    }
}

/**
 * Parse an Enumeration node
 */
void parse_Enumeration(xmlNode *node)
{
    static bool[char[]] handledEnums;
    
    if (!parseThis(node, true)) return;
    
    char[] aname = getNName(node);
    if (aname == "") return;
    
    char* realName = xmlGetProp(node, "name");
    if (realName && realName[0] == '.') {
        // this is artificial, no real name
        free(realName);
        realName = null;
    }
    if (realName) free(realName);
    
    char[] type = toStringFree(xmlGetProp(node, "id"));
    
    // make an enum in D as well
    if (!(type in handledEnums)) {
        handledEnums[type] = true;
        
        if (aname[0] == '.') return;
        
        dhead ~= "enum " ~ safeName(aname) ~ " {\n";
        
        xmlNode *curNode = null;
        
        for (curNode = node.children; curNode; curNode = curNode.next) {
            if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
                char[] nname = toString(curNode.name);
                
                if (nname == "EnumValue") {
                    dhead ~= safeName(getNName(curNode)) ~ "=" ~
                    toStringFree(xmlGetProp(curNode, "init")) ~ ",\n";
                } else {
                    writefln("I don't know how to parse %s!", nname);
                }
            }
        }
        
        dhead ~= "}\n";
        
        // then generate consts for it
        if (outputEnumConst && !realName) {
            for (curNode = node.children; curNode; curNode = curNode.next) {
                if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
                    char[] nname = toString(curNode.name);
                
                    if (nname == "EnumValue") {
                        dhead ~= "const int " ~ safeName(getNName(curNode)) ~ " = " ~
                        toStringFree(xmlGetProp(curNode, "init")) ~ ";\n";
                    } else {
                        writefln("I don't know how to parse %s!", nname);
                    }
                }
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
    
    ParsedType dup()
    {
        ParsedType pt = new ParsedType(this);
        pt.className ~= className;
        pt.isClass = isClass;
        pt.isClassPtr = isClassPtr;
        pt.isFunction = isFunction;
        return pt;
    }
    
    char[] CType;
    char[] DType;
    char[] className;
    bool isClass;
    bool isClassPtr;
    bool isFunction;
}

extern (C) int getpid();
extern (C) int kill(int, int);
/**
 * Get the type of a node in C[++] and D
 */
ParsedType parseType(char[] type)
{
    static ParsedType[char[]] parsedCache;
    
    int xmlrret;
    
    if (type == "") kill(getpid(), 11);
    
    // first find the element matching the type
    if (!(type in parsedCache)) {
        xmlNode *curNode = null;
        
        for (curNode = gccxml.children; curNode; curNode = curNode.next) {
            if (curNode.type == xmlElementType.XML_ELEMENT_NODE) {
                char[] nname = toString(curNode.name);
                
                char[] id = toStringFree(xmlGetProp(curNode, "id"));
                if (id != type) continue;
                
                if (nname == "FundamentalType") {
                    char[] ctype = getNName(curNode);
                    
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
                        parseType(toStringFree(xmlGetProp(curNode, "type")));
                    
                    // functions and classes are already pointers
                    if (!baseType.isClass && !baseType.isFunction) {
                        baseType.CType ~= " *";
                        baseType.DType ~= " *";
                        parsedCache[type] = new ParsedType(baseType);
                    } else if (baseType.isClass) {
                        ParsedType pt = new ParsedType(baseType);
                        pt.DType ~= " *";
                        pt.isClassPtr = true;
                        parsedCache[type] = pt;
                    } else {
                        parsedCache[type] = new ParsedType(baseType);
                    }
                    
                } else if (nname == "ArrayType") {
                    ParsedType baseType =
                        parseType(toStringFree(xmlGetProp(curNode, "type")));
                    int size = atoi(toStringFree(xmlGetProp(curNode, "max"))) + 1;
                
                    // make a typedef and an alias
                    static bool[char[]] handledArrays;
                
                    if (!(type in handledArrays)) {
                        handledArrays[type] = true;
                    
                        cout ~= "typedef " ~ baseType.CType ~ " _BCD_array_" ~ type ~
                        "[" ~ toString(size) ~ "];\n";
                    }
                
                    baseType.CType = "_BCD_array_" ~ type;
                    baseType.DType ~= " [" ~ toString(size) ~ "]";
                
                    parsedCache[type] = new ParsedType(baseType);
                
                } else if (nname == "ReferenceType") {
                    ParsedType baseType =
                        parseType(toStringFree(xmlGetProp(curNode, "type")));
                
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
                        baseType.CType = baseType.CType[0 .. baseType.CType.length - 2];
                        
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
                    char[] className = toStringFree(getDemangled(curNode));
                    char[] nname = safeName(getNName(curNode));
                    
                    if (outputC) {
                        char* incomplete = xmlGetProp(curNode, "incomplete");
                        if (incomplete) free(incomplete);
                        
                        if (incomplete) {
                            parsedCache[type] = new ParsedType("struct " ~ className,
                                                               "void");
                        } else {
                            parsedCache[type] = new ParsedType("struct " ~ className,
                                                               nname);
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
                        char* incomplete = xmlGetProp(curNode, "incomplete");
                        if (incomplete) free(incomplete);
                        
                        if (incomplete) {
                            pt = new ParsedType(className ~ " *",
                                                "bcd.bind.BoundClass");
                        } else {
                            pt = new ParsedType(className ~ " *",
                                                safeName(getNName(curNode)));
                        }
                    
                        pt.className = className;
                        pt.isClass = true;
                        parsedCache[type] = pt;
                    }
                
                } else if (nname == "Union") {
                    char[] className = toStringFree(getDemangled(curNode));
                    char[] nname = safeName(getNName(curNode));
                
                    char* incomplete = xmlGetProp(curNode, "incomplete");
                    if (incomplete) free(incomplete);
                
                    if (incomplete) {
                        parsedCache[type] = new ParsedType("union " ~ className,
                                                           "void");
                    } else {
                        parsedCache[type] = new ParsedType("union " ~ className,
                                                           nname);
                    }
                
                } else if (nname == "CvQualifiedType") {
                    // this is just a const
                    ParsedType pt = parseType(toStringFree(xmlGetProp(curNode, "type")));
                
                    if (pt.CType.length < 6 ||
                        pt.CType[0..6] != "const ")
                        pt.CType = "const " ~ pt.CType;
                    parsedCache[type] = pt;
                
                } else if (nname == "Typedef") {
                    // this is also an alias, but we should replicate it in D
                    ParsedType pt = parseType(toStringFree(xmlGetProp(curNode, "type")));
                    char[] aname = getNName(curNode);
                    
                    parse_Typedef(curNode);
                    
                    ParsedType rpt = new ParsedType("_BCD_" ~ aname, pt.DType);
                    rpt.isClass = pt.isClass;
                    rpt.isFunction = pt.isFunction;
                    parsedCache[type] = rpt;
                
                } else if (nname == "FunctionType") {
                    // make a typedef and an alias
                    static bool[char[]] handledFunctions;
                
                    if (!(type in handledFunctions)) {
                        handledFunctions[type] = true;
                        
                        ParsedType pt = parseType(toStringFree(xmlGetProp(curNode, "returns")));
                        char[] couta, dheada;
                        
                        bool first = true;
                        couta = "typedef " ~ pt.CType ~
                        " (*_BCD_func_" ~ type ~ ")(";
                        dheada = "alias " ~ pt.DType ~ " function(";
                    
                        // now look for arguments
                        xmlNode *curArg;
                        for (curArg = curNode.children; curArg; curArg = curArg.next) {
                            if (curArg.type == xmlElementType.XML_ELEMENT_NODE) {
                                char[] aname = toString(curArg.name);
                                
                                if (aname == "Argument") {
                                    ParsedType argType =
                                        parseType(toStringFree(xmlGetProp(curArg, "type")));
                                    
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
                        }
                    
                        cout ~= couta ~ ");\n";
                        dhead ~= dheada ~ ") _BCD_func_" ~ type ~ ";\n";
                    }
                
                    ParsedType pt = new ParsedType("_BCD_func_" ~ type, "_BCD_func_" ~ type);
                    pt.isFunction = true;
                
                    parsedCache[type] = pt;
             
                } else if (nname == "Enumeration") {
                    if (parseThis(curNode, true)) parse_Enumeration(curNode);
                
                    // if this is fake, ignore it
                    char[] aname = getNName(curNode); 
                
                    if (aname[0] == '.') {
                        parsedCache[type] = new ParsedType("int", "int");
                        break;
                    }
                
                    /* we need the demangled name in C, but there is no demangled
                     * for enumerations, so we need the parent */
                    if (!outputC) {
                        char[] context = toStringFree(xmlGetProp(curNode, "context"));
                        if (context != "") {
                            ParsedType pt = parseType(context);
                            
                            pt.CType = replace(pt.CType, " *", "");
                            
                            if (pt.CType == "") {
                                pt.CType = "enum " ~ aname;
                            } else {
                                pt.CType = "enum " ~ pt.CType ~ "::" ~ aname;
                            }
                            pt.DType = "int";
                        
                            parsedCache[type] = new ParsedType(pt);
                            break;
                        }
                    }
                    
                    parsedCache[type] = new ParsedType("enum " ~ aname, "int");
                
                } else if (nname == "Namespace") {
                    char[] aname = toStringFree(xmlGetProp(curNode, "name"));
                    if (aname == "::") aname = "";
                    parsedCache[type] = new ParsedType(aname, "");
                
                } else {
                    parsedCache[type] = new ParsedType("void", "void");
                    writefln("I don't know how to parse the type %s.", nname);
                }
                
                break;
            }
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
    File f = new File("out.i", FileMode.In);
    bool inOurFile = false;
    
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
                            fname[0..baseDir.length] != baseDir) inOurFile = false;
                    } else {
                        if (fname != curFile) inOurFile = false;
                    }
                }
                
            } else if (lns[0] == "#define" && inOurFile) {
                // turn the #define into a const int or const double
                if (lns.length >= 3 &&
                    isNumeric(lns[2])) {
                    // int or double?
                    if (find(lns[2], '.') != -1 ||
                        find(lns[2], 'e') != -1 ||
                        find(lns[2], 'E') != -1) {
                        dhead ~= "const double " ~ safeName(lns[1]) ~
                        " = " ~ lns[2] ~ ";\n";
                    } else {
                        dhead ~= "const int " ~ safeName(lns[1]) ~
                        " = " ~ lns[2] ~ ";\n";
                    }
                }
            }
        }
    }
    
    f.close();
}
