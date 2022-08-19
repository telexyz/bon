# zig build -Drelease-safe=true
# zig build -Drelease-fast=true -Dztracy-enable=true
zig build -Drelease-fast=true
time zig-out/bin/char_stream

# cat ../data/*.txt > all.tx # 2.3 GB
# pip3 install Cython youtokentome
# yttm encode --model OUTPUT_MODEL_FILE --output_type subword < TEST_DATA_FILE > ENCODED_DATA
# time yttm bpe --data ../data/all.tx --model ../data/youtokentome --vocab_size 20000
# Training parameters
#   input: ../data/all.tx
#   model: ../youtokentome
#   vocab_size: 2000
#   n_threads: 4
#   character_coverage: 1
#   pad: 0
#   unk: 1
#   bos: 2
#   eos: 3

# reading file...
# learning bpe...
# number of unique characters in the training data: 14896
# number of deleted characters: 0
# number of unique characters left: 14896
# id: 15000=14916+14981         freq: 2234699     subword: ▁năm=▁n+ăm
# id: 16000=14909+15047         freq: 148465      subword: ▁hát=▁h+át
# id: 17000=15062+72            freq: 53942       subword: ▁"S=▁"+S
# id: 18000=14959+15060         freq: 30528       subword: ▁Vàng=▁V+àng
# id: 19000=15452+28            freq: 19642       subword: ▁ik=▁i+k
# model saved to: ../youtokentome
# 201.20s user, 28.40s system, 239% cpu, 1:36.05 total