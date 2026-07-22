#include "basin.h"
#include "basin_poseidon_rc.h"
#include <string.h>

static uint64_t pow5(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x;
}

static void permute(uint64_t s[3]) {
    for(int r=0; r<65; r++) {
        s[0] += POSEIDON_RC[r*3 + 0];
        s[1] += POSEIDON_RC[r*3 + 1];
        s[2] += POSEIDON_RC[r*3 + 2];

        s[0] = pow5(s[0]);
        s[1] = pow5(s[1]);
        s[2] = pow5(s[2]);

        uint64_t t0 = s[0] + s[1] + s[2];
        uint64_t t1 = s[0] + s[1] + s[1] + s[2];
        uint64_t t2 = s[0] + s[0] + s[1] + s[2];
        s[0]=t0; s[1]=t1; s[2]=t2;
    }
}

int basin_hasher_init(basin_hasher_t* h) {
    if(!h) return -1;
    h->state[0] = 0;
    h->state[1] = 0;
    h->state[2] = 0;
    h->buf_len = 0;
    memset(h->buffer, 0, BASIN_POSEIDON_BLOCK_SIZE);
    return 0;
}

static void absorb_block(basin_hasher_t* h) {
    for(int i=0; i<3; i++) {
        h->state[i] ^= ((uint64_t*)h->buffer)[i];
    }
    permute(h->state);
    h->buf_len = 0;
    memset(h->buffer, 0, BASIN_POSEIDON_BLOCK_SIZE);
}

int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len) {
    if(!h ||!data) return -1;
    while(len > 0) {
        size_t to_copy = BASIN_POSEIDON_BLOCK_SIZE - h->buf_len;
        if(to_copy > len) to_copy = len;
        memcpy(h->buffer + h->buf_len, data, to_copy);
        h->buf_len += to_copy;
        data += to_copy;
        len -= to_copy;
        if(h->buf_len == BASIN_POSEIDON_BLOCK_SIZE) {
            absorb_block(h);
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]) {
    if(!h ||!out) return -1;
    // padding: 0x01 then zeros
    if(h->buf_len < BASIN_POSEIDON_BLOCK_SIZE) {
        h->buffer[h->buf_len] = 0x01;
    }
    absorb_block(h);

    // squeeze 32 bytes
    ((uint64_t*)out)[0] = h->state[0];
    ((uint64_t*)out)[1] = h->state[1];
    ((uint64_t*)out)[2] = h->state[2];
    ((uint64_t*)out)[3] = h->state[0] ^ h->state[1] ^ h->state[2];
    return 0;
}

// One-shot helper
int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    basin_hasher_t h;
    basin_hasher_init(&h);
    basin_hasher_update(&h, input, input_len);
    return basin_hasher_final(&h, output);
}
