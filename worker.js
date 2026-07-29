import { parentPort } from 'worker_threads';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
          for (let b = 0; b < OUTPUT_SIZE; b++) set_leaf_byte(i, b, bytes[b]);
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
        const mem = new Uint8Array(memory.buffer);
        const leaf_ptr = 0;
        const root_ptr = OUTPUT_SIZE;
        const siblings_ptr = OUTPUT_SIZE * 2;
        const flags_ptr = siblings_ptr + OUTPUT_SIZE * proof.steps.length;

        // clear
        mem.fill(0, 0, flags_ptr + proof.steps.length);

        // write leaf
        mem.set(stringToBytes(item), leaf_ptr);
        // write root
        mem.set(Buffer.from(root.replace('0x',''), 'hex'), root_ptr);
        // write siblings + flags
        proof.steps.forEach((step, i) => {
          mem.set(Buffer.from(step.sibling.replace('0x',''), 'hex'), siblings_ptr + i * OUTPUT_SIZE);
          mem[flags_ptr + i] = step.is_right? 1 : 0;
        });

        const verified = api_verify_proof(leaf_ptr, root_ptr, proof.steps.length, siblings_ptr, flags_ptr);
        result = { valid: verified === 1 };
      }
      parentPort.postMessage({ id, result });
    } catch (err) {
      parentPort.postMessage({ id, error: err.message });
    }
  });
}