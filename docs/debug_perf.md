https://sycl.it/agenda/workshops/advanced-debugging-techniques

Learn how to use powerful tools such as `Valgrind`, `GDB`, `QEMU`, and `rr`. Explore memory watchpoints, reverse-execution, leak checking, thread sanitization, and defensive programming to turn head-scratchers into no-brainers.

Bugs will have nowhere to hide once you master these advanced techniques!

- - -

## LLDB

https://lldb.llvm.org/use/map.html |
https://lldb.llvm.org/use/tutorial.html

```
zig build
lldb zig-out/bin/hash_count_str
(lldb) help

b hash_count_str.zig:139
b hash_count_str.zig:143

run

fr v 		# `frame variable` Show the arguments and local variables for the current frame
fr v -a		# `frame variable --no-args` Show the local variables for the current frame.

p bar 		# Show the contents of local variable "bar".
p/x bar 	# Show the contents of local variable "bar" formatted as hex.

s 			# Do a source level single step in the currently selected thread.
```

- - -

## Valgrind

https://www.youtube.com/watch?v=8JEEYwdrexc |
Using Valgrind and GDB together to fix a segfault and memory leak

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

## Tracy

https://github.com/michal-z/zig-gamedev/tree/main/libs/ztracy

```build tracy profiler on macos
brew install freetype capstone gtk glfw cmake
wget https://github.com/wolfpld/tracy/archive/refs/tags/v0.8.2.tar.gz
tar vxfz v0.8.2.tar.gz && rm v0.8.2.tar.gz
cd tracy/profiler/build/unix
make release
./Tracy-release
```