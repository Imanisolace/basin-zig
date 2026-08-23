import { parentPort } from 'worker_threads';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const OUTPUT_SIZE = 32;
const encoder = new TextEncoder();

// Confirmed via a build-log filesystem search: build.zig's install step
// places the real, freshly-compiled artifact at src/basin.wasm relative
// to the repo root — not at the root alongside worker.js. A stale,
// manually-committed basin.wasm previously sat at the root and masked
// this mismatch entirely; it's been deleted from the repo.
const wasmBuffer = fs.readFileSync(path.join(__dirname, 'src', 'basin.wasm'));
let wasmInstance = null;
let memory = null;

async function initWasm() {
  if (wasmInstance) return;

  const { instance } = await WebAssembly.instantiate(wasmBuffer, {
    env: { memory: new WebAssembly.Memory({ initial: 512 }) }
  });

  wasmInstance = instance;
  memory = instance.exports.memory;

  // Safety check — fail fast with a clear message naming exactly which
  // export is missing, instead of a generic "X is not a function" error
  // from whichever call site happens to touch it first.
  const required = [
    'reset_leaves',
    'begin_leaf',
    'get_leaf_write_ptr',
    'api_compute_root',
    'api_generate_proof',
    'get_root_ptr',
    'get_proof_len',
    'get_proof_step_side',
    'get_proof_step_has_sibling',
    'get_proof_step_sibling_ptr',
    'verify_leaf_capacity',
    'get_verify_leaf_ptr',
    'get_verify_root_ptr',
    'get_verify_siblings_ptr',
    'get_verify_is_right_ptr',
    'get_verify_has_sibling_ptr',
    'api_verify_proof',
  ];

  for (const name of required) {
    if (typeof instance.exports[name] !== 'function') {
      throw new Error(`WASM export missing or not a function: ${name}`);
    }
  }
}

if (parentPort) {
  parentPort.on('message', async ({ id, type, items, target_index, item, root, proof }) => {
    try {
      await initWasm();

      const {
        reset_leaves,
        begin_leaf,
        get_leaf_write_ptr,
        api_compute_root,
        api_generate_proof,
        get_root_ptr,
        get_proof_len,
        get_proof_step_side,
        get_proof_step_has_sibling,
        get_proof_step_sibling_ptr,
        verify_leaf_capacity,
        get_verify_leaf_ptr,
        get_verify_root_ptr,
        get_verify_siblings_ptr,
        get_verify_is_right_ptr,
        get_verify_has_sibling_ptr,
        api_verify_proof,
      } = wasmInstance.exports;

      let result;

      if (type === 'prove') {
        reset_leaves();

        for (let i = 0; i < items.length; i++) {
          const bytes = encoder.encode(items[i]);
          const idx = begin_leaf(bytes.length);
          if (idx < 0) {
            throw new Error(`begin_leaf failed for item ${i} (out of leaf slots or buffer space)`);
          }

          const ptr = get_leaf_write_ptr(idx);
          const mem = new Uint8Array(memory.buffer);
          mem.set(bytes, ptr);
        }

        if (api_compute_root() === 0) throw new Error('api_compute_root failed');
        if (api_generate_proof(target_index) === 0) throw new Error('api_generate_proof failed');

        const buf = new Uint8Array(memory.buffer);
        const rootHash = Buffer.from(
          buf.slice(get_root_ptr(), get_root_ptr() + OUTPUT_SIZE)
        ).toString('hex');

        const steps = [];
        for (let i = 0; i < get_proof_len(); i++) {
          const hasSibling = get_proof_step_has_sibling(i) === 1;
          steps.push({
            is_right: get_proof_step_side(i) === 1,
            has_sibling: hasSibling,
            sibling: hasSibling
              ? Buffer.from(
                  buf.slice(
                    get_proof_step_sibling_ptr(i),
                    get_proof_step_sibling_ptr(i) + OUTPUT_SIZE
                  )
                ).toString('hex')
              : null,
          });
        }

        result = { root: '0x' + rootHash, proof: { steps } };
      } else if (type === 'verify') {
        if (!proof.steps || proof.steps.length === 0 || proof.steps.length > 32) {
          throw new Error('invalid proof length');
        }

        const leafBytes = encoder.encode(item);
        const capacity = verify_leaf_capacity();
        if (leafBytes.length > capacity) {
          throw new Error(
            `leaf too large to verify (${leafBytes.length} bytes, max ${capacity})`
          );
        }

        const leafPtr = get_verify_leaf_ptr(leafBytes.length);
        let mem = new Uint8Array(memory.buffer);
        mem.set(leafBytes, leafPtr);

        // Re-view memory in case it grew.
        mem = new Uint8Array(memory.buffer);
        mem.set(Buffer.from(root.replace('0x', ''), 'hex'), get_verify_root_ptr());

        const siblingsPtr = get_verify_siblings_ptr();
        const isRightPtr = get_verify_is_right_ptr();
        const hasSiblingPtr = get_verify_has_sibling_ptr();

        proof.steps.forEach((step, i) => {
          if (step.has_sibling) {
            mem.set(
              Buffer.from(step.sibling.replace('0x', ''), 'hex'),
              siblingsPtr + i * OUTPUT_SIZE
            );
          }
          mem[isRightPtr + i] = step.is_right ? 1 : 0;
          mem[hasSiblingPtr + i] = step.has_sibling ? 1 : 0;
        });

        const verified = api_verify_proof(proof.steps.length);
        result = { valid: verified === 1 };
      } else {
        throw new Error(`unknown message type: ${type}`);
      }

      parentPort.postMessage({ id, result });
    } catch (err) {
      parentPort.postMessage({ id, error: err.message });
    }
  });
}