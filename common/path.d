/**
 * Common path functions
 * 
 * Authors:
 *  Gregor Richards
 * 
 * License:
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *  
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

module common.path;

public import std.path;

import std.c.stdlib;
import std.file;
import std.string;

/** Get the system PATH */
char[][] getPath()
{
    return split(toString(getenv("PATH")), std.path.pathsep);
}

/** From args[0], figure out our path */
void whereAmI(char[] argvz, inout char[] dir, inout char[] bname)
{
    // split it
    bname = getBaseName(argvz);
    dir = getDirName(argvz);
    
    // on Windows, this is a .exe
    version (Windows) {
        bname = defaultExt(bname, "exe");
    }
    
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
