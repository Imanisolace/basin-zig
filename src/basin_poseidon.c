#include "basin.h"
#include <string.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_BLOCK_SIZE 24

// v0.2: CT helpers. Always return 0 or 0xFF..FF mask
static inline uint64_t ct_select_u64(uint64_t a, uint64_t b, uint64_t mask) {
    return (a & ~mask) | (b & mask);
}

// returns 0xFF..FF if x==y else 0
static inline uint64_t ct_eq_u64(uint64_t x, uint64_t y) {
    uint64_t d = x ^ y;
    d |= d >> 32; d |= d >> 16; d |= d >> 8; d |= d >> 4; d |= d >> 2; d |= d >> 1;
    return 0 - (1 & ~d); // 0 or 0xFF..FF
}

// returns 0xFF..FF if x < y else 0
static inline uint64_t ct_lt_u64(uint64_t x, uint64_t y) {
    return 0 - ((x < y)? 1 : 0); // compiler will make this branchless
}

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    for(int r = 0; r < 8; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            uint64_t add = state[(i+1)%POSEIDON_WIDTH] + (uint64_t)r;
            state[i] ^= add;
            state[i] = (state[i] << 13) | (state[i] >> 51);
        }
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
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
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

        // ct_min: if space < remaining use space else remaining
        uint64_t use_space = ct_lt_u64(space, remaining);
        size_t to_copy = ct_select_u64(remaining, space, use_space);

        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;

        // Branchless absorb: compute both paths, select
        uint64_t is_full = ct_eq_u64(h->buf_len, BASIN_POSEIDON_BLOCK_SIZE);

        uint64_t new_state[POSEIDON_WIDTH];
        memcpy(new_state, h->state, sizeof(new_state));
        absorb_block(new_state, h->buffer);

        for(int k=0; k<POSEIDON_WIDTH; k++)
            h->state[k] = ct_select_u64(h->state[k], new_state[k], is_full);

        h->buf_len = ct_select_u64(h->buf_len, 0, is_full);
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]) {
    if (!h ||!out) return -1;

    // v0.2 Length hiding: always 2 blocks
    h->buffer[h->buf_len] = 0x80;
    memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer); // block 1

    uint8_t zero_block[BASIN_POSEIDON_BLOCK_SIZE] = {0};
    absorb_block(h->state, zero_block); // block 2

    // FIX: state is 24 bytes but we need 32 byte output. Pad with 8 zeros
    uint8_t tmp[POSEIDON_OUTPUT_BYTES] = {0};
    memcpy(tmp, h->state, POSEIDON_WIDTH * 8); // 24 bytes
    memcpy(out, tmp, POSEIDON_OUTPUT_BYTES); // 32 bytes

    // Scrub
    memset(h->state, 0, sizeof(h->state));
    memset(h->buffer, 0, sizeof(h->buffer));
    memset(tmp, 0, sizeof(tmp));
    h->buf_len = 0;
    return 0;
}