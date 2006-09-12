/*
 * Copyright (C) 2006  Gregor Richards
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

import std.c.stdlib;
import common.path;
import std.stdio;
import std.string;

extern(Windows) void SetEnvironmentVariableA(char *lpName, char *lpValue);
extern(C) int _spawnv(int, char *, char **);

private void toAStringz(char[][] a, char**az)
{
    foreach(char[] s; a) {
        *az++ = toStringz(s);
    }
    *az = null;
}

int main(char[][] args)
{
    // turn args into argv-style
    char** argv = cast(char**)alloca((char*).sizeof * (1 + args.length));
    toAStringz(args, argv);
    
    // figure out our location
    char[] dir, bname;
    whereAmI(args[0], dir, bname);
    char[] basePath = replace(dir, "\\", "/");
    SetEnvironmentVariableA("GCCXML_FLAGS", "-D__DBL_MIN_EXP__='(-1021)' -D__FLT_MIN__='1.17549435e-38F' -D__CHAR_BIT__='8' -D__WCHAR_MAX__='65535U' -D__DBL_DENORM_MIN__='4.9406564584124654e-324' -D__FLT_EVAL_METHOD__='2' -D__DBL_MIN_10_EXP__='(-307)' -D__FINITE_MATH_ONLY__='0' -D__GNUC_PATCHLEVEL__='2' -D_stdcall='__attribute__((__stdcall__))' -D__SHRT_MAX__='32767' -D__LDBL_MAX__='1.18973149535723176502e+4932L' -D__LDBL_MAX_EXP__='16384' -D__SCHAR_MAX__='127' -D__USER_LABEL_PREFIX__='_' -D__STDC_HOSTED__='1' -D__WIN32='1' -D__LDBL_HAS_INFINITY__='1' -D__DBL_DIG__='15' -D__FLT_EPSILON__='1.19209290e-7F' -D__GXX_WEAK__='1' -D__tune_i686__='1' -D__LDBL_MIN__='3.36210314311209350626e-4932L' -D__DECIMAL_DIG__='21' -D__LDBL_HAS_QUIET_NAN__='1' -D__GNUC__='3' -D_cdecl='__attribute__((__cdecl__))' -D__DBL_MAX__='1.7976931348623157e+308' -D__WINNT='1' -D__DBL_HAS_INFINITY__='1' -D__WINNT__='1' -D_fastcall='__attribute__((__fastcall__))' -D__cplusplus='1' -D__USING_SJLJ_EXCEPTIONS__='1' -D__DEPRECATED='1' -D__DBL_MAX_EXP__='1024' -D__WIN32__='1' -D__GNUG__='3' -D__LONG_LONG_MAX__='9223372036854775807LL' -D__GXX_ABI_VERSION='1002' -D__FLT_MIN_EXP__='(-125)' -D__DBL_MIN__='2.2250738585072014e-308' -D__FLT_MIN_10_EXP__='(-37)' -D__DBL_HAS_QUIET_NAN__='1' -D__REGISTER_PREFIX__='' -D__cdecl='__attribute__((__cdecl__))' -D__NO_INLINE__='1' -D__i386='1' -D__FLT_MANT_DIG__='24' -D__VERSION__='\"3.4.2 (mingw-special)\"' -D_WIN32='1' -D_X86_='1' -Di386='1' -D__i386__='1' -D__SIZE_TYPE__='unsigned int' -D__FLT_RADIX__='2' -D__LDBL_EPSILON__='1.08420217248550443401e-19L' -D__MSVCRT__='1' -D__FLT_HAS_QUIET_NAN__='1' -D__FLT_MAX_10_EXP__='38' -D__LONG_MAX__='2147483647L' -D__FLT_HAS_INFINITY__='1' -D__stdcall='__attribute__((__stdcall__))' -D__EXCEPTIONS='1' -D__LDBL_MANT_DIG__='64' -D__WCHAR_TYPE__='short unsigned int' -D__FLT_DIG__='6' -D__INT_MAX__='2147483647' -DWIN32='1' -D__MINGW32__='1' -D__FLT_MAX_EXP__='128' -D__DBL_MANT_DIG__='53' -D__WINT_TYPE__='short unsigned int' -D__LDBL_MIN_EXP__='(-16381)' -D__WCHAR_UNSIGNED__='1' -D__LDBL_MAX_10_EXP__='4932' -D__DBL_EPSILON__='2.2204460492503131e-16' -D__tune_pentiumpro__='1' -D__fastcall='__attribute__((__fastcall__))' -DWINNT='1' -D__FLT_DENORM_MIN__='1.40129846e-45F' -D__FLT_MAX__='3.40282347e+38F' -D__GNUC_MINOR__='4' -D__DBL_MAX_10_EXP__='308' -D__LDBL_DENORM_MIN__='3.64519953188247460253e-4951L' -D__PTRDIFF_TYPE__='int' -D__LDBL_MIN_10_EXP__='(-4931)' -D__LDBL_DIG__='18' -D__declspec(x)='__attribute__((x))' -iwrapper\"" ~ basePath ~ "\" -include \"" ~ basePath ~ "/gccxml_builtins.h\" -I\"" ~ basePath ~ "/include\"");
    return _spawnv(0, toStringz(basePath ~ "/gccxml.exe"), argv);
}
