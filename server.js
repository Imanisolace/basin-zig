import express from 'express'
import path from 'path'
import { Worker } from 'worker_threads'
import os from 'os'
import { fileURLToPath } from 'url'

// Needed for __dirname in ESM
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

// Middleware
app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

// 1. Healthcheck for Railway
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'ok', 
    uptime: process.uptime(),
    workers: workers.length 
  })
})

// 2. Root route
app.get('/', (req, res) => {
  res.json({ name: 'Basin ZK API v1', status: 'live', workers: NUM_WORKERS })
})

// 3. Spawn workers - SAFE FOR 1GB RAM
const NUM_WORKERS = Math.min(os.cpus().length, 4)
const workers = []

console.log(`Starting ${NUM_WORKERS} workers...`)
for (let i = 0; i < NUM_WORKERS; i++) {
  const worker = new Worker(path.join(__dirname, 'worker.js'))
  worker.on('error', (err) => console.error(`Worker ${i} error:`, err))
  worker.on('exit', (code) => {
    if (code!== 0) console.error(`Worker ${i} stopped with exit code ${code}`)
  })
  workers.push(worker)
}

// 4. Example API route - replace with your ZK logic
app.post('/prove', async (req, res) => {
  try {
    // Example: send work to first worker
    // workers[0].postMessage(req.body)
    res.json({ status: 'queued' })
  } catch (e) {
    console.error(e)
    res.status(500).json({ error: e.message })
  }
})

// 5. Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Basin ZK API v1 live on ${PORT} with ${NUM_WORKERS} workers`)
})

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing workers')
  workers.forEach(w => w.terminate())
  process.exit(0)
})