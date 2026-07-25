import { parentPort } from 'worker_threads';
import fs from 'fs';
import { poseidon } from 'poseidon-lite'; // npm i poseidon-lite

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
const FIELD_SIZE = 31; // Poseidon outputs fit in 31 bytes for Goldilocks
const encoder = new TextEncoder();

// REAL: Poseidon hash anything > 32 bytes down to 32 bytes
async function hashTo32Bytes(str) {
    const bytes = encoder.encode(str);
    // Convert bytes to BigInts for Poseidon
    const inputs = [];
    for(let i = 0; i < bytes.length; i += FIELD_SIZE) {
        const chunk = bytes.slice(i, i + FIELD_SIZE);
        inputs.push(BigInt('0x' + Buffer.from(chunk).toString('hex')));
    }
    if(inputs.length === 0) inputs.push(0n);

    const hash = poseidon(inputs); // returns BigInt
    const hex = hash.toString(16).padStart(64, '0');
    return new Uint8Array(Buffer.from(hex, 'hex'));
}

// FIXED: Auto-pads to 32 bytes so ReqBin doesn't delete zeros
function hexToBytes(hex) {
    if (!hex) throw new Error("hex is empty");
    if (hex.startsWith('0x')) hex = hex.slice(2);
    hex = hex.padEnd(64, '0');
    if (hex.length!== 64) throw new Error(`hex must be 64 chars after padding, got ${hex.length}`);
    return new Uint8Array(Buffer.from(hex, 'hex'));
}

parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
    try {
        let result;

        if (type === 'hash') {
            if (!inputs || inputs.length!== 3) throw new Error("Need 3 inputs");
            const h1 = await hashTo32Bytes(inputs[0]);
            const h2 = await hashTo32Bytes(inputs[1]);
            const h3 = await hashTo32Bytes(inputs[2]);
            const combined = poseidon([BigInt('0x'+Buffer.from(h1).toString('hex')), BigInt('0x'+Buffer.from(h2).toString('hex')), BigInt('0x'+Buffer.from(h3).toString('hex'))]);
            result = { hash: "0x" + combined.toString(16).padStart(64, '0') };

        } else if (type === 'prove') {
            for (let leafIdx = 0; leafIdx < items.length; leafIdx++) {
                const item = items[leafIdx];
                if (typeof item!== 'string') throw new Error(`Item ${leafIdx} must be a string`);
                const rawBytes = await hashTo32Bytes(item); // NOW POSEIDON
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
            const leafBytes = hexToBytes(leaf);
            const rootBytes = hexToBytes(root);

            const proofLen = proof.steps.length;
            const siblingsBuf = new Uint8Array(proofLen * OUTPUT_SIZE);
            const flagsBuf = new Uint8Array(proofLen);

            for (let i = 0; i < proofLen; i++) {
                const siblingBytes = hexToBytes(proof.steps[i].sibling);
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
            result = { verified: verified === 1 };

        } else {
            throw new Error(`Unknown type: ${type}`);
        }

        parentPort.postMessage({ id, result });
    } catch (err) {
        console.error("[worker error]", err);
        parentPort.postMessage({ id, error: err.message });
    }
});