import fs from 'fs';
import express from 'express';
import { Worker } from 'worker_threads';
import os from 'os';

const app = express();
app.use(express.json({ limit: '50mb' })); // bump for 10k items
app.use((_, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Content-Type");
    next();
});

// Create a pool of workers = # of CPU cores
const POOL_SIZE = os.cpus().length;
const workers = Array.from({ length: POOL_SIZE }, () => new Worker('./worker.js'));
let workerIdx = 0;
const pending = new Map();

workers.forEach(w => w.on('message', ({id, result, error}) => {
    const {resolve, reject} = pending.get(id);
    pending.delete(id);
    error? reject(error) : resolve(result);
}));

function runInWorker(payload) {
    return new Promise((resolve, reject) => {
        const id = crypto.randomUUID();
        pending.set(id, {resolve, reject});
        const worker = workers[workerIdx++ % POOL_SIZE];
        worker.postMessage({id,...payload});
    });
}

app.get('/health', (_, res) => res.json({ status: "ok" }));
app.options('/v1/prove', (_, res) => res.sendStatus(200));

app.post('/v1/prove', async (req, res) => {
    const { items, target_index = 0 } = req.body;

    if (!items ||!Array.isArray(items) || items.length === 0 || items.length > 10000) {
        return res.status(400).json({ error: "Invalid payloads. Max batch limit 10,000." });
    }
    if (target_index >= items.length) {
        return res.status(400).json({ error: "target_index out of bounds" });
    }

    // Add timeout so 10k batch can't hang forever
    const timeout = setTimeout(() => res.status(504).json({error: "Request timeout"}), 10000);

    try {
        const result = await runInWorker({ items, target_index });
        clearTimeout(timeout);
        res.json(result);
    } catch (err) {
        clearTimeout(timeout);
        res.status(500).json({ error: err.message });
    }
});

app.listen(8080, () => console.log(`Basin ZK API running on ${POOL_SIZE} workers`));