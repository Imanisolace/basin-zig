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

#ifdef __cplusplus
}
#endif

#endif // BASIN_H
