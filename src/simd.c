#include <stdint.h>
#include <emmintrin.h> // SSE2 intrinsics 126-bit register
#include <immintrin.h> // Intel intrinsics, including 256-bit lane

__m256i mm256_shuffle_epi8(__m256i a, __m256i b) {
    return _mm256_shuffle_epi8(a, b);
}

uint32_t mm256_movemask_epi8(__m256i a) {
    return _mm256_movemask_epi8(a);
}

__m256i mm256_cmpeq_epi16(__m256i a, __m256i b) {
    return _mm256_cmpeq_epi16(a, b);
}

__m256i mm256_cmpeq_epi8(__m256i a, __m256i b) {
    return _mm256_cmpeq_epi8(a, b);
}

__m256i mm256_set_epi32(int i0, int i1, int i2, int i3,
                  int i4, int i5, int i6, int i7) {
  return _mm256_set_epi32(i0, i1, i2, i3, i4, i5, i6, i7);
}

__m256i mm256_set_epi16(short __w15, short __w14, short __w13, short __w12,
                 short __w11, short __w10, short __w09, short __w08,
                 short __w07, short __w06, short __w05, short __w04,
                 short __w03, short __w02, short __w01, short __w00) {
    return _mm256_set_epi16(__w15, __w14, __w13, __w12,
                 __w11, __w10, __w09, __w08,
                 __w07, __w06, __w05, __w04,
                 __w03, __w02, __w01, __w00);
}

__m256i mm256_set_epi8(char __b31, char __b30, char __b29, char __b28,
                 char __b27, char __b26, char __b25, char __b24,
                 char __b23, char __b22, char __b21, char __b20,
                 char __b19, char __b18, char __b17, char __b16,
                 char __b15, char __b14, char __b13, char __b12,
                 char __b11, char __b10, char __b09, char __b08,
                 char __b07, char __b06, char __b05, char __b04,
                 char __b03, char __b02, char __b01, char __b00) {
  return _mm256_set_epi8(__b31, __b30, __b29, __b28,
                 __b27, __b26, __b25, __b24,
                 __b23, __b22, __b21, __b20,
                 __b19, __b18, __b17, __b16,
                 __b15, __b14, __b13, __b12,
                 __b11, __b10, __b09, __b08,
                 __b07, __b06, __b05, __b04,
                 __b03, __b02, __b01, __b00);
}


__m128i mm_cmpeq_epi8(__m128i a, __m128i b) {
    return _mm_cmpeq_epi8(a, b);
}
__m128i mm_cmplt_epi8(__m128i a, __m128i b) {
    return _mm_cmplt_epi8(a, b);
}
__m128i mm_blendv_epi8(__m128i a, __m128i b, __m128i c) {
    return _mm_blendv_epi8(a, b, c);
}
__m128i mm_set1_epi8(signed char v) {
    return _mm_set1_epi8(v);
}

__m128i mm_setr_epi8(
    signed char v15,
    signed char v14,
    signed char v13,
    signed char v12,
    signed char v11,
    signed char v10,
    signed char v9,
    signed char v8,
    signed char v7,
    signed char v6,
    signed char v5,
    signed char v4,
    signed char v3,
    signed char v2,
    signed char v1,
    signed char v0) {
    return _mm_setr_epi8(v15,v14,v13,v12,v11,v10,v9,v8,
                          v7, v6, v5, v4, v3, v2,v1,v0);
}

__m128i mm_srli_epi16(__m128i a, signed int b) {
    return _mm_srli_epi16(a, b);
}

__m128i mm_and_si128(__m128i a, __m128i b) {
    return _mm_and_si128(a, b);
}


__m128i mm_or_si128(__m128i a, __m128i b) {
    return _mm_or_si128(a, b);
}

__m128i mm_xor_si128(__m128i a, __m128i b) {
    return _mm_xor_si128(a, b);
}

__m128i mm_shuffle_epi8(__m128i a, __m128i b) {
    return _mm_shuffle_epi8(a, b);
}
