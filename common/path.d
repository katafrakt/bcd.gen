/**
 * Common path functions
 * 
 * Authors:
 *  Gregor Richards
 */

module common.path;

public import std.path;

import std.c.stdlib;
import std.file;
import std.string;

char[][] getPath()
{
    return split(toString(getenv("PATH")), std.path.pathsep);
}

void whereAmI(char[] argvz, inout char[] dir, inout char[] bname)
{
    // split it
    bname = getBaseName(argvz);
    dir = getDirName(argvz);
    
    // is this a directory?
    if (find(dir, std.path.sep) != -1) return;
    
    version (Windows) {
        // is it in cwd?
        char[] cwd = getcwd();
        if (exists(cwd ~ std.path.sep ~ bname)) {
            dir = cwd;
            return;
        }
    }
    
    // rifle through the path
    char[][] path = getPath();
    foreach (pe; path) {
        char[] fullname = pe ~ std.path.sep ~ bname;
        if (exists(fullname)) {
            version (Windows) {
                dir = pe;
                return;
            } else {
                if (getAttributes(fullname) & 0100) {
                    dir = pe;
                    return;
                }
            }
        }
    }
    
    // bad, but live with it
    return;
}
