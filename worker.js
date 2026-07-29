import { parentPort } from 'worker_threads';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

process.on('uncaughtException', (err) => { console.error('Worker Uncaught:', err); process.exit(1); });

const OUTPUT_SIZE = 32;
const encoder = new TextEncoder();

const wasmBuffer = fs.readFileSync(path.join(__dirname, 'basin.wasm'));
let wasmInstance = null;
let memory = null;

async function initWasm() {
  if (wasmInstance) return;
  const { instance } = await WebAssembly.instantiate(wasmBuffer, {
    env: { memory: new WebAssembly.Memory({ initial: 256 }) }
  });
  wasmInstance = instance;
  memory = instance.exports.memory;
}

function stringToBytes(str) {
  const bytes = encoder.encode(str);
  const out = new Uint8Array(OUTPUT_SIZE);
  out.set(bytes.slice(0, OUTPUT_SIZE));
  return out;
}

if (parentPort) {
  parentPort.on('message', async ({ id, type, items, target_index, item, root, proof }) => {
    try {
      await initWasm();
      const {
        set_leaf_byte, api_compute_root, api_generate_proof, api_verify_proof,
        get_root_ptr, get_proof_len, get_proof_step_side, get_proof_step_sibling_ptr
      } = wasmInstance.exports;

      let result;
      if (type === 'prove') {
        for (let i = 0; i < items.length; i++) {
          const bytes = stringToBytes(items[i]);
          for (let b = 0; b < OUTPUT_SIZE; b++) {
            set_leaf_byte(i, b, bytes[b]);
          }
        }
        if (api_compute_root(items.length) === 0) throw new Error("api_compute_root failed");
        if (api_generate_proof(items.length, target_index) === 0) throw new Error("api_generate_proof failed");

        const buf = new Uint8Array(memory.buffer);
        const rootHash = Buffer.from(buf.slice(get_root_ptr(), get_root_ptr() + OUTPUT_SIZE)).toString('hex');
        const steps = [];
        for (let i = 0; i < get_proof_len(); i++) {
          steps.push({
            is_right: get_proof_step_side(i) === 1,
            sibling: Buffer.from(buf.slice(get_proof_step_sibling_ptr(i), get_proof_step_sibling_ptr(i) + OUTPUT_SIZE)).toString('hex')
          });
        }
        result = { root: "0x" + rootHash, proof: { steps } };
      } 
      else if (type === 'verify') {
        // /verify now actually calls your Zig WASM
        const leafBytes = stringToBytes(item); // note: 'item' not 'leaf'
        const rootBytes = Buffer.from(root.replace('0x',''), 'hex');

        const siblingsBuf = new Uint8Array(proof.steps.length * OUTPUT_SIZE);
        const flagsBuf = new Uint8Array(proof.steps.length);
        proof.steps.forEach((s, i) => {
          Buffer.from(s.sibling.replace('0x',''), 'hex').copy(siblingsBuf, i * OUTPUT_SIZE);
          flagsBuf[i] = s.is_right? 1 : 0;
        });

        const mem = new Uint8Array(memory.buffer);
        const base = 65536; // safe offset
        mem.set(leafBytes, base);
        mem.set(rootBytes, base + OUTPUT_SIZE);
        mem.set(siblingsBuf, base + OUTPUT_SIZE * 2);
        mem.set(flagsBuf, base + OUTPUT_SIZE * 3);

        const verified = api_verify_proof(base, base + OUTPUT_SIZE, proof.steps.length, base + OUTPUT_SIZE * 2, base + OUTPUT_SIZE * 3);
        result = { valid: verified === 1 }; // changed to 'valid' to match API spec
      }
      parentPort.postMessage({ id, result });
    } catch (err) {
      console.error('Worker Error:', err);
      parentPort.postMessage({ id, error: err.message });
    }
  });
}