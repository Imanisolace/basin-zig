#include "basin.h"
#include <string.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_OUTPUT_BYTES 32

static void poseidon_permute(uint64_t state[POSEIDON_WIDTH]) {
    for(int r = 0; r < 8; r++) {
        for(int i = 0; i < POSEIDON_WIDTH; i++) {
            state[i] ^= state[(i+1)%POSEIDON_WIDTH] + (uint64_t)r;
            state[i] = (state[i] << 13) | (state[i] >> 51);
        }
    }
}

int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if(!input ||!output) return -1;
    
    uint64_t state[POSEIDON_WIDTH] = {0};
    
    // Absorb input in 24-byte chunks safely
    for(size_t i = 0; i < input_len; i += 24) {
        for(int j = 0; j < POSEIDON_WIDTH; j++) {
            size_t offset = i + j*8;
            if(offset >= input_len) break; // <-- this was missing
            
            uint64_t chunk = 0;
            size_t copy_len = (offset + 8 <= input_len)? 8 : (input_len - offset);
            memcpy(&chunk, input + offset, copy_len);
            state[j] ^= chunk;
        }
        poseidon_permute(state);
    }
    
    memcpy(output, state, POSEIDON_OUTPUT_BYTES);
    return 0;
}