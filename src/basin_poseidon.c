#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

static uint64_t load_le64(const uint8_t* p) {
    uint64_t x;
    memcpy(&x, p, 8);
    return x;
}

static void store_le64(uint8_t* p, uint64_t x) {
    for (int i = 0; i < 8; i++) p[i] = (uint8_t)(x >> (8 * i));
}

static inline uint64_t pow5(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x;
}

static void mds_mul(uint64_t s[POSEIDON_WIDTH]) {
    uint64_t t0 = s[0] + s[1] + s[2];
    uint64_t t1 = s[0] + s[1] * 2 + s[2] * 3;
    uint64_t t2 = s[0] + s[1] * 4 + s[2] * 9;
    s[0] = t0;
    s[1] = t1;
    s[2] = t2;
}

static void poseidon_permute(uint64_t s[POSEIDON_WIDTH]) {
    for (int r = 0; r < POSEIDON_ROUNDS; r++) {
        int off = r * POSEIDON_WIDTH;
        s[0] += POSEIDON_RC[off + 0];
        s[1] += POSEIDON_RC[off + 1];
        s[2] += POSEIDON_RC[off + 2];

        if (r < POSEIDON_RF / 2 || r >= POSEIDON_RF / 2 + POSEIDON_RP) {
            s[0] = pow5(s[0]);
            s[1] = pow5(s[1]);
            s[2] = pow5(s[2]);
        } else {
            s[0] = pow5(s[0]);
        }
        mds_mul(s);
    }
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
        size_t to_copy = (len - i < space)? (len - i) : space;
        memcpy(h->buffer + h->buf_len, data + i, to_copy);
        h->buf_len += to_copy;
        i += to_copy;
        if (h->buf_len == BASIN_POSEIDON_BLOCK_SIZE) {
            h->state[0] ^= load_le64(h->buffer);
            h->state[1] ^= load_le64(h->buffer + 8);
            poseidon_permute(h->state);
            h->buf_len = 0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[BASIN_POSEIDON_OUTPUT_BYTES]) {
    if (!h ||!out) return -1;

    h->buffer[h->buf_len] = 0x01;
    if (h->buf_len + 1 < BASIN_POSEIDON_BLOCK_SIZE) {
        memset(h->buffer + h->buf_len + 1, 0, BASIN_POSEIDON_BLOCK_SIZE - h->buf_len - 1);
    }
    h->buffer[BASIN_POSEIDON_BLOCK_SIZE - 1] |= 0x80;

    h->state[0] ^= load_le64(h->buffer);
    h->state[1] ^= load_le64(h->buffer + 8);
    poseidon_permute(h->state);

    store_le64(out, h->state[0]);
    store_le64(out + 8, h->state[1]);
    memset(out + 16, 0, 16);

    memset(h, 0, sizeof(*h));
    return 0;
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if (!input ||!output) return -1;
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}
