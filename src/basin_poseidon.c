#include "basin.h"
#include <string.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_BLOCK_SIZE 24

// CT helper: select a or b based on mask 0 or 0xFF..FF
static inline uint64_t ct_select_u64(uint64_t a, uint64_t b, uint64_t mask) {
    return (a & ~mask) | (b & mask);
}

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
#ifdef CONSTANT_TIME
    #pragma message "Compiling basin in CONSTANT-TIME mode. Using fixed-time permute."
#endif
    for(int r = 0; r < 8; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] ^= state[(i+1)%POSEIDON_WIDTH] + (uint64_t)r;
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
    // TODO v0.2: make error handling constant-time. For now just check
    if(!input ||!output) return -1;

    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}

// === NEW STREAMING API ===
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
        if (to_copy > len - i) to_copy = len - i;

        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;

        // Buffer full: absorb and permute
        // TODO v0.2: make this branchless with ct_select
        if (h->buf_len == BASIN_POSEIDON_BLOCK_SIZE) {
            absorb_block(h->state, h->buffer);
            h->buf_len = 0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]) {
    if (!h ||!out) return -1;

    // Pad: 0x80 + zeros
    // TODO v0.2: always absorb 2 blocks to hide length
    if (h->buf_len < BASIN_POSEIDON_BLOCK_SIZE) {
        h->buffer[h->buf_len] = 0x80;
        memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
        absorb_block(h->state, h->buffer);
    }

#ifdef CONSTANT_TIME
    // v0.2: always copy full 32 bytes + scrub state
    memcpy(out, h->state, POSEIDON_OUTPUT_BYTES);
    memset(h->state, 0, sizeof(h->state));
#else
    memcpy(out, h->state, POSEIDON_OUTPUT_BYTES);
#endif
    return 0;
}
