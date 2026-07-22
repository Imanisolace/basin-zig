#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

#define BLOCK_SIZE BASIN_POSEIDON_BLOCK_SIZE
#define WIDTH BASIN_POSEIDON_WIDTH

static inline uint64_t sbox(uint64_t x) {
    return x * x * x * x * x; // x^5 mod 2^64
}

static void mds_mul(uint64_t s[WIDTH]) {
    uint64_t t0 = s[0] + s[1] + s[2];
    uint64_t t1 = s[0] + s[1]*2 + s[2]*3;
    uint64_t t2 = s[0] + s[1]*4 + s[2]*9;
    s[0] = t0; s[1] = t1; s[2] = t2;
}

static void poseidon_permute(uint64_t s[WIDTH]) {
    for(int r = 0; r < POSEIDON_ROUNDS; r++) {
        int off = r * WIDTH;
        s[0] += POSEIDON_RC[off + 0];
        s[1] += POSEIDON_RC[off + 1];
        s[2] += POSEIDON_RC[off + 2];

        if(r < POSEIDON_RF/2 || r >= POSEIDON_RF/2 + POSEIDON_RP) {
            s[0] = sbox(s[0]);
            s[1] = sbox(s[1]);
            s[2] = sbox(s[2]);
        } else {
            s[0] = sbox(s[0]);
        }
        mds_mul(s);
    }
}

static void absorb_block(uint64_t s[WIDTH], const uint8_t block[BLOCK_SIZE]) {
    uint64_t w0, w1;
    memcpy(&w0, block, 8);
    memcpy(&w1, block + 8, 8);
    s[0] ^= w0;
    s[1] ^= w1;
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
        size_t space = BLOCK_SIZE - h->buf_len;
        size_t to_copy = (len - i < space)? (len - i) : space;
        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;
        if (h->buf_len == BLOCK_SIZE) {
            absorb_block(h->state, h->buffer);
            poseidon_permute(h->state);
            h->buf_len = 0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[BASIN_POSEIDON_OUTPUT_BYTES]) {
    if (!h ||!out) return -1;
    h->buffer[h->buf_len] = 0x01;
    if (h->buf_len + 1 < BLOCK_SIZE) {
        memset(h->buffer + h->buf_len + 1, 0, BLOCK_SIZE - h->buf_len - 1);
    }
    h->buffer[BLOCK_SIZE - 1] |= 0x80;
    absorb_block(h->state, h->buffer);
    poseidon_permute(h->state);
    for(int i = 0; i < 8; i++) out[i] = (uint8_t)(h->state[0] >> (8*i));
    for(int i = 0; i < 8; i++) out[8+i] = (uint8_t)(h->state[1] >> (8*i));
    memset(out + 16, 0, 16);
    memset(h, 0, sizeof(*h));
    return 0;
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output) return -1;
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}
