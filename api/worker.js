import { parentPort } from 'worker_threads';
import fs from 'fs';

const wasmBuffer = fs.readFileSync('./basin.wasm');
const wasmModuleCompiled = await WebAssembly.compile(wasmBuffer);
const instance = await WebAssembly.instantiate(wasmModuleCompiled);
const {
    set_leaf_byte, api_compute_root, api_generate_proof,
    get_root_ptr, get_proof_len, get_proof_step_side,
    get_proof_step_sibling_ptr, memory
} = instance.exports;

const encoder = new TextEncoder();

// Hash anything > 32 bytes down to 32 bytes. Prevents truncation collisions
async function hashTo32Bytes(str) {
    const bytes = encoder.encode(str);
    const out = new Uint8Array(32);
    // TODO: replace with real SHA256. This is just a temp hasher
    for(let i=0; i<bytes.length; i++) out[i % 32] ^= bytes[i];
    return out;
}

parentPort.on('message', async ({ id, items, target_index }) => {
    try {
        for (let leafIdx = 0; leafIdx < items.length; leafIdx++) {
            const item = items[leafIdx];
            if (typeof item!== 'string') throw new Error(`Item ${leafIdx} must be a string`);
            const rawBytes = await hashTo32Bytes(item);
            for (let b = 0; b < 32; b++) {
                set_leaf_byte(leafIdx, b, rawBytes[b]);
            }
        }

        const rootSuccess = api_compute_root(items.length);
        const proofSuccess = api_generate_proof(items.length, target_index);
        if (!rootSuccess ||!proofSuccess) throw new Error("WASM proof failed");

        const buf = memory.buffer;
        const rootHash = Buffer.from(buf, get_root_ptr(), 32).toString('hex');
        const proofLen = get_proof_len();
        const steps = [];
        for (let i = 0; i < proofLen; i++) {
            steps.push({
                is_right: get_proof_step_side(i),
                sibling: Buffer.from(buf, get_proof_step_sibling_ptr(i), 32).toString('hex')
            });
        }
        parentPort.postMessage({ id, result: { root: rootHash, proof: { steps, length: proofLen } });
    } catch (err) {
        parentPort.postMessage({ id, error: err.message });
    }
});