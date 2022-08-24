# Tối ưu phân tích âm tiết tiếng Việt

* Phân tách âm tiết utf-8 thành `âm đầu + âm giữa + âm cuối + thanh điệu`.

* Các `tokens` ko phải âm tiết được phân tách bằng BPE (Byte-Pair Encoding).

* Dùng từ điển (và có thể RNN) làm token-repair và nhóm âm tiết thành từ.

- - - 

Các kỹ thuật có thể áp dụng: data-oriented programming, SIMD (vectorized), branchless, multi-threading. Kỳ vọng tăng tốc `~10x` so với scalar, single thread code.

Tìm hiểu sâu về phần cứng để tối ưu code và chuẩn bị tương thích cho các kiến trúc phần cứng AI sắp ra mắt (spatial, processing in memory, on-chip CPU cluster ...)


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

```
(( BPE selected symbols ))

'n ':59105  'ng':53675  'an':51743  'a ':45390  's ':40054  'i ':37313  'g ':37084  'ii':37080
'in':34348  'ha':34262  'o ':33252  'nh':31764  'h ':31477  'on':29841  'oo':29184  'en':28857
't ':26563  'aa':25939  'y ':24913  'hh':24569  'ch':22980  'k ':22521  'ng ':22313 'hi':22283
'iii':22206 'nn':22161  'ee':21730  'd ':21402  'u ':21178  'er':20663  'c ':19627  'dj':19556
'm ':19104  'jd':18946  'ar':18366  'jj':17985  'r ':17897  'uu':17838  'gg':17729  'ra':17558
'j ':17436  'hu':16959  'ho':16707  'ie':16600  'nd':16331  'am':16050  'kk':15791  'ooo':15674
'll':15482  'th':15209  'la':15106  'tt':14628  're':14509  'yy':14239  'at':13886  'te':13867
'na':13775  'al':13760  'uy':13445  'es':13392  'ss':13341  'aaa':13308 'ta':13012  'li':12879
'ma':12856  'ai':12843  'ri':12840  'eee':12570 'p ':12523  'ah':12507  'ti':12407  'as':12370
'sj':12348  'l ':12290  'el':12276  'js':12016  'sh':11983  'f ':11890  'le':11856  'lo':11753
'mm':11530  'he':11525  'is':11518  'un':11437  'ia':11089  'tr':11074  'or':10824  'it':10786
'ne':10599  'b ':10586  'ay':10577  'Th':10412  'gh':10282  'ns':10098  'hj':9986   'di':9923
'ic':9919   'gu':9886   'hd':9880   'co':9745   '❤️':9702   'et':9651   'ro':9408   'Ch':9355
'da':9263   'de':9155   'os':9151   'st':9077   'uuu':9076  'sk':9009   'ks':9006   'ca':8994
```

## [ DOING ]

- Áp dụng multi-threading + SIMD cho BPE Learn v3

More https://github.com/telexyz/turbo/issues


## [ DONE ]

- BPE Learn v3, initial chars là byte (`u8`) thay vì unicode (`u21`) để định danh symbols từ `u24` xuống `u16`. 

- BPE Learn v2, tổ chức dữ liệu tốt hơn, nhanh hơn YouTokenToMe multi-threading `~2x`.

- BPE Learn v1, naive impl, tốc độ = fastBPE, chậm hơn YouTokenToMe multi-threading 7.35x.

- Chạy nhiều threads dùng chung Hash Count giúp tăng tốc > 2x

- Cài đặt (Almost-)Concurrent Hash Count (modest-lock) cho string <= 64 bytes

- Đưa token được phân tách trong `char_stream` vào bộ phân tích âm tiết

- Hoàn thiện `parseSyllable(bytes: []const u8)`

- SIMDify tìm tokens trong char stream

- Tối ưu hoá việc tìm utf8 char tiếng Việt, toLower() và tách tone

- Dùng SIMD để gạn phụ âm đầu, âm giữa và âm cuối

- Cài đặt SIMD byte lookup algorithm (archived in `simdify` folder)
