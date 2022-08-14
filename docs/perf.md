brew install google-perftools

https://github.com/michal-z/zig-gamedev/tree/main/libs/ztracy

```build tracy profiler on macos
brew install freetype capstone gtk glfw cmake
wget https://github.com/wolfpld/tracy/archive/refs/tags/v0.8.2.tar.gz
tar vxfz v0.8.2.tar.gz && rm v0.8.2.tar.gz
cd tracy/profiler/build/unix
make release
./Tracy-release
```

https://dev.to/stein/some-notes-on-using-valgrind-with-zig-35c1


- - -

MaOS perf tools 

https://gist.github.com/loderunner/36724cc9ee8db66db305

https://github.com/tlkh/asitop

- - -


https://github.com/sharkdp/hyperfine

https://github.com/gperftools/gperftools

brew install gperftools hyperfine

hyperfine --warmup 3 './zig-out/bin/char_stream'

1) Link your executable with -lprofiler
2) Run your executable with the CPUPROFILE environment var set:
     $ CPUPROFILE=/tmp/prof.out <path/to/binary> [binary args]
3) Run pprof to analyze the CPU usage
     $ pprof <path/to/binary> /tmp/prof.out      # -pg-like text output
     $ pprof --gv <path/to/binary> /tmp/prof.out # really cool graphical output

pprof --web ./zig-out/bin/char_stream /tmp/prof.out

