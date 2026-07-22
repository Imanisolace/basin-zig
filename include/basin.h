#ifndef BASIN_H
#define BASIN_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

#define BASIN_POSEIDON_BLOCK_SIZE 24
#define BASIN_POSEIDON_OUTPUT_BYTES 32

typedef struct {
    uint64_t state[3];
    uint8_t buffer[24];
    size_t buf_len;
} basin_hasher_t;

int basin_hasher_init(basin_hasher_t* h);
int basin_hasher_update(basin_hasher_t* h, const uint8_t* data, size_t len);
int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]);
int basin_poseidon_hash(const uint8_t* input, size_t input_len, uint8_t* output);

#ifdef __cplusplus
}
#endif
#endif
