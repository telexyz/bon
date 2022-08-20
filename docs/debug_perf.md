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
# if error => https://stackoverflow.com/questions/69792467/memory-check-on-macos-12-monterey
brew install qcachegrind
```

https://vimeo.com/483928828 |
Using valgrind for performance profiling
```
valgrind --tool=callgrind ./zig-out/bin/char_stream

qcachegrind
```

```
valgrind --tool=cachegrind ./zig-out/bin/char_stream

==34318==
==34318== I   refs:      32,951,563,759
==34318== I1  misses:             6,230
==34318== LLi misses:             3,808
==34318== I1  miss rate:           0.00%
==34318== LLi miss rate:           0.00%
==34318==
==34318== D   refs:       6,562,712,683  (4,001,678,865 rd   + 2,561,033,818 wr)
==34318== D1  misses:        34,966,015  (   32,479,088 rd   +     2,486,927 wr)
==34318== LLd misses:        10,210,183  (    7,902,448 rd   +     2,307,735 wr)
==34318== D1  miss rate:            0.5% (          0.8%     +           0.1%  )
==34318== LLd miss rate:            0.2% (          0.2%     +           0.1%  )
==34318==
==34318== LL refs:           34,972,245  (   32,485,318 rd   +     2,486,927 wr)
==34318== LL misses:         10,213,991  (    7,906,256 rd   +     2,307,735 wr)
==34318== LL miss rate:             0.0% (          0.0%     +           0.1%  )
```


https://dev.to/stein/some-notes-on-using-valgrind-with-zig-35c1

First switch to c allocator `pub var allocator = std.heap.c_allocator;`
Second link with `libc` by adding `exe.linkLibC();` to `build.zig`

```
valgrind --leak-check=full --track-origins=yes \
--show-leak-kinds=all --num-callers=15 \
--log-file=leak.txt ./zig-out/bin/char_stream
```

- - -

https://github.com/michal-z/zig-gamedev/tree/main/libs/ztracy

```build tracy profiler on macos
brew install freetype capstone gtk glfw cmake
wget https://github.com/wolfpld/tracy/archive/refs/tags/v0.8.2.tar.gz
tar vxfz v0.8.2.tar.gz && rm v0.8.2.tar.gz
cd tracy/profiler/build/unix
make release
./Tracy-release
```

- - -

```
brew install hyperfine
hyperfine --warmup 3 './zig-out/bin/char_stream'
```