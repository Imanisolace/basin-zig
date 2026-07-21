#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

#define POSEIDON_WIDTH 3
#define RATE 2

static inline uint64_t sbox(uint64_t x) {
    uint64_t x2 = x*x; uint64_t x4 = x2*x2; return x4*x;
}

static void mds_mul(uint64_t s[3]) {
    uint64_t t0 = s[0] + s[1] + s[2];
    uint64_t t1 = s[0] + s[1]*2 + s[2]*3;
    uint64_t t2 = s[0] + s[1]*4 + s[2]*9;
    s[0]=t0; s[1]=t1; s[2]=t2;
}

static void permute(uint64_t s[3]) {
    for(int r=0;r<POSEIDON_ROUNDS;r++){
        s[0]+=POSEIDON_RC[r*3+0]; s[1]+=POSEIDON_RC[r*3+1]; s[2]+=POSEIDON_RC[r*3+2];
        if(r<4 || r>=4+POSEIDON_RP){ s[0]=sbox(s[0]); s[1]=sbox(s[1]); s[2]=sbox(s[2]); }
        else{ s[0]=sbox(s[0]); }
        mds_mul(s);
    }
}

static void absorb(uint64_t s[3], const uint8_t b[24]) {
    uint64_t w0,w1; memcpy(&w0,b,8); memcpy(&w1,b+8,8);
    s[0]^=w0; s[1]^=w1; // RATE=2
    permute(s);
}

int basin_hasher_init(basin_hasher_t* h){ memset(h,0,sizeof(*h)); return 0; }

int basin_hasher_update(basin_hasher_t* h, const uint8_t* d, size_t n){
    size_t i=0; while(i<n){
        size_t c = 24 - h->buf_len;
        if(c > n-i) c = n-i;
        memcpy(h->buffer+h->buf_len, d+i, c);
        h->buf_len+=c; i+=c;
        if(h->buf_len==24){ absorb(h->state, h->buffer); h->buf_len=0; }
    } return 0;
}

int basin_hasher_final(basin_hasher_t* h, uint8_t out[32]){
    h->buffer[h->buf_len]=0x80; memset(h->buffer+h->buf_len+1,0,23-h->buf_len);
    absorb(h->state, h->buffer);
    permute(h->state);
    for(int i=0;i<8;i++) out[i]=(h->state[0]>>(8*i))&0xff;
    for(int i=0;i<8;i++) out[8+i]=(h->state[1]>>(8*i))&0xff;
    memset(out+16,0,16); // 2 lanes + 16 zeros = 32 bytes
    memset(h,0,sizeof(*h)); return 0;
}

int basin_poseidon_hash(const uint8_t* in, size_t n, uint8_t* out){
    basin_hasher_t h; basin_hasher_init(&h); basin_hasher_update(&h,in,n); return basin_hasher_final(&h,out);
}
