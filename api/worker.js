import { parentPort } from 'worker_threads';
import fs from 'fs';

const wasmBuffer = fs.readFileSync('./basin.wasm');
const wasmModuleCompiled = await WebAssembly.compile(wasmBuffer);
const instance = await WebAssembly.instantiate(wasmModuleCompiled);

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

// Hash anything > 32 bytes down to 32 bytes. Temp hasher
async function hashTo32Bytes(str) {
    const bytes = encoder.encode(str);
    const out = new Uint8Array(OUTPUT_SIZE);
    for(let i = 0; i < bytes.length; i++) out[i % OUTPUT_SIZE] ^= bytes[i];
    return out;
}

function hexToBytes(hex) {
    if (!hex) throw new Error("hex is empty");
    if (hex.startsWith('0x')) hex = hex.slice(2);
    if (hex.length % 2!== 0) throw new Error(`hex length must be even, got ${hex.length}`);
    const buf = Buffer.from(hex, 'hex');
    console.log(`[hexToBytes] input len: ${hex.length} chars -> ${buf.length} bytes`);
    return new Uint8Array(buf);
}

parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
    try {
        let result;

        if (type === 'hash') {
            if (!inputs || inputs.length!== 3) throw new Error("Need 3 inputs");
            result = { hash: "0x" + "00".repeat(OUTPUT_SIZE) };

        } else if (type === 'prove') {
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
            console.log("[verify] raw leaf:", leaf);
            console.log("[verify] raw root:", root);
            
            const leafBytes = hexToBytes(leaf);
            const rootBytes = hexToBytes(root);

            console.log(`[verify] leaf bytes: ${leafBytes.length}, root bytes: ${rootBytes.length}`);

            if (leafBytes.length!== OUTPUT_SIZE || rootBytes.length!== OUTPUT_SIZE) {
                throw new Error(`leaf and root must be ${OUTPUT_SIZE} bytes. Got leaf:${leafBytes.length} root:${rootBytes.length}`);
            }

            const proofLen = proof.steps.length;
            const siblingsBuf = new Uint8Array(proofLen * OUTPUT_SIZE);
            const flagsBuf = new Uint8Array(proofLen);

            for (let i = 0; i < proofLen; i++) {
                const siblingBytes = hexToBytes(proof.steps[i].sibling);
                console.log(`[verify] step ${i} sibling bytes: ${siblingBytes.length}`);
                if (siblingBytes.length!== OUTPUT_SIZE) {
                    throw new Error(`sibling ${i} must be ${OUTPUT_SIZE} bytes. Got ${siblingBytes.length}`);
                }
                siblingsBuf.set(siblingBytes, i * OUTPUT_SIZE);
                flagsBuf[i] = proof.steps[i].is_right? 1 : 0;
            }

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
            console.log("[verify] result:", verified);
            result = { verified };

        } else {
            throw new Error(`Unknown type: ${type}`);
        }

        parentPort.postMessage({ id, result });
    } catch (err) {
        console.error("[worker error]", err);
        parentPort.postMessage({ id, error: err.message });
    }
});