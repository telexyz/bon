https://www.youtube.com/watch?v=v_C1cvo1biI | 
https://lldb.llvm.org/use/tutorial.html

```
zig build
lldb zig-out/bin/char_stream.zig
(lldb) help
```

- - -

https://valgrind.org

Valgrind is an instrumentation framework for building dynamic analysis tools. There are Valgrind tools that can automatically detect many memory management and threading bugs, and profile your programs in detail. You can also use Valgrind to build new tools.

The Valgrind distribution currently includes seven production-quality tools: a memory error detector, two thread error detectors, a cache and branch-prediction profiler, a call-graph generating cache and branch-prediction profiler, and two different heap profilers. It also includes an experimental SimPoint basic block vector generator.


https://github.com/LouisBrunner/valgrind-macos

```
brew tap LouisBrunner/valgrind
brew install --HEAD LouisBrunner/valgrind/valgrind
```

ERROR => https://stackoverflow.com/questions/69792467/memory-check-on-macos-12-monterey

```
git clone https://github.com/LouisBrunner/valgrind-macos.git
cd valgrind-macos/
git checkout feature/macos_11pp2

edit configure.ac
add AC_DEFINE([DARWIN_12_00], 120000, [DARWIN_VERS value for macOS 12.0]) after line 430
add new versions for XCode 12: after line 435
AC_DEFINE([XCODE_12_0], 110000, [XCODE_VERS value for Xcode 12.0])
and after line 555

12.*)
            AC_DEFINE([XCODE_VERS], XCODE_12_0, [Xcode version])
            ;;
duplicate the case block for kernel version 21.0 (line 526), something like
       # comes after the 20.0) case
       21.*)
      AC_MSG_RESULT([Darwin 21.x (${kernel}) / macOS 12 Monterey])
      AC_DEFINE([DARWIN_VERS], DARWIN_12_00, [Darwin / Mac OS X version])
      DEFAULT_SUPP="darwin20.supp ${DEFAULT_SUPP}"
      DEFAULT_SUPP="darwin10-drd.supp ${DEFAULT_SUPP}"
                  ;;

```



- - -

https://vimeo.com/483928828 |
Using valgrind for performance profiling

