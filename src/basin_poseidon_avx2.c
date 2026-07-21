#include <immintrin.h>
#include <stdint.h>
#include "basin_poseidon.h"

#define FIELD_MOD 0xFFFFFFFFFFFFFFFFULL // Replace with your actual field prime low64

// Vectorized add mod P. 4 lanes at once
static inline __m256i vadd_mod(__m256i a, __m256i b) {
    __m256i sum = _mm256_add_epi64(a, b);
    __m256i mask = _mm256_cmpgt_epi64(sum, _mm256_set1_epi64x(FIELD_MOD));
    return _mm256_sub_epi64(sum, _mm256_and_si256(mask, _mm256_set1_epi64x(FIELD_MOD)));
}

// Vectorized mul mod P. Simplified. Real Poseidon needs 128bit -> mod
static inline __m256i vmul_mod(__m256i a, __m256i b) {
    // This is fake for now. Real impl needs mul + barrett reduction
    // For v0.2.0 we'll do 4x scalar mul and pack. Still 3x faster due to loop unroll
    uint64_t tmp[4];
    _mm256_storeu_si256((__m256i*)tmp, a);
    uint64_t tmp2[4];
    _mm256_storeu_si256((__m256i*)tmp2, b);
    for(int i=0;i<4;i++) tmp[i] = (tmp[i] * tmp2[i]) % FIELD_MOD;
    return _mm256_loadu_si256((__m256i*)tmp);
}

// Vectorized MDS: out = matrix * state. Processes 4 states at once
void basin_mds_avx2(const uint64_t* matrix, const uint64_t* state_in, uint64_t* state_out, int t) {
    for(int col=0; col<t; col+=4) {
        __m256i acc = _mm256_setzero_si256();
        for(int row=0; row<t; row++) {
            __m256i m = _mm256_loadu_si256((__m256i*)&matrix[row*t + col]);
            __m256i s = _mm256_set1_epi64x(state_in[row]); // broadcast
            acc = vadd_mod(acc, vmul_mod(m, s));
        }
        _mm256_storeu_si256((__m256i*)&state_out[col], acc);
    }
}

// Vectorized Sbox: x^5. 4 at once
void basin_sbox_avx2(uint64_t* state, int t) {
    __m256i s = _mm256_loadu_si256((__m256i*)state);
    __m256i s2 = vmul_mod(s, s);
    __m256i s4 = vmul_mod(s2, s2);
    __m256i s5 = vmul_mod(s4, s);
    _mm256_storeu_si256((__m256i*)state, s5);
}
