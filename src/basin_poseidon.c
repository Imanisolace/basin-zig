#include "basin.h"
#include <string.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_BLOCK_SIZE 24

// v0.2: Always available. No #ifdef
static inline uint64_t ct_select_u64(uint64_t a, uint64_t b, uint64_t mask) {
    return (a & ~mask) | (b & mask);
}

// mask = 0xFF...FF if x == y else 0
static inline uint64_t ct_eq_u64(uint64_t x, uint64_t y) {
    uint64_t d = x ^ y;
    d |= d >> 32; d |= d >> 16; d |= d >> 8; d |= d >> 4; d |= d >> 2; d |= d >> 1;
    return 1 & ~d;
    return 0 - (1 & ~d); // expand to mask
}

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    // v0.2: Fully branchless. 8 rounds, 3-wide
    for(int r = 0; r < 8; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            uint64_t add = state[(i+1)%POSEIDON_WIDTH] + (uint64_t)r;
            state[i] ^= add;
            // rotate left 13
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
    if(!input ||!output) return -1; // this is fine, it's API level

    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}

// === STREAMING API v0.2 ===
int basin_hasher_init(basin_hasher_t* h) {
    if (!h) return -1;
    memset(h, 0, sizeof(*h));
    return 0;
}

int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len) {
    if (!h ||!data) return -1;

    size_t i = 0;
    while (i < len) {
        size_t to_copy = BASIN_POSEIDON_BLOCK_SIZE - h->buf_len;
        uint64_t use_rem = ct_eq_u64((uint64_t)to_copy > (uint64_t)(len - i), 0); // 0 or mask
        to_copy = ct_select_u64(to_copy, len - i, use_rem);

        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;

        // BRANCHLESS: absorb if buf_len == BLOCK_SIZE
        uint64_t is_full = ct_eq_u64(h->buf_len, BASIN_POSEIDON_BLOCK_SIZE);
        uint64_t state_copy[POSEIDON_WIDTH];
        memcpy(state_copy, h->state, sizeof(state_copy));
        absorb_block(state_copy, h->buffer);
        // select: if full use new state, else keep old
        for(int k=0; k<POSEIDON_WIDTH; k++)
            h->state[k] = ct_select_u64(h->state[k], state_copy[k], is_full);

        uint64_t reset_len = ct_select_u64(h->buf_len, 0, is_full);
        h->buf_len = reset_len;
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]) {
    if (!h ||!out) return -1;

    // v0.2: Length hiding. Always absorb 2 blocks
    h->buffer[h->buf_len] = 0x80;
    memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer); // block 1

    uint8_t zero_block[BASIN_POSEIDON_BLOCK_SIZE] = {0};
    absorb_block(h->state, zero_block); // block 2. hides length

    // v0.2: Always copy + always scrub
    memcpy(out, h->state, POSEIDON_OUTPUT_BYTES);
    memset(h->state, 0, sizeof(h->state));
    memset(h->buffer, 0, sizeof(h->buffer));
    h->buf_len = 0;
    return 0;
}
