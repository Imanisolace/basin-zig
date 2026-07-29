import express from 'express'
import path from 'path'
import { Worker } from 'worker_threads'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

const NUM_WORKERS = 2
const workers = []
const pending = new Map()

console.log(`Starting ${NUM_WORKERS} workers...`)
for (let i = 0; i < NUM_WORKERS; i++) {
  const worker = new Worker(path.join(__dirname, 'worker.js'))
  
  worker.on('message', (msg) => {
    const { id, result, error } = msg
    const resolve = pending.get(id)
    if (resolve) {
      pending.delete(id)
      clearTimeout(resolve.timeout)
      resolve.cb({ result, error })
    }
  })
  
  worker.on('error', (err) => console.error(`Worker ${i} error:`, err))
  workers.push(worker)
}

let nextWorker = 0
function callWorker(type, data) {
  return new Promise((resolve) => {
    const worker = workers[nextWorker]
    nextWorker = (nextWorker + 1) % NUM_WORKERS
    const id = Date.now().toString() + Math.random().toString(16).slice(2)
    
    const timeout = setTimeout(() => {
      pending.delete(id)
      resolve({ error: "Request timed out after 30s" })
    }, 30000)
    
    pending.set(id, { cb: resolve, timeout })
    worker.postMessage({ id, type,...data })
  })
}

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime(), workers: workers.length })
})

app.get('/', (req, res) => {
  res.json({ name: 'Basin ZK API v1', status: 'live', workers: NUM_WORKERS })
})

app.post('/prove', async (req, res) => {
  const { result, error } = await callWorker('prove', req.body)
  if (error) res.status(500).json({ error })
  else res.json(result)
})

// FIXED: verify endpoint
app.post('/verify', async (req, res) => {
  const { result, error } = await callWorker('verify', req.body)
  if (error) res.status(500).json({ error })
  else res.json(result)
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Basin ZK API v1 live on ${PORT} with ${NUM_WORKERS} workers`)
})

process.on('SIGTERM', () => {
  workers.forEach(w => w.terminate())
  process.exit(0)
})