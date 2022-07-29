# Dùng SIMD để phân tích âm tiết tiếng Việt

Mục tiêu cuối phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`


## Bài toán nhập môn: phân tích âm tiết ở dạng ascii-telex

* Để làm quen với lập trình hệ thống và SIMD

* Tập làm quen với phân tích ngữ âm

`tuoizr, tuozir, tuozri` => `t` + `uoz` + `i` + `r`
- âm đầu `t`
- âm giữa `uoz` (`uô`)
- âm cuối `i`
- thanh điệu `r` (hỏi)

b1/ Âm tiết luôn có nguyên âm `a,e,i,o,u`

Làm thế nào tìm ra được vị trí các ký tự này trong chuỗi bằng SIMD?

Hint: simd byte lookup http://0x80.pl/articles/simd-byte-lookup.html

b2/ ...

## Bài toán nâng cao: phân tích âm tiết ở dạng utf-8

`tuổi` => `t` + `uoz` + `i` + `r`

c1/ các ký tự có dấu `ơ, ô, ổ ...` được cấu thành từ nhiều byte nên ta bắt đầu bằng việc xác định các ký tự đơn byte như `t, u, i ...` và nên phân tách thành nguyên âm đơn byte `u, i ...` và phụ âm đơn byte như `t ...`

c2/ dùng lookup table để tìm trực tiếp các âm cần tìm ở dạng 32-bit

- - -


## Tham khảo

https://github.com/travisstaloch/simdjzon | code mẫu SIMD = Zig

https://github.com/google/highway | CPUs provide SIMD/vector instructions that apply the same operation to multiple data items. This can reduce energy usage e.g. fivefold because fewer instructions are executed. We also often see 5-10x speedups.

https://github.com/intel/hyperscan | SIMD regular expression matching library

https://github.com/simdutf/simdutf | Unicode validation and transcoding

https://github.com/lemire/fastbase64

https://www.reddit.com/r/simd/comments/pl3ee1/pshufb_for_table_lookup

Sneller's query performance derives from pervasive use of SIMD, specifically AVX-512 [assembly](https://github.com/SnellerInc/sneller/blob/master/vm/evalbc_amd64.s) in its 250+ core primitives. The main engine is capable of processing many lanes in parallel per core for very high processing throughput. This eliminates the need to pre-process JSON data into an alternate representation - such as search indices (Elasticsearch and variants) or columnar formats like parquet (as commonly done with SQL-based tools). Combined with the fact that Sneller's main 'API' is SQL (with JSON as the primary output format), this greatly simplifies processing pipelines built around JSON data.

SSE = Streaming SIMD Extensions
AVX = Advanced Vector eXtensions (also known as Haswell New Instructions)

• SSE2/3/4: 8 128-bit XMM registers [1999]

• AVX2:    16 256-bit YMM registers [2011]

• AVX-512, 32 512-bit ZMM registers [2017 Xeon, Ice Lake]