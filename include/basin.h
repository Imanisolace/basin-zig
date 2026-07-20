#ifndef BASIN_H
#define BASIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BASIN_POSEIDON_BLOCK_SIZE 24
#define BASIN_POSEIDON_OUTPUT_BYTES 32
#define BASIN_POSEIDON_WIDTH 3

// Basin config
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t channels;
} BasinConfig;

// Init / Free
int basin_init(BasinConfig* cfg);
void basin_free(void);

// Poseidon hash: one-shot
int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output);

// Parallel processing
int basin_parallel_process(const uint8_t* data, size_t len, int threads);

// === STREAMING API ===
typedef struct {
    uint64_t state[BASIN_POSEIDON_WIDTH];
    uint8_t buffer[BASIN_POSEIDON_BLOCK_SIZE];
    size_t buf_len;
} basin_hasher_t;

// Initialize a new hasher
int basin_hasher_init(basin_hasher_t* h);

// Absorb more data. Can be called multiple times
int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len);

// Finalize and write 32-byte hash to out
int basin_hasher_final(basin_hasher_t* h, uint8_t out[BASIN_POSEIDON_OUTPUT_BYTES]);

#ifdef __cplusplus
}
#endif

#endif // BASIN_H
