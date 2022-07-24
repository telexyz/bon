# Kiểm tra chuỗi bytes có trong tập hợp cho trước không bằng SIMD

Dịch từ http://0x80.pl/articles/simd-byte-lookup.html#introduction


## Bài toán

Cho một chuỗi bytes, tìm byte-mask chỉ ra các bytes nào nằm trong một tập hợp cho trước.

Thành phần chính của kỹ thuật SIMD này là lệnh `pshufb (_mm_shuffle_epi8)`, có trong SSE, AVX2 và AVX512BW. Lệnh này tìm kiếm byte song song trong 16-byte register (or lane, in AVX2 and AVX512) sử dụng 4-bit indices từ một vector khác.
```c
for (int i=0; i < VECTOR_SIZE; i++) {
    uint8_t index = indices_vector[i];
    if (index & 0x80) // 128: 0b10000000
        result[i] = 0x00;
    else
        result[i] = lookup_vector[index & 0x0f]; // 15: 0b1111
}

```

## Thuật toán chung

Tập bytes cho trước được thể hiện ở dạng bảng `16 x 16` bits (hình dưới), giá trị ô là 1 có nghĩa là thành phần đó của bảng có trong tập hợp. Trong đó một byte được thể hiện bởi 2 nửa 4-bits được gọi là nibble (ăn từng miếng nhỏ).

```c
.     hi nibble
  .   +--------------------------------
    . | 0 1 2 3 4 5 6 7 8 9 a b c d e f
  +---+--------------------------------
l | 0 | x x . . . . x . . . x . . x . .
o | 1 | x x x x . x x . . . . . x x . x
  | 2 | . x . . x . x . . . x . . x . .
n | 3 | . x x . . . . x . . x . x . x .
i | 4 | . . . . . . . . . . . . x x x x
b | 5 | x x . . x . x x x . x . . . x x
b | 6 | x . . . . x . x . . x . x . . .
l | 7 | . . x . . . . . . . . x . . x .
e | 8 | . . x x . . . . . . . . . . . x
  | 9 | . . x x x . . x . . x . . . . .
  | a | . . . . . . x . . . x . . . . x
  | b | . . . x . . x . . . . . . . . .
  | c | x . . . x . . . . . . . . . x x
  | d | . . . x x x . x . . x x . . . .
  | e | x . x . . . . x . x . x . . . .
  | f | x x . . . . x . . . . . x x x .
```

Thuật toán dưới dạng scalar code như sau:
```c
bool in_set(uint16_t bitmap[16], uint8_t byte) {

    const uint8_t lo_nibble = byte & 0xf; // get lo_nibble index
    const uint8_t hi_nibble = byte >> 4;  // get hi_nibble index

    const uint16_t bitset  = bitmap[lo_nibble];
    const uint16_t bitmask = uint16_t(1) << hi_nibble; // set value to 1 at hi_nibble index

    return (bitset & bitmask) != 0; // true if bitset hi_nibble value is 1
}
```

Để cài đặt tt trên bằng simd, trước hết ta bẻ bảng bit thành 2 nửa bitmap_0_7 và bitmap_8_15. Cách tính bitmask mới sẽ là `1 << (higher_nibble % 8)`.
```c
/*   */ const uint8_t lo_nibble  = input & 0x0f;
/*   */ const uint8_t hi_nibble = input >> 4;

/* 1 */ const uint8_t bitset_0_7  = bitmap_0_7[lo_nibble];
/* 2 */ const uint8_t bitset_8_15 = bitmap_8_15[lo_nibble];

/* 3 */ const uint8_t bitmask = 1 << (hi_nibble & 0x7); // hi_nibble & 0b111 == hi_nibble & 8

        uint8_t bitset;
/* 4 */ if (hi_nibble < 8)
            bitset = bitset_0_7;
        else
            bitset = bitset_8_15;

/* 5 */ return (bitset & bitmask) != 0;
```
Lệnh 1, 2, 3, 4 có thể dùng `pshufb`

Áp dụng simd
```c
// example values in set: {0x10, 0x21, 0xbd}
//            not in set: {0x36, 0x91, 0xed}
// input          = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
//                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
// lower_nibbles  = [06|00|01|01|00|0d|0d|01|06|0d|06|01|01|01|0d|00]
// higher_nibbles = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]

static const __m128i bitmap_0_7 = _mm_setr_epi8(
    /* 0 */ 0x43, /* 01000011 */
    /* 1 */ 0x6f, /* 01101111 */
    /* 2 */ 0x52, /* 01010010 */
    /* 3 */ 0x86, /* 10000110 */
    /* 4 */ 0x00, /* 00000000 */
    /* 5 */ 0xd3, /* 11010011 */
    /* 6 */ 0xa1, /* 10100001 */
    /* 7 */ 0x04, /* 00000100 */
    /* 8 */ 0x0c, /* 00001100 */
    /* 9 */ 0x9c, /* 10011100 */
    /* a */ 0x40, /* 01000000 */
    /* b */ 0x48, /* 01001000 */
    /* c */ 0x11, /* 00010001 */
    /* d */ 0xb8, /* 10111000 */
    /* e */ 0x85, /* 10000101 */
    /* f */ 0x43  /* 01000011 */
);

static const __m128i bitmap_8_15 = _mm_setr_epi8(
    /* 0 */ 0x24, /* 00100100 */
    /* 1 */ 0xb0, /* 10110000 */
    /* 2 */ 0x24, /* 00100100 */
    /* 3 */ 0x54, /* 01010100 */
    /* 4 */ 0xf0, /* 11110000 */
    /* 5 */ 0xc5, /* 11000101 */
    /* 6 */ 0x14, /* 00010100 */
    /* 7 */ 0x48, /* 01001000 */
    /* 8 */ 0x80, /* 10000000 */
    /* 9 */ 0x04, /* 00000100 */
    /* a */ 0x84, /* 10000100 */
    /* b */ 0x00, /* 00000000 */
    /* c */ 0xc0, /* 11000000 */
    /* d */ 0x0c, /* 00001100 */
    /* e */ 0x0a, /* 00001010 */
    /* f */ 0x70  /* 01110000 */
);

static const __m128i bitmask_lookup = _mm_setr_epi8(
        1, 2, 4, 8, 16, 32, 64, -128,
        1, 2, 4, 8, 16, 32, 64, -128);

// 1/ load 16 byte input
const __m128i input = _mm_loadu_si128(ptr);

// 2/ Extract indices for row_0_7
const __m128i indices_0_7          = _mm_and_si128(input, _mm_set1_epi8(0x8f)); // 0b1000_1111

// 3/ Extract indices for row_8_15
const __m128i most_significant_bit = _mm_and_si128(input, _mm_set1_epi8(0x80)); // 0b1000_0000
const __m128i indices_8_15         = _mm_xor_si128(indices_0_7, most_significant_bit);

// 4/ Fetch row_0_7 and row_8_15:
// row_0_7        = [a1|43|6f|6f|43|b8|b8|6f|a1|b8|a1|6f|6f|6f|b8|43]
// row_8_15       = [14|24|b0|b0|24|0c|0c|b0|14|0c|14|b0|b0|b0|0c|24]
const __m128i row_0_7  = _mm_shuffle_epi8(bitmap_0_7, indices_0_7);
const __m128i row_8_15 = _mm_shuffle_epi8(bitmap_8_15, indices_8_15);

// 5/ Calculate a bitmask, i.e. (1 << hi_nibble % 8).
// bitmasks       = [08|02|02|02|02|40|40|02|08|08|08|04|02|02|40|02]
const __m128i bitmasks = _mm_shuffle_epi8(bitmask_lookup, higher_nibbles);

// 6/ Choose rows halves depending on higher nibbles.
// bitsets        = [ff|ff|00|ff|ff|00|00|ff|ff|00|ff|ff|00|00|00|ff]
//                ? [a1|43|..|6f|43|..|..|6f|a1|..|a1|6f|..|..|..|43]
//                : [..|..|b0|..|..|0c|0c|..|..|0c|..|..|b0|b0|0c|..]
//
//                = [a1|43|b0|6f|43|0c|0c|6f|a1|0c|a1|6f|b0|b0|0c|43]
const __m128i bitsets = _mm_or_si128(row_0_7, row_8_15);

// 7/ Finally check which bytes belong to the set.
const __m128i tmp    = _mm_and_si128(bitsets, bitmask);
const __m128i result = _mm_cmpeq_epi8(t0, bitmask);
```

9 of instructions:
- 3 x bit-and,
- 1 x bit-or,
- 1 x bit-xor,
- 3 x shuffle,
- 1 x compare.