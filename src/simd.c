#include <immintrin.h>
#include <emmintrin.h>
#include <stdint.h>

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

// 
__m256i mm256_shuffle_epi8(__m256i a, __m256i b) {
    return _mm256_shuffle_epi8(a, b);
}

uint32_t mm256_movemask_epi8(__m256i a) {
    return _mm256_movemask_epi8(a);
}
