# SIMD và tối ưu phân tích âm tiết tiếng Việt

Mục tiêu phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`

Kỳ vọng tăng tốc  `~10x` so với scalar code

```

    ÂM TIẾT:   ĐẦU  GIỮA  CUỐI THANH  CBVN
 - - - - - - - - - - - - - - - - - - - - -
        GÀN:     g     a     n     f  true      gàn
        GặN:     g    aw     n     j  true      gặn
       GIừp:    gi    uw     p     f  true     giừp
    nGhiÊng:    ng   iez    ng _none  true  nghiêng
     nGiêng:    ng   iez    ng _none  true  nghiêng
        đim:    zd     i     m _none  true      đim
         ĩm: _none     i     m     x  true       ĩm
   nghúýếng:    ng  uyez    ng     s  true  nguyếng
      giếng:    gi    ez    ng     s  true    giếng
         gĩ:     g     i _none     x  true      ghĩ
       ginh:     g     i    nh _none  true    ghinh
        gim:     g     i     m _none  true     ghim
        giâ:    gi    az _none _none  true      giâ
          a: _none     a _none _none  true        a
 - - - - - - - - - - - - - - - - - - - - -
     gĩmmmm:    gi _none _none _none false
          đ: _none _none _none _none false
          g: _none _none _none _none false
       nnnn:     n _none _none _none false
 - - - - - - - - - - - - - - - - - - - - -
      khủya:    kh  uyez _none     r  true    khuỷa
      tuảnh:     t   uoz    nh     r  true    tuổnh
      míach:     m   iez    ch     s  true    miếch
      dưạng:     d   uow    ng     j  true    dượng
        duơ:     d   uow _none _none  true      dưa
 - - - - - - - - - - - - - - - - - - - - -
         qa: _none _none _none _none  true
        qui:    qu     i _none _none  true      qui
        que:    qu     e _none _none  true      que
        quy:    qu     y _none _none  true      quy
        cua:     c   uoz _none _none  true      cua
        qua:    qu     a _none _none  true      qua
       quốc:    qu    oz     c     s  true     quốc
       cuốc:     c   uoz     c     s  true     cuốc
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