#include "basin.h"
#include <string.h>

// Dummy Poseidon hash - replace with real impl later
int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output) {
    if (!input || !output) return -1;
    
    // Just fill output with 0s for now so it compiles
    memset(output, 0, 32);
    return 0;
}
