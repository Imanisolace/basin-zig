#ifndef BASIN_H
#define BASIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Basin config
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t channels;
} BasinConfig;

// Init / Free
int basin_init(BasinConfig* cfg);
void basin_free(void);

// Poseidon hash
int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output);

// Parallel processing
int basin_parallel_process(const uint8_t* data, size_t len, int threads);

// === STREAMING API - ADD THIS ===
#define BASIN_POSEIDON_BLOCK_SIZE 64

typedef struct {
    uint8_t buffer[BASIN_POSEIDON_BLOCK_SIZE];
    size_t buf_len;
} basin_hasher_t;

int basin_hasher_init(basin_hasher_t* h);
int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len);
int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]);

#ifdef __cplusplus
}
#endif

#endif // BASIN_H