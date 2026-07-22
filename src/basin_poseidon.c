#include "basin.h"
#include "basin_poseidon_rc.h"

static uint64_t pow5(uint64_t x) {
    uint64_t x2 = x * x;
    uint64_t x4 = x2 * x2;
    return x4 * x;
}

static void permute(uint64_t s[3]) {
    for(int r=0; r<65; r++) { // 65 full rounds for t=3
        // Add round constants
        s[0] += POSEIDON_RC[r*3 + 0];
        s[1] += POSEIDON_RC[r*3 + 1];
        s[2] += POSEIDON_RC[r*3 + 2];

        // S-box
        for(int i=0; i<3; i++) {
            s[i] = pow5(s[i]);
        }

        // MDS
        uint64_t t0 = s[0]*POSEIDON_MDS[0][0] + s[1]*POSEIDON_MDS[0][1] + s[2]*POSEIDON_MDS[0][2];
        uint64_t t1 = s[0]*POSEIDON_MDS[1][0] + s[1]*POSEIDON_MDS[1][1] + s[2]*POSEIDON_MDS[1][2];
        uint64_t t2 = s[0]*POSEIDON_MDS[2][0] + s[1]*POSEIDON_MDS[2][1] + s[2]*POSEIDON_MDS[2][2];
        s[0]=t0; s[1]=t1; s[2]=t2;
    }
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    uint64_t state[3] = {0, 0, 0};

    // Absorb: pad to 24 bytes
    uint8_t block[24] = {0};
    size_t copy = input_len > 24? 24 : input_len;
    for(size_t i=0; i<copy; i++) block[i] = input[i];
    if(copy < 24) block[copy] = 0x01; // padding

    for(int i=0; i<3; i++) {
        state[i] ^= ((uint64_t*)block)[i];
    }

    permute(state);

    // Squeeze to 32 bytes
    for(int i=0; i<4; i++) {
        ((uint64_t*)output)[i] = state[i % 3];
    }
    return 0;
}
