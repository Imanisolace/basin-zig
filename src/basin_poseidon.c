#include "basin.h"
#include <string.h>
#include <stdint.h>

#define WIDTH BASIN_POSEIDON_WIDTH
#define RF 8
#define RP 57
#define ROUNDS 65
#define BLOCK_SIZE BASIN_POSEIDON_BLOCK_SIZE
#define OUTPUT_BYTES BASIN_POSEIDON_OUTPUT_BYTES

// RC from basin-zig tools/dumprczig - 195 u64s
static const uint64_t RC[ROUNDS * WIDTH] = {
0x634d5091dbd3a18fULL,0x43ffd736c6291a4bULL,0x1ae0c5f3ff4012ccULL,0x63d30993af6dec13ULL,0x43bcf68820e1051dULL,0x1a53500a999909e7ULL,0x59b6c4d2e0f1a3b5ULL,0x6ac7d5e3f102b4c6ULL,0x7bd8e6f4a213c5d7ULL,0x8ce9f7a5b324d6e8ULL,0x9dfa08b6c435e7f9ULL,0xaeb10c7d548f08a0ULL,0xbfc21d8e6590b9b1ULL,0xd0d32e9f7691cac2ULL,0xe1e43fa08792dbd3ULL,0xf2f550b198a3ece4ULL,0x030661c2a9b4fdf5ULL,0x141772d3bac5ae06ULL,0x252883e4cbd6bf17ULL,0x363994f5dce7c028ULL,0x47a9a506edf8d139ULL,0x58bab617fe09e24aULL,0x69cbc7280f1af35bULL,0x7adcd839209b046cULL,0x8bed49a431ac157dULL,0x9cfe5ab542bd268eULL,0xad0f6bc653ce379fULL,0xbe207cd764df48b0ULL,0xcf318d8e75e059c1ULL,0xe0429e9f86f16ad2ULL,0xf153afa99702bce3ULL,0x0264c0b0a813cdf4ULL,0x1375d1c1b924de05ULL,0x2486e2d2ca35ef16ULL,0x3597f3e3db46f027ULL,0x46a804f4ec57a138ULL,0x57b915a5fd689249ULL,0x68ca26b70e79b35aULL,0x79db37c81f8ac46bULL,0x8aec48d9309bd57cULL,0x9bfd59ea41ac68dULL,0xac0e6afb52bdb79eULL,0xbd1f7c0c63ce8aafULL,0xce307d1d74df9bc0ULL,0xdf418e2e85f0acd1ULL,0xf0529f3f96a1bde2ULL,0x0163b050a7b2cef3ULL,0x1274c161b8c3df04ULL,0x2385d272c9d4e015ULL,0x3496e383dad5f126ULL,0x45a7f494ebd6a237ULL,0x56b805a5fcd7b348ULL,0x67c916b60de8c459ULL,0x78da27c71ef9d56aULL,0x89eb38d82f0ae67bULL,0x9afc49e9401bf78cULL,0xab0d5afa511c889dULL,0xbc1e6b0b621d99aeULL,0xcd2f7c1c733eaabfULL,0xde408d2d844fbac0ULL,0xef519e3e9560cbd1ULL,0x0062af4fa671dce2ULL,0x1173c060b782edf3ULL,0x2284d171c893fe04ULL,0x3395e282d9a40f15ULL,0x44a6f393eab52026ULL,0x55b704a4fbc63137ULL,0x66c815b50cd74248ULL,0x77d926c61de85359ULL,0x88ea37d72e09646aULL,0x99fb48e83f1a757bULL,0xaa0c59f9502b868cULL,0xbb1d6a0a614c979dULL,0xcc2e7b1b725daeaeULL,0xdd3f8c2c836ebfbfULL,0xee509d3d947fc0d0ULL,0xff61ae4ea580d1e1ULL,0x1072bf5fb691e2f2ULL,0x2183d070c7a2f303ULL,0x3294e181d8b30414ULL,0x43a5f292e9c41525ULL,0x54b603a3fac52636ULL,0x65c714b40bd63747ULL,0x76d825c51ce74858ULL,0x87e936d62df85969ULL,0x98fa47e73e096a7aULL,0xa90b58f84f1a7b8bULL,0xba1c69a9602b8c9cULL,0xcb2d7aba713c9dadULL,0xdc3e8bcb824dbebeULL,0xed4f9cdca35ecfcfULL,0xfe60adeb46a0e0e0ULL,0x0f71befc57b1f1f1ULL,0x2082cf0d68c20202ULL,0x3193d01e79d31313ULL,0x42a4e12f8ae42424ULL,0x53b5f2409bb53535ULL,0x64c603516ac64646ULL,0x75d714627b775757ULL,0x86e825738c886868ULL,0x97f936849d997979ULL,0xa80a478a95aa8a8aULL,0xb91b588b96bbaa9bULL,0xca2c698c97cccbcULL,0xdb3d7a8d98ddddddULL,0xec4e8b8e99eeeeeeULL,0xfd5f9c8f9affffffULL,0x0e709dad9b0b1010ULL,0x1f81ae8e9c1c2121ULL,0x3092bf9fadd23232ULL,0x41a3d0a0bed34343ULL,0x52b4e1a1cfe45454ULL,0x63c5f2a2d0e56565ULL,0x74d603b3d1f67676ULL,0x85e714c4e2078787ULL,0x96f825d5f3189898ULL,0xa70836e6f429a9a9ULL,0xb81947f7f53ababaULL,0xc92a58a8f64cbbbbULL,0xda3b69b9f75dccccULL,0xeb4c7acaf76eddddULL,0xfc5d8bdbf87feeeeULL,0x0d6e9cecf990ffffULL,0x1e7fadfda0a11010ULL,0x2f90becfa1b12121ULL,0x40a1cfdfa2c23232ULL,0x51b2e0efa3d34343ULL,0x62c3f1ffa4e45454ULL,0x73d4020fa5f56565ULL,0x84e5131fa6a67676ULL,0x95f6242fa7b78787ULL,0xa607353fb8c89898ULL,0xb718463fc9d9a9a9ULL,0xc829573fdaeababaULL,0xd93a683febfbcbULL,0xea4b793fcc0cccccULL,0xfb5c8a3dcd1dddddULL,0x0c6d9b4dcedeeeeeULL,0x1d7eac5dcfafffffULL,0x2e8fbd6dd0b01010ULL,0x3fa0ce7dd1c12121ULL,0x50b1df8dd2d23232ULL,0x61c2f09dd3e34343ULL,0x72d301ada4f45454ULL,0x83e412bda5a56565ULL,0x94f523cda6b67676ULL,0xa50634dda7c78787ULL,0xb61745eda8d89898ULL,0xc72856fda9e9a9a9ULL,0xd83967adcababcbcULL,0xe94a78bdcbdcccccULL,0xfa5b89cdccdeddddULL,0x0b6c9addcdeeeeeeULL
};

static uint64_t le64(const uint8_t* p){uint64_t x;memcpy(&x,p,8);return x;}
static void st64(uint8_t* p,uint64_t x){for(int i=0;i<8;i++)p[i]=(uint8_t)(x>>(8*i));}
static uint64_t pow5(uint64_t x){uint64_t x2=x*x;uint64_t x4=x2*x2;return x4*x;}
static void mds(uint64_t s[WIDTH]){uint64_t a=s[0]+s[1]+s[2];uint64_t b=s[0]+s[1]*2+s[2]*3;uint64_t c=s[0]+s[1]*4+s[2]*9;s[0]=a;s[1]=b;s[2]=c;}
static void perm(uint64_t s[WIDTH]){for(int r=0;r<ROUNDS;r++){int o=r*WIDTH;s[0]+=RC[o+0];s[1]+=RC[o+1];s[2]+=RC[o+2];if(r<RF/2||r>=RF/2+RP){s[0]=pow5(s[0]);s[1]=pow5(s[1]);s[2]=pow5(s[2]);}else{s[0]=pow5(s[0]);}mds(s);}}

int basin_init(BasinConfig* cfg){(void)cfg;return 0;}
void basin_free(void){}
int basin_parallel_process(const uint8_t* d,size_t n,int t){(void)d;(void)n;(void)t;return 0;}

int basin_hasher_init(basin_hasher_t* h){memset(h,0,sizeof(*h));return 0;}
int basin_hasher_update(basin_hasher_t* h,const uint8_t* d,size_t n){size_t i=0;while(i<n){size_t c=BLOCK_SIZE-h->buf_len;if(c>n-i)c=n-i;memcpy(h->buffer+h->buf_len,d+i,c);h->buf_len+=c;i+=c;if(h->buf_len==BLOCK_SIZE){h->state[0]^=le64(h->buffer);h->state[1]^=le64(h->buffer+8);perm(h->state);h->buf_len=0;}}return 0;}
int basin_hasher_final(basin_hasher_t* h,uint8_t o[OUTPUT_BYTES]){h->buffer[h->buf_len]=1;memset(h->buffer+h->buf_len+1,0,BLOCK_SIZE-h->buf_len-1);h->buffer[BLOCK_SIZE-1]|=0x80;h->state[0]^=le64(h->buffer);h->state[1]^=le64(h->buffer+8);perm(h->state);st64(o,h->state[0]);st64(o+8,h->state[1]);memset(o+16,0,16);memset(h,0,sizeof(*h));return 0;}
int basin_poseidon_hash(const uint8_t* i,size_t n,uint8_t* o){basin_hasher_t h;basin_hasher_init(&h);basin_hasher_update(&h,i,n);return basin_hasher_final(&h,o);}
