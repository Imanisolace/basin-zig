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
        // 1. Load all items into WASM memory, padded to 32 bytes
        for (let i = 0; i < items.length; i++) {
          const bytes = stringToBytes(items[i]);
          for (let b = 0; b < OUTPUT_SIZE; b++) {
            set_leaf_byte(i, b, bytes[b]);
          }
        }
        // 2. Compute root
        if (api_compute_root(items.length) === 0) throw new Error("api_compute_root failed");
        // 3. Generate proof
        if (api_generate_proof(items.length, target_index) === 0) throw new Error("api_generate_proof failed");

        // 4. Read result from WASM memory
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
        const base = 65536; // safe offset in WASM memory

        // 1. Clear the memory region first
        for(let i=0; i<OUTPUT_SIZE*4; i++) mem[base+i] = 0;

        // 2. Write leaf, padded to 32 bytes
        const leafBytes = stringToBytes(item);
        for(let b=0; b<OUTPUT_SIZE; b++) mem[base+b] = leafBytes[b];

        // 3. Write root
        const rootBytes = Buffer.from(root.replace('0x',''), 'hex');
        mem.set(rootBytes, base + OUTPUT_SIZE);

        // 4. Write siblings and flags
        for(let i=0; i<proof.steps.length; i++) {
          const siblingBytes = Buffer.from(proof.steps[i].sibling.replace('0x',''), 'hex');
          for(let b=0; b<OUTPUT_SIZE; b++) {
            mem[base + OUTPUT_SIZE*2 + i*OUTPUT_SIZE + b] = siblingBytes[b];
          }
          mem[base + OUTPUT_SIZE*3 + i] = proof.steps[i].is_right? 1 : 0;
        }

        // 5. Call Zig verify
        const verified = api_verify_proof(
          base, // leaf_ptr
          base + OUTPUT_SIZE, // root_ptr
          proof.steps.length, // proof_len
          base + OUTPUT_SIZE * 2, // siblings_ptr
          base + OUTPUT_SIZE * 3 // flags_ptr
        );
        result = { valid: verified === 1 };
      }
      parentPort.postMessage({ id, result });
    } catch (err) {
      console.error('Worker Error:', err);
      parentPort.postMessage({ id, error: err.message });
    }
  });
}