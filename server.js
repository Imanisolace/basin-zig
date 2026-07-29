import express from 'express'
import path from 'path'
import { Worker } from 'worker_threads'
import { fileURLToPath } from 'url'
import crypto from 'crypto'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

// ===== IN-MEMORY DB FOR NOW. Use Redis/Postgres later =====
const db = {
  // apiKey: { tier, usage: {prove, verify}, email }
  "demo_key_free_123": { tier: "free", usage: { prove: 0, verify: 0 }, email: "demo@test.com" }
}

const TIERS = {
  free: { prove: 1000, verify: 5000, price: 0 },
  builder: { prove: 50000, verify: 200000, price: 29 },
  scale: { prove: 500000, verify: 2000000, price: 199 }
}

// ===== WORKERS =====
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

// ===== MIDDLEWARE: API KEY + RATE LIMIT + USAGE =====
function authAndTrack(endpoint) {
  return async (req, res, next) => {
    const apiKey = req.headers['x-api-key']
    if (!apiKey ||!db[apiKey]) {
      return res.status(401).json({ error: "Missing or invalid x-api-key header" })
    }

    const user = db[apiKey]
    const tier = TIERS[user.tier]

    // Check limits
    if (user.usage[endpoint] >= tier[endpoint]) {
      return res.status(429).json({
        error: `Monthly limit reached for ${endpoint}. Upgrade at /billing`,
        limit: tier[endpoint],
        used: user.usage[endpoint]
      })
    }

    // Rate limit: 10 req/sec for free
    // TODO: add proper redis rate limiter later

    // Track usage AFTER success
    res.on('finish', () => {
      if (res.statusCode < 400) {
        user.usage[endpoint] += 1
      }
    })

    next()
  }
}

// ===== ROUTES =====
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime(), workers: workers.length })
})

app.get('/', (req, res) => {
  res.json({ name: 'Basin ZK API v1', status: 'live', workers: NUM_WORKERS })
})

// Create API Key - Free tier by default
app.post('/apikey', (req, res) => {
  const { email } = req.body
  const newKey = `zk_${crypto.randomBytes(16).toString('hex')}`
  db[newKey] = { tier: "free", usage: { prove: 0, verify: 0 }, email }
  res.json({ apiKey: newKey, tier: "free", limits: TIERS.free })
})

// Prove with auth
app.post('/prove', authAndTrack('prove'), async (req, res) => {
  const { result, error } = await callWorker('prove', req.body)
  if (error) res.status(500).json({ error })
  else res.json({...result, _credits_used: 1 })
})

// Verify with auth
app.post('/verify', authAndTrack('verify'), async (req, res) => {
  const { result, error } = await callWorker('verify', req.body)
  if (error) res.status(500).json({ error })
  else res.json({...result, _credits_used: 1 })
})

// Usage endpoint
app.get('/usage', (req, res) => {
  const apiKey = req.headers['x-api-key']
  if (!apiKey ||!db[apiKey]) return res.status(401).json({ error: "Invalid key" })
  const user = db[apiKey]
  res.json({ tier: user.tier, usage: user.usage, limits: TIERS[user.tier] })
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Basin ZK API v1 live on ${PORT} with ${NUM_WORKERS} workers`)
})

process.on('SIGTERM', () => {
  workers.forEach(w => w.terminate())
  process.exit(0)
})