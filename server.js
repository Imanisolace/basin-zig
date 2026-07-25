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

// 3. Spawn workers - 2 is SAFE FOR 512MB-1GB RAM
const NUM_WORKERS = 2 // CHANGED FROM 4 TO 2
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

// 4. Route messages to workers - ROUND ROBIN
let nextWorker = 0
app.post('/prove', async (req, res) => {
  try {
    const worker = workers[nextWorker]
    nextWorker = (nextWorker + 1) % NUM_WORKERS
    
    const id = Date.now().toString()
    worker.postMessage({ id,...req.body })
    
    worker.once('message', (msg) => {
      if (msg.id === id) res.json(msg.result || { error: msg.error })
    })
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