#include "basin.h"
#include "basin_poseidon_rc.h"

static void permute(uint64_t s[3]) {
    for(int r=0; r<195; r++) {
        // add RC
        s[0] += POSEIDON_RC[r*3+0];
        s[1] += POSEIDON_RC[r*3+1];
        s[2] += POSEIDON_RC[r*3+2];

        // SBOX
        for(int i=0;i<3;i++) {
            uint64_t x = s[i];
            s[i] = x*x; s[i]*=s[i]; s[i]*=x; // x^5
        }

        // MDS
        uint64_t t0 = s[0]*POSEIDON_MDS[0][0] + s[1]*POSEIDON_MDS[0][1] + s[2]*POSEIDON_MDS[0][2];
        uint64_t t1 = s[0]*POSEIDON_MDS[1][0] + s[1]*POSEIDON_MDS[1][1] + s[2]*POSEIDON_MDS[1][2];
        uint64_t t2 = s[0]*POSEIDON_MDS[2][0] + s[1]*POSEIDON_MDS[2][1] + s[2]*POSEIDON_MDS[2][2];
        s[0]=t0; s[1]=t1; s[2]=t2;
    }
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    uint64_t state[3] = {0};
    // simple absorb: pad to 24 bytes, xor in
    uint8_t block[24] = {0};
    size_t copy = input_len > 24? 24 : input_len;
    for(size_t i=0;i<copy;i++) block[i] = input[i];
    block[copy] = 0x01; // padding

    for(int i=0;i<3;i++) state[i] ^= ((uint64_t*)block)[i];
    permute(state);

    for(int i=0;i<4;i++) ((uint64_t*)output)[i] = state[i%3]; // expand to 32 bytes
    return 0;
}
