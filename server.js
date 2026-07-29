import express from 'express'
import path from 'path'
import { Worker } from 'worker_threads'
import { fileURLToPath } from 'url'
import crypto from 'crypto'
import Stripe from 'stripe'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

// STRIPE: put these in Railway ENV vars
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY)
const STRIPE_PRICE_BUILDER = process.env.STRIPE_PRICE_BUILDER // price_xxx
const STRIPE_PRICE_SCALE = process.env.STRIPE_PRICE_SCALE // price_xxx
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET

app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

// ===== IN-MEMORY DB. REPLACE WITH POSTGRES LATER =====
const db = {
  // apiKey: { tier, usage, email, customerId }
  "demo_key_free_123": { tier: "free", usage: { prove: 0, verify: 0 }, email: "demo@test.com", customerId: null }
}

const TIERS = {
  free: { prove: 1000, verify: 5000, price: 0 },
  builder: { prove: 50000, verify: 200000, price: 29 },
  scale: { prove: 500000, verify: 2000000, price: 199 }
}

const PRICE_TO_TIER = {
  [STRIPE_PRICE_BUILDER]: "builder",
  [STRIPE_PRICE_SCALE]: "scale"
}

// ===== WORKERS =====
const NUM_WORKERS = 2
const workers = []
const pending = new Map()
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
  workers.push(worker)
}
let nextWorker = 0
function callWorker(type, data) {
  return new Promise((resolve) => {
    const worker = workers[nextWorker]
    nextWorker = (nextWorker + 1) % NUM_WORKERS
    const id = Date.now().toString() + Math.random().toString(16).slice(2)
    const timeout = setTimeout(() => { pending.delete(id); resolve({ error: "Timeout" }) }, 30000)
    pending.set(id, { cb: resolve, timeout })
    worker.postMessage({ id, type,...data })
  })
}

// ===== MIDDLEWARE =====
function authAndTrack(endpoint) {
  return (req, res, next) => {
    const apiKey = req.headers['x-api-key']
    if (!apiKey ||!db[apiKey]) return res.status(401).json({ error: "Invalid x-api-key" })
    const user = db[apiKey]
    const tier = TIERS[user.tier]
    if (user.usage[endpoint] >= tier[endpoint]) {
      return res.status(429).json({ error: `Limit reached. Upgrade at /billing`, limit: tier[endpoint], used: user.usage[endpoint] })
    }
    res.on('finish', () => { if (res.statusCode < 400) user.usage[endpoint] += 1 })
    next()
  }
}

// ===== ROUTES =====
app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }))
app.get('/', (req, res) => res.json({ name: 'Basin ZK API v2', status: 'live' }))

// 1. Create API Key
app.post('/apikey', (req, res) => {
  const { email } = req.body
  const newKey = `zk_${crypto.randomBytes(16).toString('hex')}`
  db[newKey] = { tier: "free", usage: { prove: 0, verify: 0 }, email, customerId: null }
  res.json({ apiKey: newKey, tier: "free", limits: TIERS.free })
})

// 2. Create Stripe Checkout
app.post('/billing', async (req, res) => {
  const { apiKey, priceId } = req.body
  if (!db[apiKey]) return res.status(401).json({ error: "Invalid key" })

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `https://your-domain.com/usage`,
    cancel_url: `https://your-domain.com/`,
    client_reference_id: apiKey,
    customer_email: db[apiKey].email
  })
  res.json({ url: session.url })
})

// 3. Stripe Webhook - upgrades tier
app.post('/webhook', express.raw({type: 'application/json'}), async (req, res) => {
  const sig = req.headers['stripe-signature']
  let event
  try {
    event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET)
  } catch (err) { return res.status(400).send(`Webhook Error: ${err.message}`) }

  if (event.type === 'checkout.session.completed') {
    const apiKey = event.data.object.client_reference_id
    const priceId = event.data.object.line_items?.data[0]?.price.id
    if (db[apiKey] && PRICE_TO_TIER[priceId]) {
      db[apiKey].tier = PRICE_TO_TIER[priceId]
      db[apiKey].customerId = event.data.object.customer
      db[apiKey].usage = { prove: 0, verify: 0 } // reset on upgrade
    }
  }
  res.json({ received: true })
})

// 4. API Endpoints
app.post('/prove', authAndTrack('prove'), async (req, res) => {
  const { result, error } = await callWorker('prove', req.body)
  if (error) res.status(500).json({ error })
  else res.json({...result })
})

app.post('/verify', authAndTrack('verify'), async (req, res) => {
  const { result, error } = await callWorker('verify', req.body)
  if (error) res.status(500).json({ error })
  else res.json({...result })
})

// 5. Check usage
app.get('/usage', (req, res) => {
  const apiKey = req.headers['x-api-key']
  if (!apiKey ||!db[apiKey]) return res.status(401).json({ error: "Invalid key" })
  const user = db[apiKey]
  res.json({ tier: user.tier, usage: user.usage, limits: TIERS[user.tier] })
})

app.listen(PORT, '0.0.0.0', () => console.log(`Basin ZK API v2 live on ${PORT}`))