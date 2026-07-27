import { parentPort } from 'worker_threads';
import fs from 'fs';
import pkg from 'circomlib'; // FIX: CJS import
const { buildPoseidon } = pkg;

// Crash logging so we see errors in Railway
process.on('uncaughtException', (err) => {
  console.error('Worker Uncaught:', err);
  process.exit(1);
});
process.on('unhandledRejection', (err) => {
  console.error('Worker Unhandled:', err);
  process.exit(1);
});

console.log('Worker: Loading circomlib...');
const poseidon = await buildPoseidon(); // circomlib also needs async init
const F = poseidon.F;
console.log('Worker: circomlib loaded');

console.log('Worker: Loading basin.wasm...');
const wasmBuffer = fs.readFileSync('./basin.wasm');
const wasmModuleCompiled = await WebAssembly.compile(wasmBuffer);
const instance = await WebAssembly.instantiate(wasmModuleCompiled);
console.log('Worker: WASM loaded');

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
    let bytes;
    if(typeof input === 'number') {
        bytes = Buffer.from(input.toString(16).padStart(64, '0'), 'hex');
    } else {
        bytes = encoder.encode(String(input));
    }

    const inputs = [];
    for(let i = 0; i < bytes.length; i += 31) {
        const chunk = bytes.slice(i, i + 31);
        const hex = Buffer.from(chunk).toString('hex') || '0';
        inputs.push(BigInt('0x' + hex));
    }
    if(inputs.length === 0) inputs.push(0n);
    
    const hash = poseidon(inputs); // returns field element
    const hashHex = F.toString(hash); // convert to hex string
    return new Uint8Array(Buffer.from(hashHex.padStart(64, '0'), 'hex'));
}

function hexToBytes(hex) {
    if (!hex) throw new Error("hex is empty");
    hex = hex.replace('0x','').padEnd(64, '0');
    return new Uint8Array(Buffer.from(hex, 'hex'));
}

parentPort.on('message', async ({ id, type, items, target_index, inputs, leaf, root, proof }) => {
    try {
        let result;
        if (type === 'hash') {
            const h = await Promise.all(inputs.map(i => hashTo32Bytes(i)));
            const combined = poseidon(h.map(b => BigInt('0x'+Buffer.from(b).toString('hex'))));
            const combinedHex = F.toString(combined);
            result = { hash: "0x" + combinedHex.padStart(64, '0') };
        }
        else if (type === 'prove') {
            for (let i = 0; i < items.length; i++) {
                const rawBytes = await hashTo32Bytes(items[i]);
                for (let b = 0; b < OUTPUT_SIZE; b++) set_leaf_byte(i, b, rawBytes[b]);
            }
            if(!api_compute_root(items.length) ||!api_generate_proof(items.length, target_index)) throw new Error("WASM failed");
            const buf = memory.buffer;
            const rootHash = Buffer.from(buf, get_root_ptr(), OUTPUT_SIZE).toString('hex');
            const steps = Array.from({length: get_proof_len()}, (_,i) => ({
                is_right: get_proof_step_side(i),
                sibling: Buffer.from(buf, get_proof_step_sibling_ptr(i), OUTPUT_SIZE).toString('hex')
            }));
            result = { root: "0x" + rootHash, proof: { steps } };
        }
        else if (type === 'verify') {
            const leafBytes = hexToBytes(leaf); const rootBytes = hexToBytes(root);
            const siblingsBuf = new Uint8Array(proof.steps.length * OUTPUT_SIZE);
            const flagsBuf = new Uint8Array(proof.steps.length);
            proof.steps.forEach((s,i) => {
                siblingsBuf.set(hexToBytes(s.sibling), i * OUTPUT_SIZE);
                flagsBuf[i] = s.is_right? 1 : 0;
            });
            const mem = new Uint8Array(memory.buffer);
            mem.set(leafBytes, 0); 
            mem.set(rootBytes, 32); 
            mem.set(siblingsBuf, 64); 
            mem.set(flagsBuf, 64 + siblingsBuf.length);
            const verified = api_verify_proof(0, 32, proof.steps.length, 64, 64 + siblingsBuf.length);
            result = { verified: verified === 1 };
        }
        parentPort.postMessage({ id, result });
    } catch (err) {
        console.error('Worker Message Error:', err);
        parentPort.postMessage({ id, error: err.message });
    }
});