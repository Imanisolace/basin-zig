#include "basin.h"
#include "basin_poseidon_rc.h" // contains RC + MDS
#include <string.h>
#include <stdint.h>

#define WIDTH 3
#define RF 8
#define RP 56
#define ROUNDS 64
#define BLOCK_SIZE 24
#define OUTPUT_BYTES 32

static inline uint64_t be64(const uint8_t* p){
    uint64_t x = 0;
    for(int i=0;i<8;i++) x = (x<<8) | p[i];
    return x;
}
static inline void st64(uint8_t* p,uint64_t x){
    for(int i=7;i>=0;i--){ p[i]=(uint8_t)x; x>>=8; }
}
static inline uint64_t pow5(uint64_t x){uint64_t x2=x*x;return x2*x2*x;}

static inline void mds(uint64_t s[3]){
    uint64_t t0 = s[0]*BASIN_POSEIDON_MDS[0][0] + s[1]*BASIN_POSEIDON_MDS[0][1] + s[2]*BASIN_POSEIDON_MDS[0][2];
    uint64_t t1 = s[0]*BASIN_POSEIDON_MDS[1][0] + s[1]*BASIN_POSEIDON_MDS[1][1] + s[2]*BASIN_POSEIDON_MDS[1][2];
    uint64_t t2 = s[0]*BASIN_POSEIDON_MDS[2][0] + s[1]*BASIN_POSEIDON_MDS[2][1] + s[2]*BASIN_POSEIDON_MDS[2][2];
    s[0]=t0; s[1]=t1; s[2]=t2;
}

static void perm(uint64_t s[3]){
    for(int r=0;r<ROUNDS;r++){
        int o=r*3;
        s[0]+=BASIN_POSEIDON_RC[o+0]; s[1]+=BASIN_POSEIDON_RC[o+1]; s[2]+=BASIN_POSEIDON_RC[o+2];
        if(r<RF/2 || r>=RF/2+RP){ // Full rounds
            s[0]=pow5(s[0]); s[1]=pow5(s[1]); s[2]=pow5(s[2]);
        }
        else{ // Partial rounds
            s[0]=pow5(s[0]);
        }
        mds(s);
    }
}

//... rest of your hasher code is good. BE is correct for Circom
