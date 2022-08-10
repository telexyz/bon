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