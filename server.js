import express from 'express'
import path from 'path'
import { Worker } from 'worker_threads'
import { fileURLToPath } from 'url'

// Needed for __dirname in ESM
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

// Middleware
app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

// 1. Spawn workers - 2 is SAFE FOR 512MB-1GB RAM on Railway
const NUM_WORKERS = 2 
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

// 2. Route messages to workers - ROUND ROBIN
let nextWorker = 0

// 3. Healthcheck for Railway
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'ok', 
    uptime: process.uptime(),
    workers: workers.length 
  })
})

// 4. Root route
app.get('/', (req, res) => {
  res.json({ name: 'Basin ZK API v1', status: 'live', workers: NUM_WORKERS })
})

// 5. PROVE endpoint
app.post('/prove', async (req, res) => {
  try {
    const worker = workers[nextWorker]
    nextWorker = (nextWorker + 1) % NUM_WORKERS

    const id = Date.now().toString() + Math.random().toString(16).slice(2)
    
    // THE KEY FIX: add type: 'prove' so worker.js knows what to do
    worker.postMessage({ id, type: 'prove',...req.body })

    // Timeout in case worker hangs
    const timeout = setTimeout(() => {
      return res.status(504).json({ error: "Request timed out after 30s" })
    }, 30000)

    worker.once('message', (msg) => {
      clearTimeout(timeout)
      if (msg.id === id) {
        if (msg.error) res.status(500).json({ error: msg.error })
        else res.json(msg.result)
      }
    })
  } catch (e) {
    console.error(e)
    res.status(500).json({ error: e.message })
  }
})

// 6. VERIFY endpoint
app.post('/verify', async (req, res) => {
  try {
    const worker = workers[nextWorker]
    nextWorker = (nextWorker + 1) % NUM_WORKERS

    const id = Date.now().toString() + Math.random().toString(16).slice(2)
    
    // THE KEY FIX: add type: 'verify'
    worker.postMessage({ id, type: 'verify',...req.body })

    const timeout = setTimeout(() => {
      return res.status(504).json({ error: "Request timed out after 30s" })
    }, 30000)

    worker.once('message', (msg) => {
      clearTimeout(timeout)
      if (msg.id === id) {
        if (msg.error) res.status(500).json({ error: msg.error })
        else res.json(msg.result)
      }
    })
  } catch (e) {
    console.error(e)
    res.status(500).json({ error: e.message })
  }
})

// 7. Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Basin ZK API v1 live on ${PORT} with ${NUM_WORKERS} workers`)
})

// 8. Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing workers')
  workers.forEach(w => w.terminate())
  process.exit(0)
})