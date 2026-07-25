import fs from 'fs';
import express from 'express';
import { Worker } from 'worker_threads';
import os from 'os';
import crypto from 'crypto';
import path from 'path'; // ADD THIS
import { fileURLToPath } from 'url'; // ADD THIS

const __dirname = path.dirname(fileURLToPath(import.meta.url)); // ADD THIS

const app = express();
app.use(express.json({ limit: '50mb' }));
app.use((_, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Content-Type, x-api-key");
    res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    next();
});

// ========== COMMERCIAL LAYER ==========
const VALID_KEYS = new Set([process.env.API_KEY]);
const requestCounters = new Map();

function enforceApiLimits(req, res, next) {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey ||!VALID_KEYS.has(apiKey)) {
        return res.status(401).json({ error: "Unauthorized. Valid 'x-api-key' header required." });
    }

    const currentMinute = Math.floor(Date.now() / 60000);
    const counterKey = `${apiKey}:${currentMinute}`;
    const currentUsage = requestCounters.get(counterKey) || 0;

    if (currentUsage >= 100) {
        return res.status(429).json({ error: "Rate limit exceeded. Max 100 req/min on free tier." });
    }
    requestCounters.set(counterKey, currentUsage + 1);
    next();
}

setInterval(() => {
    const cutoff = Math.floor(Date.now() / 60000) - 2;
    for (const key of requestCounters.keys()) {
        if (parseInt(key.split(':')[1]) < cutoff) requestCounters.delete(key);
    }
}, 600000);

// ========== WORKER POOL ==========
const POOL_SIZE = os.cpus().length;
// FIXED: use absolute path to worker.js in same folder
const workers = Array.from({ length: POOL_SIZE }, () => new Worker(path.join(__dirname, 'worker.js')));
let workerIdx = 0;
const pending = new Map();

workers.forEach(w => w.on('message', ({id, result, error}) => {
    const {resolve, reject} = pending.get(id);
    pending.delete(id);
    error? reject(new Error(error)) : resolve(result);
}));

function runInWorker(payload) {
    return new Promise((resolve, reject) => {
        const id = crypto.randomUUID();
        pending.set(id, {resolve, reject});
        const worker = workers[workerIdx++ % POOL_SIZE];
        worker.postMessage({id,...payload});
    });
}

// ========== ROUTES ==========
app.get('/health', (_, res) => res.json({ status: "ok" }));
app.options('*', (_, res) => res.sendStatus(200));

app.post('/v1/hash', enforceApiLimits, async (req, res) => {
    const { inputs } = req.body;
    if (!inputs ||!Array.isArray(inputs) || inputs.length!== 3) {
        return res.status(400).json({ error: "Provide an array of exactly 3 numerical field elements." });
    }
    try {
        const result = await runInWorker({ type: "hash", inputs });
        res.json({ hash: result.hash });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/v1/prove', enforceApiLimits, async (req, res) => {
    const { items, target_index = 0 } = req.body;
    if (!items ||!Array.isArray(items) || items.length === 0 || items.length > 10000) {
        return res.status(400).json({ error: "Invalid payloads. Max batch limit 10,000." });
    }
    if (target_index >= items.length) {
        return res.status(400).json({ error: "target_index out of bounds" });
    }
    const timeout = setTimeout(() => res.status(504).json({error: "Request timeout"}), 10000);
    try {
        const result = await runInWorker({ type: "prove", items, target_index });
        clearTimeout(timeout);
        res.json(result);
    } catch (err) {
        clearTimeout(timeout);
        res.status(500).json({ error: err.message });
    }
});

app.post('/v1/verify', enforceApiLimits, async (req, res) => {
    const { leaf, root, proof } = req.body;
    if (!leaf ||!root ||!proof ||!Array.isArray(proof.steps)) {
        return res.status(400).json({ error: "Missing leaf, root, or proof matrix structured payload." });
    }
    const timeout = setTimeout(() => res.status(504).json({error: "Request timeout"}), 5000);
    try {
        const result = await runInWorker({ type: "verify", leaf, root, proof });
        clearTimeout(timeout);
        res.json({ verified: result.verified });
    } catch (err) {
        clearTimeout(timeout);
        res.status(500).json({ error: err.message });
    }
});

// FIXED: Use Railway PORT
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Basin ZK API v1 live on ${PORT} with ${POOL_SIZE} workers`));