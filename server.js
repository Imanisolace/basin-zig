import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import db from './db.js';
import path from 'path';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 3000;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PADDLE_API_KEY = process.env.PADDLE_API_KEY?.trim(); // <-- ADDED.trim() to remove spaces
const YOUR_DOMAIN = process.env.RAILWAY_PUBLIC_DOMAIN || 'your-railway-url.up.railway.app';

// Manual CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

app.get('/test', (req, res) => res.sendFile(path.join(__dirname, 'test.html')));
app.get('/welcome', (req, res) => res.send('<h1>Payment Successful!</h1><p>Check Railway logs. Your API key is now upgraded.</p><a href="/test">Back to Test</a>'));

app.use((req, res, next) => {
  if (req.path === '/webhooks/paddle') express.raw({type: 'application/json'})(req, res, next);
  else express.json()(req, res, next);
});

// MERKLE TREE - same as before
class MerkleTree { /*... keep your class... */ }
function verifyProof(leaf, proof, root, index) { /*... keep... */ }

const LIMITS = {
  free: { prove: 1000, verify: 5000 },
  pro: { prove: 50000, verify: 200000 },
  team: { prove: 500000, verify: 2000000 },
  unlimited: { prove: Infinity, verify: Infinity }
};

const RATE_LIMITS = {
  free: { windowMs: 60 * 1000, max: 10 },
  pro: { windowMs: 60 * 1000, max: 100 },
  team: { windowMs: 60 * 1000, max: 1000 },
  unlimited: { windowMs: 60 * 1000, max: 10000 }
};

// FIX 1: Create limiters once at startup, not per request
const limiters = {};
for (const tier in RATE_LIMITS) {
  limiters[tier] = rateLimit({
    windowMs: RATE_LIMITS[tier].windowMs,
    max: RATE_LIMITS[tier].max,
    keyGenerator: (req) => req.user.api_key,
    message: { error: `Rate limit exceeded for ${tier} tier. ${RATE_LIMITS[tier].max} req/min` }
  });
}

async function auth(req, res, next) {
  const key = req.headers['x-api-key'];
  if (!key) return res.status(401).json({ error: 'Missing x-api-key' });
  const result = await db.query('SELECT * FROM api_keys WHERE api_key = $1', [key]);
  if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid x-api-key' });
  req.user = result.rows[0];
  next();
}

async function autoReset(req, res, next) {
  const today = new Date();
  const lastReset = new Date(req.user.last_reset);
  const isNewMonth = today.getMonth()!== lastReset.getMonth() || today.getFullYear()!== lastReset.getFullYear();
  if (isNewMonth) {
    await db.query('UPDATE api_keys SET prove_usage=0, verify_usage=0, last_reset=$1 WHERE id=$2', [today, req.user.id]);
    req.user.prove_usage = 0;
    req.user.verify_usage = 0;
  }
  next();
}

// FIX 2: Middleware to pick the right limiter
const dynamicRateLimit = (req, res, next) => {
  const tier = req.user.tier || 'free';
  return limiters[tier](req, res, next);
};

async function checkLimit(req, res, next, type) {
  const tier = req.user.tier || 'free';
  const limit = LIMITS[tier][type];
  const used = type === 'prove'? req.user.prove_usage : req.user.verify_usage;
  if (used >= limit) return res.status(429).json({ error: `Monthly limit reached for ${tier} tier. Upgrade at /pricing` });
  next();
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/create-checkout', auth, async (req, res) => {
  try {
    const { price_id } = req.body;
    const { id: user_id, email, tier, paddle_customer_id } = req.user;
    if (tier!== 'free') return res.status(400).json({ error: 'Already on a paid plan' });

    const PADDLE_API_URL = PADDLE_API_KEY.startsWith('pdl_live_')? 'https://api.paddle.com' : 'https://sandbox-api.paddle.com';
    console.log('Creating checkout for:', { price_id, email, user_id });

    let customerId = paddle_customer_id;
    if (!customerId) {
      const customerRes = await fetch(`${PADDLE_API_URL}/customers`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${PADDLE_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email })
      });
      const customerData = await customerRes.json();
      if (!customerRes.ok) {
        console.error('Paddle Customer Error:', customerData);
        return res.status(customerRes.status).json(customerData);
      }
      customerId = customerData.data.id;
      await db.query('UPDATE api_keys SET paddle_customer_id=$1 WHERE id=$2', [customerId, req.user.id]);
    }

    const payload = {
      items: [{ price_id, quantity: 1 }],
      customer_id: customerId,
      customer_email: email,
      custom_data: { user_id: String(user_id), tier: 'pro', billing: price_id.includes('year')? 'yearly' : 'monthly' },
      return_url: `https://${YOUR_DOMAIN}/welcome`
    };

    const response = await fetch(`${PADDLE_API_URL}/transactions`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${PADDLE_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await response.json();
    if (!response.ok) { console.error('Paddle Response:', response.status, data); return res.status(response.status).json(data); }
    res.json({ url: data.data.checkout.url });
  } catch (e) { console.error('Create checkout error:', e); res.status(500).json({ error: e.message }); }
});

app.post('/apikey', async (req, res) => { /*... keep... */ });
app.post('/prove', auth, autoReset, dynamicRateLimit, (req, res, next) => checkLimit(req, res, next, 'prove'), async (req, res) => { /*... keep... */ });
app.post('/verify', auth, autoReset, dynamicRateLimit, (req, res, next) => checkLimit(req, res, next, 'verify'), async (req, res) => { /*... keep... */ });
app.get('/usage', auth, autoReset, (req, res) => { /*... keep... */ });
app.post('/webhooks/paddle', async (req, res) => { /*... keep... */ });

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));