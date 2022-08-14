Fastest BPE + DropOut https://github.com/telexyz/turbo/tree/main/libs/youtokentome

Zig Impl https://gwenzek.github.io/fastBPE/analysis.html
https://github.com/gwenzek/fastBPE/blob/master/fastBPE/learnBPE.zig

Blog https://leimao.github.io/blog/Byte-Pair-Encoding

Original code https://github.com/rsennrich/subword-nmt/blob/master/subword_nmt/learn_bpe.py

Video https://www.youtube.com/watch?v=tOMjTCO0htA


Coi tokens là tập hợp bytes (đơn vị nhỏ nhất có thể)
Có thể giả sử encode dài nhất <= 32-bytes
Đầu tiên cần tính count của mọi utf-8 chars trong alco_hash_count
của các token ko phải âm tiết tiếng Việt.

Đầu vào các tokens đã được count sẵn trong `counters: ahc.HashCount1M` từ `char_stream.zig`
counters chứa `keys_bytes` và `keys_bytes_len` là 1 chuỗi các `types` (uniq tokens)
Để xác định count của `pair` ta search pair's value trong keys_bytes,
để xác định keys có chứa pair's value, cộng dồn counts của các keys đó được count của pair

=> Cần 1 bước đệm là map key's ending vào key's count (u24)
=> Để dành 3-bytes sau key's ending để lưu key's count

* `key_string`\0x010203\0x20
* 0x20 GUARD_BYTE
* 0x010203 `key_count` (3-bytes)

- - -

## Thuật toán tìm sub-string hiệu quả
http://0x80.pl/articles/simd-strfind.html#algorithm

Basically these algorithms could be split into two major categories: (1) based on Deterministic Finite Automaton, like Knuth-Morris-Pratt, Boyer Moore, etc., and (2) based on a simple comparison, like the Karp-Rabin algorithm.

> The main problem with these standard algorithms is a silent assumption that comparing (only happened on) a pair of characters, and looking up in an extra table and conditions are cheap, while comparing two substrings is expansive.

But current desktop CPUs do not meet this assumption, in particular:

* There is no difference in comparing one, two, four or 8 bytes on a 64-bit CPU. When a processor supports SIMD instructions, then comparing vectors (it means 16, 32 or even 64 bytes) is as cheap as comparing a single byte.

* Thus comparing short sequences of chars can be faster than fancy algorithms which avoids such comparison.

* Looking up in a table costs one memory fetch, so at least a L1 cache round (`~3` cycles). Reading char-by-char also cost as much cycles.

* Mispredicted jumps cost several cycles of penalty (`~10-20` cycles).

* There is a short chain of dependencies: read char, compare it, conditionally jump, which make hard to utilize out-of-order execution capabilities present in a CPU.


https://github.com/ashvardanian/CppBenchSubstrSearch

