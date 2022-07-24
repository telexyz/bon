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

## Tham khảo

https://github.com/travisstaloch/simdjzon | nhiều code mẫu SIMD = Zig

SSE = Streaming SIMD Extensions
AVX = Advanced Vector eXtensions (also known as Haswell New Instructions)

• SSE2/3/4, new 8 128-bit registers [1999]

• AVX-2, new 256-bit registers [2011]

• AVX-512, 512-bit


SSE2 data types: anything that fits into 16 bytes,