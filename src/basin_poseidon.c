#include <stdint.h>
#include <string.h>
#include "basin_poseidon_rc.h"

static uint64_t pow5(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x; // mod 2^64 overflow is feature
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

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    uint64_t state[3] = {0, 0, 0};
    uint8_t block[24] = {0};

    size_t copy = input_len > 24? 24 : input_len;
    memcpy(block, input, copy);
    if(copy < 24) block = 0x01; // domain sep padding

    for(int i=0; i<3; i++) {
        state[i] ^= ((uint64_t*)block)[i];
    }

    permute(state);

    // 32 byte output
    ((uint64_t*)output)[0] = state[0];
    ((uint64_t*)output)[1] = state[1];
    ((uint64_t*)output)[2] = state[2];
    ((uint64_t*)output)[3] = state[0] ^ state[1] ^ state[2];
    return 0;
}
