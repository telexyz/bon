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

'in':582    'on':552    'er':537    'ar':467    'an':381    'al':317    'en':299    'am':278    'es':264    'or':258    'il':228    'ia':218    'Đ':210     'TP':210    'el':198    'ic':191    'one':175   'st':174
'HC':169    'Ph':165    'ur':163    'HCM':161   'pp':158    'ac':157    'le':151    'it':150    'ok':149
'ea':148    'ho':146    'ra':144    'US':131    'ol':130    'id':126    'gu':126    'yr':125    'VN':124
'ing':121   'us':118    'et':109    'op':106    'ro':98     'Mo':94     'art':94    'USD':93    'ch':92
'ap':91     'Phone':91  'arc':89    'em':88     'iPhone':86 'Ch':84     'yria':84   'Syria':84
'Ar':83     'ter':83    'as':82     'ir':81     'ace':80    'Barc':79   'gue':77    'bo':76     'ex':74
'Lea':73    'mp':72     'League':72 'at':71     'ard':70    'ines':70   'ore':69    'Phil':69
'ipp':69    'Sing':69   'Singap':69 'Singapore':68          'ama':67    'App':67    'Philipp':67
'Philippines':67        'nd':66     'IS':66     'Apple':66  'og':65     'os':65     'sen':65    'ad':64
'Face':64   'li':63     'ot':63     'up':62     'Barca':62  'Cit':61    'Arsen':61  'Arsenal':61
'om':60     'inho':60   'els':59    'City':59   'ber':58    'Mour':57   'Mourinho':57           'ru':56
'ri':55     'Ro':55     'ed':53     'TT':52     'For':53    'book':53   'ik':52     'Cam':52    'ĐT':52
'ig':51     'ut':51     'GT':51     'ô':51      'ab':50     'Chels':50  'and':50    'Chelsea':50    'ba':48
'ĐH':48     'stan':48   'ide':48    'ly':47     'Vi':47     'HL':47     'ain':47    'te':46     'ov':46
'Top':46    'ine':45    'HLV':45    'ier':44    'mart':44   'Viet':44   'is':43     'ust':43    'ideo':43
'Pr':42     'un':41     'gy':41     'ero':41    'gyz':41    'hot':41    'gyzstan':41            'Kyr':41
'Kyrgyzstan':41         'ph':40     'ess':40    'Tru':40    'Trump':40  'Prem':39   'ey':39     'Premier':39
```

## [ DOING ]

https://github.com/telexyz/turbo/issues

- BPE Learn v5: Gộp nhiều pairs trong cùng 1 lần scan, tốc độ tăng tỷ lệ thuận với số pairs được gộp

## [ DONE ]

- BPE Learn v4, multi-threading + SIMD, nhanh hơn YouTokenToMe `1.75x`

- BPE Learn v1, naive impl, tốc độ = fastBPE.

- Chạy nhiều threads dùng chung Hash Count giúp tăng tốc > 2x

- Cài đặt (Almost-)Concurrent Hash Count (modest-lock) cho string <= 64 bytes

- Đưa token được phân tách trong `char_stream` vào bộ phân tích âm tiết

- Hoàn thiện `parseSyllable(bytes: []const u8)`

- SIMDify tìm tokens trong char stream

- Tối ưu hoá việc tìm utf8 char tiếng Việt, toLower() và tách tone

- Dùng SIMD để gạn phụ âm đầu, âm giữa và âm cuối

- Cài đặt SIMD byte lookup algorithm (archived in `simdify` folder)
