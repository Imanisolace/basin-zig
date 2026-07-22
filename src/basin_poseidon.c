#include "basin.h"
#include <string.h>
#include <stdint.h>

#define WIDTH BASIN_POSEIDON_WIDTH
#define RF 8
#define RP 57
#define ROUNDS 65
#define BLOCK_SIZE BASIN_POSEIDON_BLOCK_SIZE
#define OUTPUT_BYTES BASIN_POSEIDON_OUTPUT_BYTES

#include "basin_poseidon_rc.h"

static uint64_t le64(const uint8_t* p){uint64_t x;memcpy(&x,p,8);return x;}
static void st64(uint8_t* p,uint64_t x){for(int i=0;i<8;i++)p[i]=(uint8_t)(x>>(8*i));}
static uint64_t pow5(uint64_t x){uint64_t x2=x*x;uint64_t x4=x2*x2;return x4*x;}
static void mds(uint64_t s[WIDTH]){uint64_t a=s[0]+s[1]+s[2];uint64_t b=s[0]+s[1]*2+s[2]*3;uint64_t c=s[0]+s[1]*4+s[2]*9;s[0]=a;s[1]=b;s[2]=c;}
static void perm(uint64_t s[WIDTH]){
    for(int r=0;r<ROUNDS;r++){
        int o=r*WIDTH;
        s[0]+=POSEIDON_RC[o+0];
        s[1]+=POSEIDON_RC[o+1];
        s[2]+=POSEIDON_RC[o+2];
        if(r<RF/2||r>=RF/2+RP){
            s[0]=pow5(s[0]);s[1]=pow5(s[1]);s[2]=pow5(s[2]);
        }else{
            s[0]=pow5(s[0]);
        }
        mds(s);
    }
}

// FIX: Use non-zero IV like reference implementation
int basin_hasher_init(basin_hasher_t* h){
    memset(h,0,sizeof(*h));
    h->state[0] = 0x736962206e697361ULL; // "basin "
    h->state[1] = 0x6e6f736570206e6fULL; // "on pose"
    h->state[2] = 0x646f6e206449ULL; // "idonI"
    return 0;
}

int basin_hasher_update(basin_hasher_t* h,const uint8_t* d,size_t n){size_t i=0;while(i<n){size_t c=BLOCK_SIZE-h->buf_len;if(c>n-i)c=n-i;memcpy(h->buffer+h->buf_len,d+i,c);h->buf_len+=c;i+=c;if(h->buf_len==BLOCK_SIZE){h->state[0]^=le64(h->buffer);h->state[1]^=le64(h->buffer+8);perm(h->state);h->buf_len=0;}}return 0;}
int basin_hasher_final(basin_hasher_t* h,uint8_t o[OUTPUT_BYTES]){h->buffer[h->buf_len]=1;memset(h->buffer+h->buf_len+1,0,BLOCK_SIZE-h->buf_len-1);h->buffer[BLOCK_SIZE-1]|=0x80;h->state[0]^=le64(h->buffer);h->state[1]^=le64(h->buffer+8);perm(h->state);st64(o,h->state[0]);st64(o+8,h->state[1]);memset(o+16,0,16);memset(h,0,sizeof(*h));return 0;}
int basin_poseidon_hash(const uint8_t* i,size_t n,uint8_t* o){basin_hasher_t h;basin_hasher_init(&h);basin_hasher_update(&h,i,n);return basin_hasher_final(&h,o);}
