import { parentPort } from 'worker_threads';
import fs from 'fs';

const wasmBuffer = fs.readFileSync('./basin.wasm');
const wasmModuleCompiled = await WebAssembly.compile(wasmBuffer);
const instance = await WebAssembly.instantiate(wasmModuleCompiled);

const {
    set_leaf_byte, 
    api_compute_root, 
    api_generate_proof,
    api_verify_proof, // NEW
    get_root_ptr, 
    get_proof_len, 
    get_proof_step_side,
    get_proof_step_sibling_ptr, 
    memory
} = instance.exports;

const OUTPUT_SIZE = 32;
const encoder = new TextEncoder();

// Hash anything > 32 bytes down to 32 bytes. Prevents truncation collisions
async function hashTo32Bytes(str) {
    const bytes = encoder.encode(str);
    const out = new Uint8Array(OUTPUT_SIZE);
    // TODO: replace with real SHA256. This is just a temp hasher
    for(let i=0; i<bytes.length; i++) out[i % OUTPUT_SIZE] ^= bytes[i];
    return out;
}

function hexToBytes(hex) {
    if (hex.startsWith('0x')) hex = hex.slice(2);
    return new Uint8Array(Buffer.from(hex, 'hex'));
}

parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
    try {
        let result;

        if (type === 'hash') {
            // inputs: [a, b, c]
            // For now we do this in JS. If you export hash3 from zig, call it here
            if (!inputs || inputs.length!== 3) throw new Error("Need 3 inputs");
            // TODO: call instance.exports.hash3 when you export it
            result = { hash: "0x" + "00".repeat(OUTPUT_SIZE) }; // placeholder

        } else if (type === 'prove') {
            // Load leaves into static WASM buffer
            for (let leafIdx = 0; leafIdx < items.length; leafIdx++) {
                const item = items[leafIdx];
                if (typeof item!== 'string') throw new Error(`Item ${leafIdx} must be a string`);
                const rawBytes = await hashTo32Bytes(item);
                for (let b = 0; b < OUTPUT_SIZE; b++) {
                    set_leaf_byte(leafIdx, b, rawBytes[b]);
                }
            }

            const rootSuccess = api_compute_root(items.length);
            const proofSuccess = api_generate_proof(items.length, target_index);
            if (!rootSuccess ||!proofSuccess) throw new Error("WASM proof failed");

            const buf = memory.buffer;
            const rootHash = Buffer.from(buf, get_root_ptr(), OUTPUT_SIZE).toString('hex');
            const proofLen = get_proof_len();
            const steps = [];
            for (let i = 0; i < proofLen; i++) {
                steps.push({
                    is_right: get_proof_step_side(i),
                    sibling: Buffer.from(buf, get_proof_step_sibling_ptr(i), OUTPUT_SIZE).toString('hex')
                });
            }
            result = { root: "0x" + rootHash, proof: { steps, length: proofLen } };

        } else if (type === 'verify') {
            // Write leaf, root, and proof arrays into WASM memory then call api_verify_proof
            const leafBytes = hexToBytes(leaf);
            const rootBytes = hexToBytes(root);
            
            if (leafBytes.length!== OUTPUT_SIZE || rootBytes.length!== OUTPUT_SIZE) {
                throw new Error(`leaf and root must be ${OUTPUT_SIZE} bytes`);
            }

            const proofLen = proof.steps.length;
            const siblingsBuf = new Uint8Array(proofLen * OUTPUT_SIZE);
            const flagsBuf = new Uint8Array(proofLen);

            for (let i = 0; i < proofLen; i++) {
                const siblingBytes = hexToBytes(proof.steps[i].sibling);
                siblingsBuf.set(siblingBytes, i * OUTPUT_SIZE);
                flagsBuf[i] = proof.steps[i].is_right? 1 : 0;
            }

            // Allocate space in WASM memory. Use the end of the buffer
            const mem = new Uint8Array(memory.buffer);
            const leafPtr = 0;
            const rootPtr = leafPtr + OUTPUT_SIZE;
            const siblingsPtr = rootPtr + OUTPUT_SIZE;
            const flagsPtr = siblingsPtr + siblingsBuf.length;

            mem.set(leafBytes, leafPtr);
            mem.set(rootBytes, rootPtr);
            mem.set(siblingsBuf, siblingsPtr);
            mem.set(flagsBuf, flagsPtr);

            const verified = api_verify_proof(leafPtr, rootPtr, proofLen, siblingsPtr, flagsPtr);
            result = { verified };

        } else {
            throw new Error(`Unknown type: ${type}`);
        }

        parentPort.postMessage({ id, result });
    } catch (err) {
        parentPort.postMessage({ id, error: err.message });
    }
});