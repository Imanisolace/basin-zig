#include "basin.h"
#include <string.h>
#include <stdint.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_BLOCK_SIZE 24
#define POSEIDON_RF 8
#define POSEIDON_RP 57
#define POSEIDON_ROUNDS (POSEIDON_RF + POSEIDON_RP)

static const uint64_t MDS[POSEIDON_WIDTH][POSEIDON_WIDTH] = {
    {2, 3, 1},
    {1, 2, 3},
    {3, 1, 2}
};

// Deterministic PRNG for constants. Matches HorizenLabs seed
static uint64_t rc_gen(uint64_t seed) {
    seed ^= seed >> 12;
    seed ^= seed << 25;
    seed ^= seed >> 27;
    return seed * 0x2545F4914F6CDD1DULL;
}

static inline uint64_t sbox(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x;
}

static inline void mds_mul(uint64_t state[POSEIDON_WIDTH]) {
    uint64_t new_state[POSEIDON_WIDTH] = {0};
    for(int i = 0; i < POSEIDON_WIDTH; i++) {
        for(int j = 0; j < POSEIDON_WIDTH; j++) {
            new_state[i] += MDS[i][j] * state[j];
        }
    }
    memcpy(state, new_state, sizeof(new_state));
}

static inline uint64_t ct_select_u64(uint64_t a, uint64_t b, uint64_t mask) { return (a & ~mask) | (b & mask); }
static inline uint64_t ct_eq_u64(uint64_t x, uint64_t y) { uint64_t d = x ^ y; d |= d >> 32; d |= d >> 16; d |= d >> 8; d |= d >> 4; d |= d >> 2; d |= d >> 1; return 0 - (1 & ~d); }
static inline uint64_t ct_lt_u64(uint64_t x, uint64_t y) { return 0 - ((x < y)? 1 : 0); }

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    uint64_t seed = 0x123456789abcdef0ULL; // domain separator
    for(int r = 0; r < POSEIDON_ROUNDS; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] += rc_gen(seed + r*POSEIDON_WIDTH + i);
        }
        if(r < POSEIDON_RF/2 || r >= POSEIDON_RF/2 + POSEIDON_RP) {
            for(int i = 0; i < POSEIDON_WIDTH; i++) state[i] = sbox(state[i]);
        } else {
            state[0] = sbox(state[0]);
        }
        mds_mul(state);
    }
}

static void absorb_block(uint64_t state[POSEIDON_WIDTH], const uint8_t block[BASIN_POSEIDON_BLOCK_SIZE]) {
    for(int j = 0; j < POSEIDON_WIDTH; j++) {
        uint64_t chunk = 0;
        memcpy(&chunk, block + j*8, 8);
        state[j] ^= chunk;
    }
    poseidon_permute(state);
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output) return -1;
    basin_hasher_t h; basin_hasher_init(&h); basin_hasher_update(&h, input, input_len); return basin_hasher_final(&h, output);
}
int basin_hasher_init(basin_hasher_t* h) { if (!h) return -1; memset(h, 0, sizeof(*h)); return 0; }
int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len) {
    if (!h ||!data) return -1; size_t i = 0;
    while (i < len) {
        size_t space = BASIN_POSEIDON_BLOCK_SIZE - h->buf_len; size_t remaining = len - i;
        uint64_t use_space = ct_lt_u64(space, remaining); size_t to_copy = ct_select_u64(remaining, space, use_space);
        memcpy(h->buffer + h->buf_len, data + i, to_copy); h->buf_len += to_copy; i += to_copy;
        uint64_t is_full = ct_eq_u64(h->buf_len, BASIN_POSEIDON_BLOCK_SIZE);
        uint64_t new_state[POSEIDON_WIDTH]; memcpy(new_state, h->state, sizeof(new_state)); absorb_block(new_state, h->buffer);
        for(int k=0; k<POSEIDON_WIDTH; k++) h->state[k] = ct_select_u64(h->state[k], new_state[k], is_full);
        h->buf_len = ct_select_u64(h->buf_len, 0, is_full);
    }
    return 0;
}
int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]) {
    if (!h ||!out) return -1;
    h->buffer[h->buf_len] = 0x80; memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer); uint8_t zero_block[BASIN_POSEIDON_BLOCK_SIZE] = {0}; absorb_block(h->state, zero_block);
    uint8_t tmp[POSEIDON_OUTPUT_BYTES] = {0}; memcpy(tmp, h->state, POSEIDON_WIDTH * 8); memcpy(out, tmp, POSEIDON_OUTPUT_BYTES);
    memset(h->state, 0, sizeof(h->state)); memset(h->buffer, 0, sizeof(h->buffer)); memset(tmp, 0, sizeof(tmp)); h->buf_len = 0; return 0;
}
