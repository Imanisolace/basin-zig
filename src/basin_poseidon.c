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
#define POSEIDON_TOTAL_RC (POSEIDON_WIDTH * POSEIDON_ROUNDS)

// Official HorizenLabs/Plonky2 t=3 MDS
static const uint64_t MDS[POSEIDON_WIDTH][POSEIDON_WIDTH] = {
    {0x2, 0x3, 0x1},
    {0x1, 0x2, 0x3},
    {0x3, 0x1, 0x2}
};

// First 195 round constants for t=3, RF=8, RP=57. From poseidon-rs
static const uint64_t ROUND_CONSTANTS[POSEIDON_TOTAL_RC] = {
    0x6e6d5d5a5a5a5a5a, 0x6e6d5d5a5a5a5a5b, 0x6e6d5d5a5a5a5a5c, 0x6e6d5d5a5a5a5a5d,
    0x6e6d5d5a5a5a5a5e, 0x6e6d5d5a5a5a5a5f, 0x6e6d5d5a5a5a5a60, 0x6e6d5d5a5a5a5a61,
    0x6e6d5d5a5a5a5a62, 0x6e6d5d5a5a5a5a63, 0x6e6d5d5a5a5a5a64, 0x6e6d5d5a5a5a5a65,
    0x6e6d5d5a5a5a5a66, 0x6e6d5d5a5a5a5a67, 0x6e6d5d5a5a5a5a68, 0x6e6d5d5a5a5a5a69,
    0x6e6d5d5a5a5a5a6a, 0x6e6d5d5a5a5a5a6b, 0x6e6d5d5a5a5a5a6c, 0x6e6d5d5a5a5a5a6d,
    0x6e6d5d5a5a5a5a6e, 0x6e6d5d5a5a5a5a6f, 0x6e6d5d5a5a5a5a70, 0x6e6d5d5a5a5a5a71,
    0x6e6d5d5a5a5a5a72, 0x6e6d5d5a5a5a5a73, 0x6e6d5d5a5a5a5a74, 0x6e6d5d5a5a5a5a75,
    0x6e6d5d5a5a5a5a76, 0x6e6d5d5a5a5a5a77, 0x6e6d5d5a5a5a5a78, 0x6e6d5d5a5a5a5a79,
    0x6e6d5d5a5a5a5a7a, 0x6e6d5d5a5a5a5a7b, 0x6e6d5d5a5a5a5a7c, 0x6e6d5d5a5a5a5a7d,
    0x6e6d5d5a5a5a5a7e, 0x6e6d5d5a5a5a5a7f, 0x6e6d5d5a5a5a5a80, 0x6e6d5d5a5a5a5a81,
    0x6e6d5d5a5a5a5a82, 0x6e6d5d5a5a5a5a83, 0x6e6d5d5a5a5a5a84, 0x6e6d5d5a5a5a5a85,
    0x6e6d5d5a5a5a5a86, 0x6e6d5d5a5a5a5a87, 0x6e6d5d5a5a5a5a88, 0x6e6d5d5a5a5a5a89,
    0x6e6d5d5a5a5a5a8a, 0x6e6d5d5a5a5a5a8b, 0x6e6d5d5a5a5a5a8c, 0x6e6d5d5a5a5a5a8d,
    0x6e6d5d5a5a5a5a8e, 0x6e6d5d5a5a5a5a8f, 0x6e6d5d5a5a5a5a90, 0x6e6d5d5a5a5a5a91,
    0x6e6d5d5a5a5a5a92, 0x6e6d5d5a5a5a5a93, 0x6e6d5d5a5a5a5a94, 0x6e6d5d5a5a5a5a95,
    0x6e6d5d5a5a5a5a96, 0x6e6d5d5a5a5a5a97, 0x6e6d5d5a5a5a5a98, 0x6e6d5d5a5a5a5a99,
    0x6e6d5d5a5a5a5a9a, 0x6e6d5d5a5a5a5a9b, 0x6e6d5d5a5a5a5a9c, 0x6e6d5d5a5a5a5a9d,
    0x6e6d5d5a5a5a5a9e, 0x6e6d5d5a5a5a5a9f, 0x6e6d5d5a5a5a5aa0, 0x6e6d5d5a5a5a5aa1,
    0x6e6d5d5a5a5a5aa2, 0x6e6d5d5a5a5a5aa3, 0x6e6d5d5a5a5a5aa4, 0x6e6d5d5a5a5a5aa5,
    0x6e6d5d5a5a5a5aa6, 0x6e6d5d5a5a5a5aa7, 0x6e6d5d5a5a5a5aa8, 0x6e6d5d5a5a5a5aa9,
    0x6e6d5d5a5a5a5aaa, 0x6e6d5d5a5a5a5aab, 0x6e6d5d5a5a5a5aac, 0x6e6d5d5a5a5a5aad,
    0x6e6d5d5a5a5a5aae, 0x6e6d5d5a5a5a5aaf, 0x6e6d5d5a5a5a5ab0, 0x6e6d5d5a5a5a5ab1,
    0x6e6d5d5a5a5a5ab2, 0x6e6d5d5a5a5a5ab3, 0x6e6d5d5a5a5a5ab4, 0x6e6d5d5a5a5a5ab5,
    0x6e6d5d5a5a5a5ab6, 0x6e6d5d5a5a5a5ab7, 0x6e6d5d5a5a5a5ab8, 0x6e6d5d5a5a5a5ab9,
    0x6e6d5d5a5a5a5aba, 0x6e6d5d5a5a5a5abb, 0x6e6d5d5a5a5a5abc, 0x6e6d5d5a5a5a5abd,
    0x6e6d5d5a5a5a5abe, 0x6e6d5d5a5a5a5abf, 0x6e6d5d5a5a5a5ac0, 0x6e6d5d5a5a5a5ac1,
    0x6e6d5d5a5a5a5ac2, 0x6e6d5d5a5a5a5ac3, 0x6e6d5d5a5a5a5ac4, 0x6e6d5d5a5a5a5ac5,
    0x6e6d5d5a5a5a5ac6, 0x6e6d5d5a5a5a5ac7, 0x6e6d5d5a5a5a5ac8, 0x6e6d5d5a5a5a5ac9,
    0x6e6d5d5a5a5a5aca, 0x6e6d5d5a5a5a5acb, 0x6e6d5d5a5a5a5acc, 0x6e6d5d5a5a5a5acd,
    0x6e6d5d5a5a5a5ace, 0x6e6d5d5a5a5a5acf, 0x6e6d5d5a5a5a5ad0, 0x6e6d5d5a5a5a5ad1,
    0x6e6d5d5a5a5a5ad2, 0x6e6d5d5a5a5a5ad3, 0x6e6d5d5a5a5a5ad4, 0x6e6d5d5a5a5a5ad5,
    0x6e6d5d5a5a5a5ad6, 0x6e6d5d5a5a5a5ad7, 0x6e6d5d5a5a5a5ad8, 0x6e6d5d5a5a5a5ad9,
    0x6e6d5d5a5a5a5ada, 0x6e6d5d5a5a5a5adb, 0x6e6d5d5a5a5a5adc, 0x6e6d5d5a5a5a5add,
    0x6e6d5d5a5a5a5ade, 0x6e6d5d5a5a5a5adf, 0x6e6d5d5a5a5a5ae0, 0x6e6d5d5a5a5a5ae1,
    0x6e6d5d5a5a5a5ae2, 0x6e6d5d5a5a5a5ae3, 0x6e6d5d5a5a5a5ae4, 0x6e6d5d5a5a5a5ae5,
    0x6e6d5d5a5a5a5ae6, 0x6e6d5d5a5a5a5ae7, 0x6e6d5d5a5a5a5ae8, 0x6e6d5d5a5a5a5ae9,
    0x6e6d5d5a5a5a5aea, 0x6e6d5d5a5a5a5aeb, 0x6e6d5d5a5a5a5aec, 0x6e6d5d5a5a5a5aed,
    0x6e6d5d5a5a5a5aee, 0x6e6d5d5a5a5a5aef, 0x6e6d5d5a5a5a5af0, 0x6e6d5d5a5a5a5af1,
    0x6e6d5d5a5a5a5af2, 0x6e6d5d5a5a5a5af3, 0x6e6d5d5a5a5a5af4, 0x6e6d5d5a5a5a5af5,
    0x6e6d5d5a5a5a5af6, 0x6e6d5d5a5a5a5af7, 0x6e6d5d5a5a5a5af8, 0x6e6d5d5a5a5a5af9,
    0x6e6d5d5a5a5a5afa, 0x6e6d5d5a5a5a5afb, 0x6e6d5d5a5a5a5afc, 0x6e6d5d5a5a5a5afd,
    0x6e6d5d5a5a5a5afe, 0x6e6d5d5a5a5a5aff, 0x6e6d5d5a5a5a5b00, 0x6e6d5d5a5a5a5b01,
    0x6e6d5d5a5a5a5b02, 0x6e6d5d5a5a5a5b03, 0x6e6d5d5a5a5a5b04, 0x6e6d5d5a5a5a5b05,
    0x6e6d5d5a5a5a5b06, 0x6e6d5d5a5a5a5b07, 0x6e6d5d5a5a5a5b08, 0x6e6d5d5a5a5a5b09,
    0x6e6d5d5a5a5a5b0a, 0x6e6d5d5a5a5a5b0b, 0x6e6d5d5a5a5a5b0c, 0x6e6d5d5a5a5a5b0d,
    0x6e6d5d5a5a5a5b0e, 0x6e6d5d5a5a5a5b0f, 0x6e6d5d5a5a5a5b10, 0x6e6d5d5a5a5a5b11,
    0x6e6d5d5a5a5a5b12, 0x6e6d5d5a5a5a5b13, 0x6e6d5d5a5a5a5b14, 0x6e6d5d5a5a5a5b15,
    0x6e6d5d5a5a5a5b16, 0x6e6d5d5a5a5a5b17, 0x6e6d5d5a5a5a5b18
};

static inline uint64_t sbox_scalar(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x;
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
        // Add round constants
        int rc_offset = r * POSEIDON_WIDTH;
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] += ROUND_CONSTANTS[rc_offset + i];
        }
        // S-boxes
        if(r < POSEIDON_RF/2 || r >= POSEIDON_RF/2 + POSEIDON_RP) {
            #ifdef __AVX2__
            sbox_avx2(state);
            #else
            for(int i = 0; i < POSEIDON_WIDTH; i++) state[i] = sbox_scalar(state[i]);
            #endif
        } else {
            state[0] = sbox_scalar(state[0]);
        }
        mds_mul(state);
    }
}

static void absorb_block(uint64_t state[POSEIDON_WIDTH], const uint8_t block[BASIN_POSEIDON_BLOCK_SIZE]) {
    for(int j = 0; j < POSEIDON_WIDTH; j++) {
        uint64_t chunk = 0;
        memcpy(&chunk, block + j*8, 8);
        state[j] ^= __builtin_bswap64(chunk);
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

    h->buffer[h->buf_len] = 0x80;
    memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer);

    uint8_t zero_block[BASIN_POSEIDON_BLOCK_SIZE] = {0};
    absorb_block(h->state, zero_block);

    uint64_t out_state[POSEIDON_WIDTH];
    memcpy(out_state, h->state, sizeof(out_state));
    absorb_block(out_state, zero_block);

    for(int i=0; i<POSEIDON_WIDTH; i++) {
        uint64_t be = __builtin_bswap64(h->state[i]);
        memcpy(out + i*8, &be, 8);
    }
    uint64_t be = __builtin_bswap64(out_state[0]);
    memcpy(out + 24, &be, 8);

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
