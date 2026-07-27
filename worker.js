import { parentPort } from 'worker_threads';
import fs from 'fs';
import path from 'path';

// Production crash logging and exception sandboxing
process.on('uncaughtException', (err) => { console.error('Worker Uncaught:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('Worker Unhandled:', err); process.exit(1); });

// BN254 Prime Field Order Size Definition
const FIELD_SIZE = BigInt("21888242871839275222246405745257275088548364400416034343698204186575808495617");

const F = {
    add: (a, b) => (a + b) % FIELD_SIZE,
    mul: (a, b) => (a * b) % FIELD_SIZE,
    pow: (a, e) => { 
        let r = 1n; 
        while (e > 0n) { 
            if (e & 1n) r = F.mul(r, a); 
            a = F.mul(a, a); 
            e >>= 1n; 
        } 
        return r; 
    },
    toString: (b) => b.toString(16),
};

// Streamlined data extraction to completely avoid code file parsing issues
const rawConstants = JSON.parse(fs.readFileSync(path.resolve('./constants.json'), 'utf8'));
const C = rawConstants.map(hexStr => BigInt(hexStr));

// Full MDS Diffusion Matrix for t=3 layout configurations
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

    // 1. Initial 4 Full rounds (4 rounds * 3 constants = 12 consumed)
    for (let r = 0; r < 4; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        for (let i = 0; i < t; i++) state[i] = F.pow(state[i], 5n);
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }

    // 2. 56 Partial rounds (56 rounds * 3 constants = 168 consumed)
    for (let r = 0; r < 56; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        state[0] = F.pow(state[0], 5n); // Unrolled S-Box optimization applied strictly to index 0
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }

    // 3. Final 4 Full rounds (4 rounds * 3 constants = 12 consumed. Total array offsets = 12 + 168 + 12 = 216)
    for (let r = 0; r < 4; r++) {
        for (let i = 0; i < t; i++) state[i] = F.add(state[i], C[cIdx++]);
        for (let i = 0; i < t; i++) state[i] = F.pow(state[i], 5n);
        let newState = [0n, 0n, 0n];
        for (let i = 0; i < t; i++) for (let j = 0; j < t; j++) newState[i] = F.add(newState[i], F.mul(M[i][j], state[j]));
        state = newState;
    }
    return state[0];
}

// ===== LINEAR WASM TREE STORAGE MANAGEMENT LAYER =====
async function initWorker() {
    console.log('Worker: Streamlined Poseidon Engine Context Initialized Successfully');
    const wasmBuffer = fs.readFileSync('./basin.wasm');
    const { instance } = await WebAssembly.instantiate(wasmBuffer);
    const { 
        set_leaf_byte, 
        api_compute_root, 
        api_generate_proof, 
        api_verify_proof, 
        get_root_ptr, 
        get_proof_len, 
        get_proof_step_side, 
        get_proof_step_sibling_ptr, 
        memory 
    } = instance.exports;
    
    const OUTPUT_SIZE = 32;
    const encoder = new TextEncoder();

    async function hashTo32Bytes(input) {
        let bytes = typeof input === 'number' ? Buffer.from(input.toString(16).padStart(64, '0'), 'hex') : encoder.encode(String(input));
        const chunks = [];
        for (let i = 0; i < bytes.length; i += 31) {
            const chunk = bytes.slice(i, i + 31);
            const hex = Buffer.from(chunk).toString('hex') || '0';
            chunks.push(BigInt('0x' + hex));
        }
        while (chunks.length < 2) chunks.push(0n);
        const hash = poseidon(chunks);
        return new Uint8Array(Buffer.from(F.toString(hash).padStart(64, '0'), 'hex'));
    }

    function hexToBytes(hex) {
        hex = hex.replace('0x', '').padStart(64, '0');
        return new Uint8Array(Buffer.from(hex, 'hex'));
    }

    if (parentPort) {
        parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
            try {
                let result;
                if (type === 'hash') {
                    const h = await Promise.all(inputs.map(i => hashTo32Bytes(i)));
                    const combined = poseidon(h.map(b => BigInt('0x' + Buffer.from(b).toString('hex'))));
                    result = { hash: "0x" + F.toString(combined).padStart(64, '0') };
                }
                else if (type === 'prove') {
                    for (let i = 0; i < items.length; i++) {
                        const rawBytes = await hashTo32Bytes(items[i]);
                        for (let b = 0; b < OUTPUT_SIZE; b++) set_leaf_byte(i, b, rawBytes[b]);
                    }
                    if (!api_compute_root(items.length) || !api_generate_proof(items.length, target_index)) {
                        throw new Error("WASM calculation execution layout returned failure state");
                    }
                    const buf = memory.buffer;
                    const rootHash = Buffer.from(buf, get_root_ptr(), OUTPUT_SIZE).toString('hex');
                    const steps = Array.from({ length: get_proof_len() }, (_, i) => ({ 
                        is_right: get_proof_step_side(i) === 1, 
                        sibling: Buffer.from(buf, get_proof_step_sibling_ptr(i), OUTPUT_SIZE).toString('hex') 
                    }));
                    result = { root: "0x" + rootHash, proof: { steps } };
                }
                else if (type === 'verify') {
                    const leafBytes = hexToBytes(leaf); 
                    const rootBytes = hexToBytes(root);
                    const siblingsBuf = new Uint8Array(proof.steps.length * OUTPUT_SIZE);
                    const flagsBuf = new Uint8Array(proof.steps.length);
                    
                    proof.steps.forEach((s, i) => { 
                        siblingsBuf.set(hexToBytes(s.sibling), i * OUTPUT_SIZE); 
                        flagsBuf[i] = s.is_right ? 1 : 0; 
                    });
                    
                    const mem = new Uint8Array(memory.buffer);
                    
                    // Fixed safe allocation offset above static data bounds
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
                console.error('Worker Processing Frame Error:', err);
                parentPort.postMessage({ id, error: err.message });
            }
        });
    }
}

initWorker().catch(err => console.error("Worker Boot Sequence Failed:", err));
