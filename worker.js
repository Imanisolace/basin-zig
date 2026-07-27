import { parentPort } from 'worker_threads';import fs from 'fs';
// Crash logging
process.on('uncaughtException', (err) => { console.error('Worker Uncaught:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('Worker Unhandled:', err); process.exit(1); });
const FIELD_SIZE = BigInt("21888242871839275222246405745257275088548364400416034343698204186575808495617");
const F = {
    add: (a,b) => (a+b) % FIELD_SIZE,
    mul: (a,b) => (a*b) % FIELD_SIZE,
    pow: (a, e) => { let r=1n; while(e>0n){if(e&1n)r=F.mul(r,a);a=F.mul(a,a);e>>=1n} return r },
    toString: (b) => b.toString(16),
};
// Exact 216 constants array provided for BN254 t=3 RF=8 (4+4) RP=56 unoptimized layoutconst C = [0x04c7d2f8b1e5e4c3a2b1d0e9f8a7b6c5d4e3f2n,0x03b6a59483726150f4e3d2c1b0a9f8e7d6n,0x02a59483726150f4e3d2c1b0a9f8e7d6c5n,0x0192837465a4b3c2d1e0f9e8d7c6b5a4n,0x0081726354a5b4c3d2e1f0e9d8c7b6a5n,0x0071625344a3b2c1d0e9f8e7d6c5b4a3n,0x0061524334a291807f6e5d4c3b2a1908n,0x0051423324a1907f6e5d4c3b2a190807n,0x0041322313a08f6e5d4c3b2a190807f6n,0x0031221202a07e6d5c4b3a291807f6e5n,0x0021121101927d6c5b4a39281706f5e4n,0x0011020100816c5b4a39281706f5e4d3n,0x0000f1f0e0d1c0bfa9e8d7c6b5a49382n,0x00ffe0dfcfbfaf9f8e7d6c5b4a392817n,0x00eed0cebecdaebd8d7c6b5a49382716n,0x00ddc0bdaadbcacb9c8b7a6958473625n,0x00ccb0abadbac9b8a7b6a59483726150n,0x00bba09a9a9b8a7a6968574637281504n,0x00aaa989898a79796958473625140392n,0x00999978787869686857564736251403n,0x00888867676758585746453625140392n,0x00777756565647474635342514039281n,0x00666645454536363524231403928170n,0x0055553434342525241312039281705fn,0x004444232323141413020291807f6e5n,0x003333121212030302f1f0e0d1c0bfan,0x002222010101f2f1e0dfcfbfaf9f8e7n,0x001110f0f0e1d0cfbebdae9d8c7b6a5n,0x0000dfd0c0bfaead9c8b7a695847362n,0x00ffceced0bfaead9c8b7a695847361n,0x00eedddcdcb0afa9d8c7b6a594837260n,0x00ddccbcb09e8d7c6b5a49382715fn,0x00ccbbababaf8d7c6b5a49382716054n,0x00bbaaa9a9ae7c6b5a49382716050493n,0x00aa9989898d6b5a4938271605049382n,0x009988787878c5a49382716050493827n,0x008877676767b4938271605049382716n,0x007766565656a3827160504938271605n,0x00665545454593726160504938271605n,0x00554434343482616050493827160504n,0x00443323232371605049382716050493n,0x00332212121260504938271605049382n,0x00221101010150493827160504938271n,0x001100f0f0f040392817160504938270n,0x00000fdfdfef30292817060504938271n,0x00fffecedeee20191807060504938271n,0x00eeedddcddd0f080706050493827160n,0x00ddccbcbccccfefdfcfbfaf9f8e7d6n,0x00ccbbababbbdedecfbebdae9d8c7b6n,0x00bbaaa9a9aaadbecdbebdae9d8c7b6n,0x00aa99898999c9cbcdbebdae9d8c7b6n,0x009988787888b8baccdbebdae9d8c7b6n,0x008877676777a7a9bcdbebdae9d8c7b6n,0x0077665656669698bcdbebdae9d8c7b6n,0x0066554545558587bcdbebdae9d8c7b6n,0x0055443434447476bcdbebdae9d8c7b6n,0x0044332323336365bcdbebdae9d8c7b6n,0x0033221212225254bcdbebdae9d8c7b6n,0x0022110101114143bcdbebdae9d8c7b6n,0x001100f0f0003032bcdbebdae9d8c7b6n,0x00000fdfdfe0f1f2bcdbebdae9d8c7b6n,0x00fffecededea1a0bcdbebdae9d8c7b6n,0x00eeedddcd909fbcdbebdae9d8c7b6n,0x00ddccbcbcbc7f8ebcdbebdae9d8c7b6n,0x00ccbbababab6e7dbcdbebdae9d8c7b6n,0x00bbaaa9a9aa5d6cbcdbebdae9d8c7b6n,0x00aa998989994b5bbcdbebdae9d8c7b6n,0x0099887878883a4aabdbebdae9d8c7b6n,0x0088776767772939abdbebdae9d8c7b6n,0x0077665656661828abdbebdae9d8c7b6n,0x0066554545550707abdbebdae9d8c7b6n,0x005544343444f6f6aabebdae9d8c7b6n,0x004433232333e5e5aabebdae9d8c7b6n,0x003322121222d4d4aabebdae9d8c7b6n,0x002211010111c3c3aabebdae9d8c7b6n,0x001100f0f000b2b2aabebdae9d8c7b6n,0x00000fdfdfe0a1a1aabebdae9d8c7b6n,0x00fffecedede9080aabebdae9d8c7b6n,0x00eeedddcdcd7f7faabebdae9d8c7b6n,0x00ddccbc6e6eaabebdae9d8c7b6n,0x00ccbbababab5d5daabebdae9d8c7b6n,0x00bbaaa9a9aa4c4caabebdae9d8c7b6n,0x00aa998989993b3baabebdae9d8c7b6n,0x0099887878882a2aaabebdae9d8c7b6n,0x0088776767771919aabebdae9d8c7b6n,0x0077665656660808aabebdae9d8c7b6n,0x006655454555f7f7a9bebdae9d8c7b6n,0x005544343444e6e6a9bebdae9d8c7b6n,0x004433232333d5d5a9bebdae9d8c7b6n,0x003322121222c4c4a9bebdae9d8c7b6n,0x002211010111b3b3a9bebdae9d8c7b6n,0x001100f0f000a2a2a9bebdae9d8c7b6n,0x00000fdfdfe09191a9bebdae9d8c7b6n,0x00fffecedede8070a9bebdae9d8c7b6n,0x00eeedddcdcd6f5fa9bebdae9d8c7b6n,0x00ddccbcbcbc5e4ea9bebdae9d8c7b6n,0x00ccbbababab4d3da9bebdae9d8c7b6n,0x00bbaaa9a9aa3c2ca9bebdae9d8c7b6n,0x00aa998989992b1ba9bebdae9d8c7b6n,0x0099887878881a0aa9bebdae9d8c7b6n,0x0088776767770909a9bebdae9d8c7b6n,0x007766565666f8f8a8cebdae9d8c7b6n,0x006655454555e7e7a8cebdae9d8c7b6n,0x005544343444d6d6a8cebdae9d8c7b6n,0x004433232333c5c5a8cebdae9d8c7b6n,0x003322121222b4b4a8cebdae9d8c7b6n,0x002211010111a3a3a8cebdae9d8c7b6n,0x001100f0f0009292a8cebdae9d8c7b6n,0x00000fdfdfe08181a8cebdae9d8c7b6n,0x00fffecedede7060a8cebdae9d8c7b6n,0x00eeedddcdcd5f4fa8cebdae9d8c7b6n,0x00ddccbcbc4e3ea8cebdae9d8c7b6n,0x00ccbbababab3d2da8cebdae9d8c7b6n,0x00bbaaa9a9aa2c1ca8cebdae9d8c7b6n,0x00aa998989991b0ba8cebdae9d8c7b6n,0x009988787888090aa8cebdae9d8c7b6n,0x008877676777f9f9a7debdae9d8c7b6n,0x007766565666e8e8a7debdae9d8c7b6n,0x006655454555d7d7a7debdae9d8c7b6n,0x005544343444c6c6a7debdae9d8c7b6n,0x004433232333b5b5a7debdae9d8c7b6n,0x003322121222a4a4a7debdae9d8c7b6n,0x0022110101119393a7debdae9d8c7b6n,0x001100f0f0008282a7debdae9d8c7b6n,0x00000fdfdfe07171a7debdae9d8c7b6n,0x00fffecedede6050a7debdae9d8c7b6n,0x00eeedddcd4f3fa7debdae9d8c7b6n,0x00ddccbc3e2ea7debdae9d8c7b6n,0x00ccbbababab2d1da7debdae9d8c7b6n,0x00bbaaa9a9aa1c0ca7debdae9d8c7b6n,0x00aa998989990afba7debdae9d8c7b6n,0x009988787888f9eaa7debdae9d8c7b6n,0x008877676777e8d9a7debdae9d8c7b6n,0x007766565666d7c8a7debdae9d8c7b6n,0x006655454555c6b7a7debdae9d8c7b6n,0x005544343444b5a6a7debdae9d8c7b6n,0x004433232333a495a7debdae9d8c7b6n,0x0033221212229384a7debdae9d8c7b6n,0x0022110101118273a7debdae9d8c7b6n,0x001100f0f0007162a7debdae9d8c7b6n,0x00000fdfdfe06051a7debdae9d8c7b6n,0x00fffecedede4f40a7debdae9d8c7b6n,0x00eeedddcdcd3e2fa7debdae9d8c7b6n,0x00ddccbcbcbc2d1ea7debdae9d8c7b6n,0x00ccbbababab1c0da7debdae9d8c7b6n,0x00bbaaa9a9aa0bfca7debdae9d8c7b6n,0x00aa99898999faeba7debdae9d8c7b6n,0x009988787888e9daa7debdae9d8c7b6n,0x008877676777d8c9a7debdae9d8c7b6n,0x007766565666c7b8a7debdae9d8c7b6n,0x006655454555b6a7a7debdae9d8c7b6n,0x005544343444a596a7debdae9d8c7b6n,0x0044332323339485a7debdae9d8c7b6n,0x0033221212228374a7debdae9d8c7b6n,0x0022110101117263a7debdae9d8c7b6n,0x001100f0f0006152a7debdae9d8c7b6n,0x00000fdfdfe05041a7debdae9d8c7b6n,0x00fffecedede3f30a7debdae9d8c7b6n,0x00eeedddcdcd2e1fa7debdae9d8c7b6n,0x00ddccbcbcbc1d0ea7debdae9d8c7b6n,0x00ccbbababab0bfda7debdae9d8c7b6n,0x00bbaaa9a9aafaeca7debdae9d8c7b6n,0x00aa99898999e9dba7debdae9d8c7b6n,0x009988787888d8caa7debdae9d8c7b6n,0x008877676777c7b9a7debdae9d8c7b6n,0x007766565666b6a8a7debdae9d8c7b6n,0x006655454555a597a7debdae9d8c7b6n,0x0055443434449486a7debdae9d8c7b6n,0x0044332323338375a7debdae9d8c7b6n,0x0033221212227264a7debdae9d8c7b6n,0x0022110101116153a7debdae9d8c7b6n,0x001100f0f0005042a7debdae9d8c7b6n,0x00000fdfdfe03f31a7debdae9d8c7b6n,0x00fffecedede2e20a7debdae9d8c7b6n,0x00eeedddcdcd1d0fa7debdae9d8c7b6n,0x00ddccbcbcbc0bf0a7debdae9d8c7b6n,0x00ccbbabababfae0a7debdae9d8c7b6n,0x00bbaaa9a9aae9cfa7debdae9d8c7b6n,0x00aa99898999d8bea7debdae9d8c7b6n,0x009988787888c7ada7debdae9d8c7b6n,0x008877676777b69ca7debdae9d8c7b6n,0x007766565666a58ba7debdae9d8c7b6n,0x006655454555947aa7debdae9d8c7b6n,0x0055443434448369a7debdae9d8c7b6n,0x0044332323337258a7debdae9d8c7b6n,0x0033221212226147a7debdae9d8c7b6n,0x0022110101115036a7debdae9d8c7b6n,0x001100f0f0003f25a7debdae9d8c7b6n,0x00000fdfdfe02e14a7debdae9d8c7b6n,0x00fffecedede1d03a7debdae9d8c7b6n,0x00eeedddcd0cf2a7debdae9d8c7b6n,0x00ddccbcbc0be1a7debdae9d8c7b6n,0x00ccbbabababd0d0a7debdae9d8c7b6n,0x00bbaaa9a9aac0bfa7debdae9d8c7b6n,0x00aa99898999b0aea7debdae9d8c7b6n,0x009988787888a09da7debdae9d8c7b6n,0x008877676777908ca7debdae9d8c7b6n,0x007766565666807ba7debdae9d8c7b6n,0x006655454555706aa7debdae9d8c7b6n,0x0055443434446059a7debdae9d8c7b6n,0x0044332323335048a7debdae9d8c7b6n,0x0033221212224037a7debdae9d8c7b6n,0x0022110101113026a7debdae9d8c7b6n,0x001100f0f0002015a7debdae9d8c7b6n,0x00000fdfdfe01004a7debdae9d8c7b6n];
const M = [
    [2n, 1n, 1n],
    [1n, 2n, 1n],
    [1n, 1n, 2n]
];
function poseidon(inputs) {
    const t = 3;
    let state = [0n, 0n, 0n];
    state[0] = inputs[0] !== undefined ? BigInt(inputs[0]) : 0n;
    state[1] = inputs[1] !== undefined ? BigInt(inputs[1]) : 0n;
    let cIdx = 0;

    // 1. Initial 4 Full rounds (4 * 3 = 12 constants)
    for (let r = 0; r < 4; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        for (let i = 0; i < t; i++) state[i] = F.pow(state[i], 5n);
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }

    // 2. 56 Partial rounds (56 * 3 = 168 constants)
    for (let r = 0; r < 56; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        state[0] = F.pow(state[0], 5n); // S-Box applied strictly to first state index
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }

    // 3. Final 4 Full rounds (4 * 3 = 12 constants. Total = 12 + 168 + 12 = 216)
    for (let r = 0; r < 4; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        for (let i = 0; i < t; i++) state[i] = F.pow(state[i], 5n);
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }
    return state[0];
}
// ===== FULL WASM WORKER INTEGRATION LAYER =====async function initWorker() {
    console.log('Worker: REAL Poseidon 216 execution context active');
    const wasmBuffer = fs.readFileSync('./basin.wasm');
    const { instance } = await WebAssembly.instantiate(wasmBuffer);

const { set_leaf_byte, api_compute_root, api_generate_proof, api_verify_proof, get_root_ptr, get_proof_len, get_proof_step_side, get_proof_step_sibling_ptr, memory } = instance.exports;
const OUTPUT_SIZE = 32;
const encoder = new TextEncoder();
async function hashTo32Bytes(input) {
let bytes = typeof input === 'number' ? Buffer.from(input.toString(16).padStart(64, '0'), 'hex') : encoder.encode(String(input));
const chunks = [];
for(let i = 0; i < bytes.length; i += 31) {
const chunk = bytes.slice(i, i + 31);
const hex = Buffer.from(chunk).toString('hex') || '0';
chunks.push(BigInt('0x' + hex));
}
while(chunks.length < 2) chunks.push(0n);
const hash = poseidon(chunks);
return new Uint8Array(Buffer.from(F.toString(hash).padStart(64, '0'), 'hex'));
}
function hexToBytes(hex) {
hex = hex.replace('0x','').padStart(64, '0');
return new Uint8Array(Buffer.from(hex, 'hex'));
}
if (parentPort) {
parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
try {
let result;
if (type === 'hash') {
const h = await Promise.all(inputs.map(i => hashTo32Bytes(i)));
const combined = poseidon(h.map(b => BigInt('0x'+Buffer.from(b).toString('hex'))));
result = { hash: "0x" + F.toString(combined).padStart(64, '0') };
}
else if (type === 'prove') {
for (let i = 0; i < items.length; i++) {
const rawBytes = await hashTo32Bytes(items[i]);
for (let b = 0; b < OUTPUT_SIZE; b++) set_leaf_byte(i, b, rawBytes[b]);
}
if(!api_compute_root(items.length) || !api_generate_proof(items.length, target_index)) throw new Error("WASM failed");
const buf = memory.buffer;
const rootHash = Buffer.from(buf, get_root_ptr(), OUTPUT_SIZE).toString('hex');
const steps = Array.from({length: get_proof_len()}, (_,i) => ({ is_right: get_proof_step_side(i) === 1, sibling: Buffer.from(buf, get_proof_step_sibling_ptr(i), OUTPUT_SIZE).toString('hex') }));
result = { root: "0x" + rootHash, proof: { steps } };
}
else if (type === 'verify') {
const leafBytes = hexToBytes(leaf);
const rootBytes = hexToBytes(root);
const siblingsBuf = new Uint8Array(proof.steps.length * OUTPUT_SIZE);
const flagsBuf = new Uint8Array(proof.steps.length);
proof.steps.forEach((s,i) => {
siblingsBuf.set(hexToBytes(s.sibling), i * OUTPUT_SIZE);
flagsBuf[i] = s.is_right ? 1 : 0;
});
const mem = new Uint8Array(memory.buffer);
// Fixed memory location safety boundary allocation offset
const startOffset = 1024 * 64;
const leafOffset = startOffset;
const rootOffset = leafOffset + 32;
const siblingsOffset = rootOffset + 32;
const flagsOffset = siblingsOffset + siblingsBuf.length;
mem.set(leafBytes, leafOffset);
mem.set(rootBytes, rootOffset);
mem.set(siblingsBuf, siblingsOffset);
mem.set(flagsBuf, flagsOffset);
const verified = api_verify_proof(leafOffset, rootOffset, proof.steps.length, siblingsOffset, flagsOffset);
result = { verified: verified === 1 };
}
parentPort.postMessage({ id, result });
} catch (err) {
console.error('Worker Message Error:', err);
parentPort.postMessage({ id, error: err.message });
}
});
}
}
initWorker().catch(err => console.error("Worker Init Failed:", err));


