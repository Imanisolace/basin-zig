// pool.js
import { Worker } from 'worker_threads';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import os from 'os';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const POOL_SIZE = Math.min(4, Math.max(1, os.cpus().length - 1));
const REQUEST_TIMEOUT_MS = 10_000;

class WorkerPool {
  constructor(size) {
    this.workers = [];
    this.nextIndex = 0;
    this.pending = new Map(); // id -> { resolve, reject, timeoutHandle }
    for (let i = 0; i < size; i++) this.spawn(i);
  }

  spawn(slot) {
    const worker = new Worker(path.join(__dirname, 'worker.js'));
    worker.on('message', ({ id, result, error }) => {
      const entry = this.pending.get(id);
      if (!entry) return; // response for a request we already timed out
      clearTimeout(entry.timeoutHandle);
      this.pending.delete(id);
      if (error) entry.reject(new Error(error));
      else entry.resolve(result);
    });
    worker.on('error', (err) => {
      console.error(`worker[${slot}] crashed:`, err);
      // reject anything this worker still owed a response for
      for (const [id, entry] of this.pending) {
        if (entry.slot === slot) {
          clearTimeout(entry.timeoutHandle);
          entry.reject(new Error('worker crashed'));
          this.pending.delete(id);
        }
      }
      this.workers[slot] = this.spawnRaw(slot); // respawn so the pool stays full-sized
    });
    this.workers[slot] = worker;
    return worker;
  }

  spawnRaw(slot) {
    return this.spawn(slot);
  }

  dispatch(message) {
    const id = crypto.randomUUID();
    const slot = this.nextIndex;
    this.nextIndex = (this.nextIndex + 1) % this.workers.length;
    const worker = this.workers[slot];

    return new Promise((resolve, reject) => {
      const timeoutHandle = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error('worker request timed out'));
      }, REQUEST_TIMEOUT_MS);

      this.pending.set(id, { resolve, reject, timeoutHandle, slot });
      worker.postMessage({ id, ...message });
    });
  }
}

export default new WorkerPool(POOL_SIZE);