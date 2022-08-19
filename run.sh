# zig build -Drelease-safe=true
# zig build -Drelease-fast=true -Dztracy-enable=true
zig build -Drelease-fast=true
time zig-out/bin/char_stream
