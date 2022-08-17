# Tối ưu phân tích âm tiết tiếng Việt

Mục tiêu phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`.
Các `tokens` ko phải âm tiết được phân tách bằng BPE (Byte-Pair Encoding).

Các kỹ thuật có thể áp dụng: SIMD (vectorized), branchless, multi-threading

Kỳ vọng tăng tốc `~10x` so với scalar, single thread code

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

Xem https://github.com/telexyz/turbo/issues

## [ DONE ]

- Chạy nhiều threads dùng chung Hash Count giúp tăng tốc > 2x

- Cài đặt (Almost-)Concurrent Hash Count (modest-lock) cho string <= 64 bytes

- Đưa token được phân tách trong `char_stream` vào bộ phân tích âm tiết

- Hoàn thiện `parseSyllable(bytes: []const u8)`

- SIMDify tìm tokens trong char stream

- Tối ưu hoá việc tìm utf8 char tiếng Việt, toLower() và tách tone

- Dùng SIMD để gạn phụ âm đầu, âm giữa và âm cuối

- Cài đặt SIMD byte lookup algorithm (archived in `simdify` folder)