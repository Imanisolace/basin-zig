#pragma once
#include <stdint.h>

#define POSEIDON_WIDTH 3
#define POSEIDON_RF 8
#define POSEIDON_RP 57
#define POSEIDON_ROUNDS (POSEIDON_RF + POSEIDON_RP)

static const uint64_t POSEIDON_MDS[3][3] = {
    {1, 2, 3},
    {2, 3, 1},
    {3, 1, 2}
};

static const uint64_t POSEIDON_RC[195] = {
(uint64_t)0x634d5091dbd3a18f,(uint64_t)0x43ffd736c6291a4b,(uint64_t)0x1ae0c5f3ff4012cc,(uint64_t)0x63d30993af6dec13,(uint64_t)0x43bcf68820e1051d,(uint64_t)0x1a53500a999909e7,
(uint64_t)0x1a9a5c4f2d3e1b09,(uint64_t)0x2b8b6d5e3c4f2a1a,(uint64_t)0x3c9c7e6f4d5a3b2b,(uint64_t)0x4dad8f7a5e6b4c3c,(uint64_t)0x5ebe90b6f7c5d4d,(uint64_t)0x6fcf0a1c8096e5e,
(uint64_t)0x70e01b2d9187f6f,(uint64_t)0x81f12c3ea298070,(uint64_t)0x93023d4fb3a9181,(uint64_t)0xa4134e5cc4ba292,(uint64_t)0xb5245f6dd5cb3a3,(uint64_t)0xc63570e7e6dc4b4,
(uint64_t)0xd74681f8f7ed5c5,(uint64_t)0xe85792f908fe6d6,(uint64_t)0xf968a30a19af7e7,(uint64_t)0x0a79b41b2ab0808,(uint64_t)0x1b8ac52c3bc1c19,(uint64_t)0x2c9bd63d4cd2d2a,
(uint64_t)0x3dace74e5de3e3b,(uint64_t)0x4ebdf85f6ef4f4c,(uint64_t)0x5fce09570aff05d,(uint64_t)0x60df1a681b10016e,(uint64_t)0x71f02b792c21127f,(uint64_t)0x83013c8a3d322390,
(uint64_t)0x94124d9b4e4334a1,(uint64_t)0xa5235eac5f5445b2,(uint64_t)0xb6346fbd607565c3,(uint64_t)0xc74580ce718676d4,(uint64_t)0xd85691df829787e5,(uint64_t)0xe967a2f093a898f6,
(uint64_t)0xfa78b301a4b9a907,(uint64_t)0x0b89c412b5cacb18,(uint64_t)0x1c9ad523c6dbdc29,(uint64_t)0x2dabc634d7eced3a,(uint64_t)0x3ebcd745e8fdfe4b,(uint64_t)0x4fcd0e560f0e0f5c,
(uint64_t)0x60de1f67101f206d,(uint64_t)0x71ef307821302e7e,(uint64_t)0x8300418921323f8f,(uint64_t)0x9411529a32434a90,(uint64_t)0xa56263ab43554ba1,(uint64_t)0xb67374bc54665cb2,
(uint64_t)0xc78485cd65776dc3,(uint64_t)0xd89596de76887ed4,(uint64_t)0xe9a6a7ef87a98fe5,(uint64_t)0xfab7b8f098ba9af6,(uint64_t)0x0bc8c9f1a9cbab07,(uint64_t)0x1cd9daf0bacbd18,
(uint64_t)0x2deafb01cbdce229,(uint64_t)0x3efb0c12dcedf33a,(uint64_t)0x4f0c1d23efde044b,(uint64_t)0x601d2e34f0ef155c,(uint64_t)0x712e3f4521f0266d,(uint64_t)0x823f50463211037e,
(uint64_t)0x935061472143148f,(uint64_t)0xa47172581532525a,(uint64_t)0xb5828369264363b,(uint64_t)0xc69394a9375474c,(uint64_t)0xd7a4a5b8486585d,(uint64_t)0xe8b5b6c9597696e,
(uint64_t)0xf9c6c7da6a87a7f,(uint64_t)0x0ad7d8eb7b98b80,(uint64_t)0x1be8e9fc8ca9c91,(uint64_t)0x2cf9fad9daabaa2,(uint64_t)0x3e0a0beaebbcbbb3,(uint64_t)0x4f1b1cfbccdcdcc4,
(uint64_t)0x602c2d0cdddeddd5,(uint64_t)0x713d3e1deeeefee6,(uint64_t)0x824e4f2effffff7,(uint64_t)0x935f60604010108,(uint64_t)0xa47071415121219,(uint64_t)0xb58182526232322a,
(uint64_t)0xc69293736343433b,(uint64_t)0xd7a3a4747474544c,(uint64_t)0xe8b4b585858565d,(uint64_t)0xf9c5c696969676e,(uint64_t)0x0ad6d7a7a7a8787f,(uint64_t)0x1be7e8b8b8b9890,
(uint64_t)0x2cf8f9c9c9cac9a1,(uint64_t)0x3e090adbbab2,(uint64_t)0x4f1a1bebebecbc3c,(uint64_t)0x602b2cfdcdd4,(uint64_t)0x713c3d0d0d0eede5,(uint64_t)0x824d4e1e1e1f0ef6,
(uint64_t)0x935e5f2f2f303007,(uint64_t)0xa46f706060414118,(uint64_t)0xb580817171525229,(uint64_t)0xc69192828263633a,(uint64_t)0xd7a2a39393974744b,(uint64_t)0xe8b3b4a4a4a8585c,
(uint64_t)0xf9c4c5b5b5b9696d,(uint64_t)0x0ad5d6c6c6cac77e,(uint64_t)0x1be6e7d7d7dbd88f,(uint64_t)0x2cf7f8e8e8ece990,(uint64_t)0x3e0809f9f9fdfaa1,(uint64_t)0x4f191a0a0b0e0bb2,
(uint64_t)0x602a2b1b1c1f1cc3,(uint64_t)0x713b3c2c2d3030d4,(uint64_t)0x824c4d3d3e4141e5,(uint64_t)0x935d5e4e4f5252f6,(uint64_t)0xa46e6f5f60636307,(uint64_t)0xb57f807070747418,
(uint64_t)0xc690918181858529,(uint64_t)0xd7a1a2929296963a,(uint64_t)0xe8b2b3a3a3a7a74b,(uint64_t)0xf9c3c4b4b4b8b85c,(uint64_t)0x0ad4d5c5c5c9c96d,(uint64_t)0x1be5e6d6d6dad77e,
(uint64_t)0x2cf6f7e7e7ebe88f,(uint64_t)0x3e0708f8f8fcf990,(uint64_t)0x4f18190a0b0d0aa1,(uint64_t)0x60292a1b1c1e1bb2,(uint64_t)0x713a3b2c2d2f2cc3,(uint64_t)0x824b4c3d3e4040d4,
(uint64_t)0x935c5d4e4f5151e5,(uint64_t)0xa46d6e5f606262f6,(uint64_t)0xb57e7f7070717307,(uint64_t)0xc68f908080818418,(uint64_t)0xd7a0a19191929229,(uint64_t)0xe8b1b2a2a2a3a33a,
(uint64_t)0xf9c2c3b3b3b4b44b,(uint64_t)0x0ad3d4c4c4c5c55c,(uint64_t)0x1be4e5d5d5d6d66d,(uint64_t)0x2cf5f6e6e6e7e77e,(uint64_t)0x3e0607f7f7f8f88f,(uint64_t)0x4f17180a0b090990,
(uint64_t)0x60281a1b1c1a1aa1,(uint64_t)0x71392b2c2d2b2bb2,(uint64_t)0x824a4b3d3e3c3cc3,(uint64_t)0x935b5c4e4f4d4dd4,(uint64_t)0xa46c6d5f606e5ee5,(uint64_t)0xb57d7e7071726ff6,
(uint64_t)0xc68e8f8081828007,(uint64_t)0xd79f90a091929118,(uint64_t)0xe8b0b1a1a2a3a229,(uint64_t)0xf9c1c2b2b3b4b33a,(uint64_t)0x0ad2d3c3c4c5c44b,(uint64_t)0x1be3e4d4d5d6d55c,
(uint64_t)0x2cf4f5e5e6e7e66d,(uint64_t)0x3e0506f7f8f9f77e,(uint64_t)0x4f16170a0b0a088f,(uint64_t)0x60271a1b1c1b1990,(uint64_t)0x71382b2c2d2c2aa1,(uint64_t)0x82494b3d3e3d3bb2,
(uint64_t)0x935a5c4e4f4e4cc3,(uint64_t)0xa46b6d5f606f5dd4,(uint64_t)0xb57c7e7071806ee5,(uint64_t)0xc68d8f8081907ff6,(uint64_t)0xd79e90a091a19007,(uint64_t)0xe8afb1a1a2a2a118,
(uint64_t)0xf9c0c1b2b3b3b229,(uint64_t)0x0ad1d2c3c4c4c33a,(uint64_t)0x1be2e3d4d5d5d44b,(uint64_t)0x2cf3f4e5e6e6e55c,(uint64_t)0x3e0405f6f7f7f66d,(uint64_t)0x4f15160a0b08077e
};
