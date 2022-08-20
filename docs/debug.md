https://lldb.llvm.org/use/tutorial.html

```
zig build
lldb zig-out/bin/char_stream.zig
(lldb) help
```

https://valgrind.org

Valgrind is an instrumentation framework for building dynamic analysis tools. There are Valgrind tools that can automatically detect many memory management and threading bugs, and profile your programs in detail. You can also use Valgrind to build new tools.

The Valgrind distribution currently includes seven production-quality tools: a memory error detector, two thread error detectors, a cache and branch-prediction profiler, a call-graph generating cache and branch-prediction profiler, and two different heap profilers. It also includes an experimental SimPoint basic block vector generator.


https://github.com/LouisBrunner/valgrind-macos

```
brew tap LouisBrunner/valgrind
brew install --HEAD LouisBrunner/valgrind/valgrind
```

https://vimeo.com/483928828
Using valgrind for performance profiling

