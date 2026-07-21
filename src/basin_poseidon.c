#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

#ifdef __AVX2__
#include <immintrin.h>
#endif

#define POSEIDON_WIDTH 3
#define POSEIDON_RF 8
#define POSEIDON_RP 57
#define POSEIDON_ROUNDS (POSEIDON_RF + POSEIDON_RP)

// Use the MDS from basin_poseidon_rc.h
static const uint64_t (*MDS)[POSEIDON_WIDTH] = POSEIDON_MDS;

// Use the RC from basin_poseidon_rc.h
static const uint64_t *RC = POSEIDON_RC;

static inline uint64_t sbox_scalar(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x; // x^5
}

#ifdef __AVX2__
static inline __m256i vmul(__m256i a, __m256i b) {
    uint64_t A[4], B[4], R[4];
    _mm256_storeu_si256((__m256i*)A, a);
    _mm256_storeu_si256((__m256i*)B, b);
    for(int i=0;i<4;i++) R[i] = A[i] * B[i];
    return _mm256_loadu_si256((__m256i*)R);
}
static void sbox_avx2(uint64_t state[POSEIDON_WIDTH]) {
    uint64_t tmp[4] = {state[0], state[1], state[2], 0};
    __m256i s = _mm256_loadu_si256((__m256i*)tmp);
    __m256i s2 = vmul(s, s);
    __m256i s4 = vmul(s2, s2);
    __m256i s5 = vmul(s4, s);
    _mm256_storeu_si256((__m256i*)tmp, s5);
    state[0]=tmp[0]; state[1]=tmp[1]; state[2]=tmp[2];
}
#endif

static inline void mds_mul(uint64_t state[POSEIDON_WIDTH]) {
    uint64_t new_state[POSEIDON_WIDTH] = {0};
    for(int i = 0; i < POSEIDON_WIDTH; i++) {
        for(int j = 0; j < POSEIDON_WIDTH; j++) {
            new_state[i] += MDS[i][j] * state[j];
        }
    }
    memcpy(state, new_state, sizeof(new_state));
}

static inline uint64_t ct_select_u64(uint64_t a, uint64_t b, uint64_t mask) {
    return (a & ~mask) | (b & mask);
}
static inline uint64_t ct_eq_u64(uint64_t x, uint64_t y) {
    uint64_t d = x ^ y;
    d |= d >> 32; d |= d >> 16; d |= d >> 8; d |= d >> 4; d |= d >> 2; d |= d >> 1;
    return 0 - (1 & ~d);
}
static inline uint64_t ct_lt_u64(uint64_t x, uint64_t y) {
    return 0 - ((x < y)? 1 : 0);
}

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    for(int r = 0; r < POSEIDON_ROUNDS; r++) {
        int off = r * POSEIDON_WIDTH;
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] += RC[off + i];
        }
        if(r < POSEIDON_RF/2 || r >= POSEIDON_RF/2 + POSEIDON_RP) {
            #ifdef __AVX2__
            sbox_avx2(state);
            #else
            for(int i = 0; i < POSEIDON_WIDTH; i++) state[i] = sbox_scalar(state[i]);
            #endif
        } else {
            state[0] = sbox_scalar(state[0]); // partial round
        }
        mds_mul(state);
    }
}

// Arkworks uses LE absorb
static void absorb_block(uint64_t state[POSEIDON_WIDTH], const uint8_t block[BASIN_POSEIDON_BLOCK_SIZE]) {
    for(int j = 0; j < POSEIDON_WIDTH; j++) {
        uint64_t chunk = 0;
        memcpy(&chunk, block + j*8, 8); // LE load
        state[j] ^= chunk;
    }
    poseidon_permute(state);
}

int basin_hasher_init(basin_hasher_t* h) {
    if (!h) return -1;
    memset(h, 0, sizeof(*h));
    return 0;
}

int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len) {
    if (!h ||!data) return -1;
    size_t i = 0;
    while (i < len) {
        size_t space = BASIN_POSEIDON_BLOCK_SIZE - h->buf_len;
        size_t remaining = len - i;
        uint64_t use_space = ct_lt_u64(space, remaining);
        size_t to_copy = ct_select_u64(remaining, space, use_space);

        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;

        uint64_t is_full = ct_eq_u64(h->buf_len, BASIN_POSEIDON_BLOCK_SIZE);
        if (is_full) {
            absorb_block(h->state, h->buffer);
            h->buf_len = 0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[BASIN_POSEIDON_OUTPUT_BYTES]) {
    if (!h ||!out) return -1;

    // padding: 0x80 then zeros
    h->buffer[h->buf_len] = 0x80;
    memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer);

    uint8_t zero_block[BASIN_POSEIDON_BLOCK_SIZE] = {0};
    absorb_block(h->state, zero_block);

    uint64_t out_state[POSEIDON_WIDTH];
    memcpy(out_state, h->state, sizeof(out_state));
    absorb_block(out_state, zero_block);

    // LE squeeze: 32 bytes = s0,s1,s2,s0 again
    for(int i=0; i<8; i++) out[i] = (h->state[0] >> (8*i)) & 0xff;
    for(int i=0; i<8; i++) out[8+i] = (h->state[1] >> (8*i)) & 0xff;
    for(int i=0; i<8; i++) out[16+i] = (h->state[2] >> (8*i)) & 0xff;
    for(int i=0; i<8; i++) out[24+i] = (out_state[0] >> (8*i)) & 0xff;

    memset(h->state, 0, sizeof(h->state));
    memset(h->buffer, 0, sizeof(h->buffer));
    h->buf_len = 0;
    return 0;
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output) return -1;
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}
