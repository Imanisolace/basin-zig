#include "basin_poseidon_rc.h"
#include "basin.h"
#include <string.h>
#include <stdint.h>

#define BLOCK_SIZE 24
#define WIDTH 3

static uint64_t load_le64(const uint8_t* p){uint64_t v;memcpy(&v,p,8);return v;}
static void store_le64(uint8_t* p,uint64_t v){for(int i=0;i<8;i++)p[i]=(v>>(8*i))&0xff;}

static inline uint64_t sbox(uint64_t x){return x*x;}

static void mds(uint64_t s[3]){
    uint64_t t0=s[0]+s[1]+s[2];
    uint64_t t1=s[0]+s[1]*2+s[2]*3;
    uint64_t t2=s[0]+s[1]*4+s[2]*9;
    s[0]=t0;s[1]=t1;s[2]=t2;
}

static void perm(uint64_t s[3]){
    for(int r=0;r<65;r++){
        s[0]+=POSEIDON_RC[r*3+0];
        s[1]+=POSEIDON_RC[r*3+1];
        s[2]+=POSEIDON_RC[r*3+2];
        if(r<4||r>=61){s[0]=sbox(s[0]);s[1]=sbox(s[1]);s[2]=sbox(s[2]);}
        else{s[0]=sbox(s[0]);}
        mds(s);
    }
}

int basin_hasher_init(basin_hasher_t* h){memset(h,0,sizeof(*h));return 0;}

int basin_hasher_update(basin_hasher_t* h,const uint8_t* d,size_t n){
    size_t i=0;
    while(i<n){
        size_t c=BLOCK_SIZE-h->buf_len;
        if(c>n-i)c=n-i;
        memcpy(h->buffer+h->buf_len,d+i,c);
        h->buf_len+=c;i+=c;
        if(h->buf_len==BLOCK_SIZE){
            h->state[0]^=load_le64(h->buffer);
            h->state[1]^=load_le64(h->buffer+8);
            perm(h->state);
            h->buf_len=0;
        }
    }
    return 0;
}

int basin_hasher_final(basin_hasher_t* h,uint8_t out[32]){
    h->buffer[h->buf_len]=0x01;
    memset(h->buffer+h->buf_len+1,0,BLOCK_SIZE-h->buf_len-1);
    h->buffer[BLOCK_SIZE-1]|=0x80;
    h->state[0]^=load_le64(h->buffer);
    h->state[1]^=load_le64(h->buffer+8);
    perm(h->state);
    store_le64(out,h->state[0]);
    store_le64(out+8,h->state[1]);
    memset(out+16,0,16);
    memset(h,0,sizeof(*h));
    return 0;
}

int basin_poseidon_hash(const uint8_t* i,size_t n,uint8_t* o){
    basin_hasher_t h;basin_hasher_init(&h);basin_hasher_update(&h,i,n);return basin_hasher_final(&h,o);
}
