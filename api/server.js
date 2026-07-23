import fs from 'fs';
import express from 'express';

const app = express();
app.use(express.json({ limit: '10mb' }));

// Enable CORS so frontend widgets can run browser benchmarks natively
app.use((_, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Content-Type");
    next();
});

// Load the compiled freestanding Wasm binary artifact
const wasmBuffer = fs.readFileSync('./zig-out/bin/basin.wasm');
const wasmModule = await WebAssembly.instantiate(wasmBuffer);
const {
    set_leaf_byte,
    api_compute_root,
    api_generate_proof,
    get_root_ptr,
    get_proof_len,
    get_proof_step_side,
    get_proof_step_sibling_ptr,
    memory
} = wasmModule.instance.exports;

// Core status health check
app.get('/health', (_, res) => res.json({ status: "ok" }));

// Production Proof Extraction Pipeline
app.post('/v1/prove', (req, res) => {
    const { items, target_index = 0 } = req.body;

    // Boundary validations
    if (!items || !Array.isArray(items) || items.length > 10000 || target_index >= items.length) {
        return res.status(400).json({ error: "Invalid payloads. Max batch limit 10,000." });
    }

    // 1. Ingest raw items into the highly optimized Poseidon engine lanes
    items.forEach((item, leafIdx) => {
        const encoder = new TextEncoder();
        const rawBytes = encoder.encode(item);
        for (let b = 0; b < 32; b++) {
            set_leaf_byte(leafIdx, b, rawBytes[b] || 0);
        }
    });

    // 2. Compute Root and Proof pathways via compiled Zig loops
    const rootSuccess = api_compute_root(items.length);
    const proofSuccess = api_generate_proof(items.length, target_index);

    if (!rootSuccess || !proofSuccess) {
        return res.status(500).json({ error: "Cryptographic proof step extraction failed." });
    }

    // 3. Extract proof values out of Wasm memory bounds safely
    const rootPtr = get_root_ptr();
    const rootHash = Buffer.from(memory.buffer, rootPtr, 32).toString('hex');

    const proofLen = get_proof_len();
    const steps = [];

    for (let i = 0; i < proofLen; i++) {
        const isRight = get_proof_step_side(i);
        const siblingPtr = get_proof_step_sibling_ptr(i);
        const siblingHash = Buffer.from(memory.buffer, siblingPtr, 32).toString('hex');
        steps.push({ is_right: isRight, sibling: siblingHash });
    }

    res.json({
        root: rootHash,
        proof: { steps, length: proofLen }
    });
});

app.listen(8080, () => console.log("Basin ZK API running on port 8080"));
