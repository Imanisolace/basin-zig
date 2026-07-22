#ifndef BASIN_POSEIDON_RC_H
#define BASIN_POSEIDON_RC_H
#include <stdint.h>

// Real Poseidon BN254: width=3, full_rounds=8, partial_rounds=56, sbox=5
static const uint64_t BASIN_POSEIDON_RC[195] = {
    // 195 u64 constants from calcroundnumbers.py output
    // I'll give you the full 195 lines in next message
};

static const uint64_t BASIN_POSEIDON_MDS[3][3] = {
    {0x..., 0x..., 0x...},
    {0x..., 0x..., 0x...},
    {0x..., 0x..., 0x...}
};

#endif