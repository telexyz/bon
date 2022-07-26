# zig build -Drelease-safe=true
# zig build -Drelease-fast=true -Dztracy-enable=true
zig build -Drelease-fast=true
./zig-out/bin/char_stream
# hyperfine --runs 1 --show-output 'zig-out/bin/char_stream'

# Gen assembly code
# zig build-lib -O ReleaseFast -femit-asm=main.asm --strip src/main.zig
#
# Debug, Analysis: Mem / Perf
# - - - - - - - - - - - - - - 
# valgrind --tool=callgrind ./zig-out/bin/char_stream
# 
# valgrind --tool=cachegrind ./zig-out/bin/char_stream
# 
# valgrind --leak-check=full --track-origins=yes \
# --show-leak-kinds=all --num-callers=15 \
# --log-file=leak.txt ./zig-out/bin/char_stream

# wget https://github.com/sharkdp/hyperfine/releases/download/v1.15.0/hyperfine_1.15.0_amd64.deb
# sudo dpkg -i hyperfine_1.15.0_amd64.deb

# You Token To Me, the fatest BPE out-there
# - - - - - - - - - - - - - - - - - - - - -
# brew install hyperfine
# cat ../data/*.txt > all.tx # 2.3 GB
# pip3 install Cython youtokentome
# hyperfine --runs 1 --show-output 'yttm bpe --data ../data/all.tx --model ../data/youtokentome --vocab_size 22896'
time ~/.local/bin/yttm bpe --data ../data/combined --model ../data/youtokentome --vocab_size 22896

# input: ../data/all.tx
# model: ../data/youtokentome
# vocab_size: 23500q
# n_threads: 4
# ...
# model saved to: ../data/youtokentome
# Time (abs ≡):        93.145 s               [User: 207.317 s, System: 24.864 s]