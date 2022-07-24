# Dùng SIMD để phân tích âm tiết tiếng Việt

Mục tiêu cuối phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`


## Bài toán nhập môn: phân tích âm tiết ở dạng ascii-telex

* Để làm quen với lập trình hệ thống và SIMD

* Tập làm quen với phân tích ngữ âm

`tuoizr` => `t` + `uoz` + `i` + `r`
- âm đầu `t`
- âm giữa `uoz` (`uô`)
- âm cuối `i`
- thanh điệu `r` (hỏi)

b1/ Âm tiết luôn có nguyên âm `a,e,i,o,u`

Làm thế nào tìm ra được vị trí các ký tự này trong chuỗi bằng SIMD?

Hint: simd byte lookup http://0x80.pl/articles/simd-byte-lookup.html

b2/ ...

## Bài toán nâng cao: phân tích âm tiết ở dạng utf-8

`tuổi` => => `t` + `uoz` + `i` + `r`

b1/ các ký tự có dấu `ơ, ô, ổ ...` được cấu thành từ nhiều byte nên ta bắt đầu bằng việc xác định các ký tự đơn byte như `t, u, i ...` và nên phân tách thành nguyên âm đơn byte `u, i ...` và phụ âm đơn byte như `t ...`

b2/ ...

- - -

## Tài liệu SIMD

http://0x80.pl/articles/simd-strfind.html | https://github.com/WojciechMula/sse4-strstr


The main problem with these standard algorithms is a silent assumption that comparing a pair of characters, looking up in an extra table and conditions are cheap, while comparing two substrings is expansive. But current desktop CPUs do not meet this assumption, in particular:


* There is no difference in comparing one, two, four or 8 bytes on a 64-bit CPU. When a processor supports SIMD instructions, then comparing vectors (it means 16, 32 or even 64 bytes) is as cheap as comparing a single byte. => Thus comparing short sequences of chars can be faster than fancy algorithms which avoids such comparison.

* Looking up in a table costs one memory fetch, so at least a L1 cache round (3 cycles). Reading char-by-char also cost as much cycles.

* Mispredicted jumps cost several cycles of penalty (10-20 cycles).

* There is a short chain of dependencies: read char, compare it, conditionally jump, which make hard to utilize out-of-order execution capabilities present in a CPU.


- - -

## Tham khảo thêm

https://github.com/travisstaloch/simdjzon | nhiều code mẫu SIMD = Zig


https://www.eidos.ic.i.u-tokyo.ac.jp/~tau/lecture/parallel_distributed/slides/pdf/peak_cpu.pdf


- - -

SSE = Streaming SIMD Extensions
AVX = Advanced Vector eXtensions (also known as Haswell New Instructions)

• SSE2/3/4, new 8 128-bit registers [1999]

• AVX-2, new 256-bit registers [2011]

• AVX-512, 512-bit


SSE2 data types: anything that fits into 16 bytes,