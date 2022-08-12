# zig build -Drelease-fast=true -Dztracy-enable=true
zig build -Drelease-fast=true
time ./zig-out/bin/char_stream
zig run src/char_stream.zig