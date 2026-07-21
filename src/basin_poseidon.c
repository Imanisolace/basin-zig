#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

#define BLOCK_SIZE 24 // RATE * 8

static inline uint64_t sbox(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x; // x^5
}

static void mds_mul(uint64_t s[POSEIDON_WIDTH]) {
    uint64_t t0 = s[0] + s[1] + s[2];
    uint64_t t1 = s[0] + s[1]*2 + s[2]*3;
    uint64_t t2 = s[0] + s[1]*4 + s[2]*9;
    s[0] = t0; s[1] = t1; s[2] = t2;
}

static void poseidon_permute(uint64_t s[POSEIDON_WIDTH]) {
    for(int r = 0; r < POSEIDON_ROUNDS; r++) {
        int off = r * POSEIDON_WIDTH;
        s[0] += POSEIDON_RC[off + 0];
        s[1] += POSEIDON_RC[off + 1];
        s[2] += POSEIDON_RC[off + 2];

        if(r < POSEIDON_RF/2 || r >= POSEIDON_RF/2 + POSEIDON_RP) { // full
            s[0] = sbox(s[0]);
            s[1] = sbox(s[1]);
            s[2] = sbox(s[2]);
        } else { // partial
            s[0] = sbox(s[0]);
        }
        mds_mul(s);
    }
}

static void absorb_block(uint64_t s[POSEIDON_WIDTH], const uint8_t block[BLOCK_SIZE]) {
    uint64_t w0, w1;
    memcpy(&w0, block, 8);
    memcpy(&w1, block + 8, 8);
    s[0] ^= w0; // RATE = 2
    s[1] ^= w1;
    poseidon_permute(s);
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
            h->buf_len = 0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[BASIN_POSEIDON_OUTPUT_BYTES]) {
    if (!h ||!out) return -1;

    // 10*1 padding
    h->buffer[h->buf_len] = 0x01;
    memset(h->buffer + h->buf_len + 1, 0, BLOCK_SIZE - h->buf_len - 1);
    absorb_block(h->state, h->buffer);

    // final permutation
    poseidon_permute(h->state);

    // Squeeze: s0, s1 LE + 16 zeros = 32 bytes
    for(int i = 0; i < 8; i++) out[i] = (h->state[0] >> (8*i)) & 0xff;
    for(int i = 0; i < 8; i++) out[8+i] = (h->state[1] >> (8*i)) & 0xff;
    memset(out + 16, 0, 16);

    memset(h, 0, sizeof(*h));
    return 0;
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output || input_len == 0) return -1;
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}
