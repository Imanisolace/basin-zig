#include "basin.h"
#include <string.h>

// Simple Poseidon2 over 3x 64-bit limbs. Not cryptographically optimized yet.
// For v0.1 we just need "it works + it's fast". We'll optimize rounds later.
#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    // Placeholder round function: xorshift + add. 
    // Replace with real S-box + MDS later. For now: deterministic + fast
    for(int r = 0; r < 8; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] ^= state[(i+1)%POSEIDON_WIDTH] + r;
            state[i] = (state[i] << 13) | (state[i] >> 51); // rotate
        }
    }
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output) return -1;
    
    uint64_t state[POSEIDON_WIDTH] = {0};
    
    // Absorb input in 24-byte chunks
    for(size_t i = 0; i < input_len; i += 24) {
        for(int j = 0; j < POSEIDON_WIDTH; j++) {
            uint64_t chunk = 0;
            size_t copy_len = (i + j*8 + 8 <= input_len)? 8 : (input_len - (i + j*8));
            if(copy_len > 0) memcpy(&chunk, input + i + j*8, copy_len);
            state[j] ^= chunk;
        }
        poseidon_permute(state);
    }
    
    // Squeeze output
    memcpy(output, state, POSEIDON_OUTPUT_BYTES);
    return 0;
}