# SIMD và tối ưu phân tích âm tiết tiếng Việt

Mục tiêu phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`

Kỳ vọng tăng tốc  `~10x` so với scalar code

```
    ÂM TIẾT:   ĐẦU  GIỮA  CUỐI THANH  CBVN
 - - - - - - - - - - - - - - - - - - - - -
        GÀN:     g     a     n     f  true
        GặN:     g    aw     n     j  true
       GIừp:    gi    uw     p     f  true
    nGhiÊng:    ng   iez    ng _none  true
     nGiêng:    ng   iez    ng _none  true
        đim:    zd     i     m _none  true
         ĩm: _none     i     m     x  true
   nghúýếng:    ng  uyez    ng     s  true
      giếng:    gi    ez    ng     s  true
         gĩ:     g     i _none     x  true
       ginh:     g     i    nh _none  true
        gim:     g     i     m _none  true
        giâ:    gi    az     i _none  true
 - - - - - - - - - - - - - - - - - - - - -
     gĩmmmm:    gi _none _none _none false
          đ: _none _none _none _none false
          g: _none _none _none _none false
          a: _none     a _none _none false
       nnnn:     n _none _none _none false
```

## [ DOING ]

- Đưa token phân tách được trong char_stream vào bộ phân tích âm tiết

- Test bộ phân tích âm tiết với mọi âm tiết tiếng Việt, viết hoa và thường lẫn lộn

## [ DONE ]

- SIMDify char stream to tokens: tìm vị trí của ascii nonalphabet bytes

- SIMDify char stream to tokens: tìm vị trí space

- Tối ưu hoá việc tìm utf8 char tiếng Việt, toLower() và tách tone

- Dùng SIMD để gạn phụ âm đầu => làm tương tự cho âm giữa và âm cuối

- Cài đặt SIM byte lookup algorithm


## Tham khảo

https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.htm

https://github.com/travisstaloch/simdjzon | A CPU with both AVX2 and CLMUL is required (Haswell from 2013 onwards should do for Intel, for AMD a Ryzen/EPYC CPU (Q1 2017) should be sufficient).

http://0x80.pl/articles/simd-byte-lookup.html | SIMD byte lookup 

https://github.com/intel/hyperscan | SIMD regular expression matching library

https://github.com/simdutf/simdutf | Unicode validation and transcoding


SSE = Streaming SIMD Extensions

AVX = Advanced Vector eXtensions (also known as Haswell New Instructions)

• SSE2/3/4: 8 128-bit XMM registers [1999]

• AVX2:    16 256-bit YMM registers [2013]

• AVX-512, 32 512-bit ZMM registers [2017 Xeon, Ice Lake]