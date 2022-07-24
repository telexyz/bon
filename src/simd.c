#include <immintrin.h>
#include <emmintrin.h>
#include <stdint.h>

__m256i w_mm256_shuffle_epi8(__m256i a, __m256i b) {
    return _mm256_shuffle_epi8(a, b);
}

uint32_t w_mm256_movemask_epi8(__m256i a) {
    return _mm256_movemask_epi8(a);
}
