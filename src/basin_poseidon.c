#include "basin.h"
#include <string.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_BLOCK_SIZE 24

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
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
    if (h->buf_len < BASIN_POSEIDON_BLOCK_SIZE) {
        h->buffer[h->buf_len] = 0x80;
        memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
        absorb_block(h->state, h->buffer);
    }

    memcpy(out, h->state, POSEIDON_OUTPUT_BYTES);
    return 0;
}
