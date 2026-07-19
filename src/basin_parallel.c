#include "basin.h"

// Dummy parallel - just runs single thread for now
int basin_parallel_process(const uint8_t* data, size_t len, int threads) {
    if (!data) return -1;
    (void)threads; // ignore for now
    (void)len;
    
    // TODO: add real threading later
    return 0;
}
