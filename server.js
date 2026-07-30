import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import db from './db.js';

const app = express();
app.use(express.json());
const PORT = process.env.PORT || 3000;

// ... MerkleTree and verifyProof stays the same ...

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

async function auth(req, res, next) {
  const key = req.headers['x-api-key'];
  if (!key) return res.status(401).json({ error: 'Missing x-api-key' });

  const result = await db.query('SELECT * FROM api_keys WHERE api_key = $1', [key]);
  if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid x-api-key' });

  req.user = result.rows[0];
  next();
}

// NEW: Auto reset usage every new month
async function autoReset(req, res, next) {
  const today = new Date();
  const lastReset = new Date(req.user.last_reset);
  
  const isNewMonth = today.getMonth() !== lastReset.getMonth() || today.getFullYear() !== lastReset.getFullYear();
  
  if (isNewMonth) {
    await db.query('UPDATE api_keys SET prove_usage=0, verify_usage=0, last_reset=$1 WHERE id=$2', [today, req.user.id]);
    req.user.prove_usage = 0;
    req.user.verify_usage = 0;
  }
  next();
}

const dynamicRateLimit = async (req, res, next) => {
  const tier = req.user.tier || 'free';
  const limits = RATE_LIMITS[tier];
  return rateLimit({
    windowMs: limits.windowMs,
    max: limits.max,
    keyGenerator: () => req.user.api_key,
    message: { error: `Rate limit exceeded for ${tier} tier. ${limits.max} req/min` }
  })(req, res, next);
};

async function checkLimit(req, res, next, type) {
  const tier = req.user.tier || 'free';
  const limit = LIMITS[tier][type];
  const used = type === 'prove'? req.user.prove_usage : req.user.verify_usage;
  if (used >= limit) {
    return res.status(429).json({ error: `Monthly limit reached for ${tier} tier. Upgrade at /pricing` });
  }
  next();
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/apikey', async (req, res) => {
  try {
    const { email, user_id } = req.body;
    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');
    await db.query(`CREATE TABLE IF NOT EXISTS api_keys (id SERIAL PRIMARY KEY, user_id TEXT, email TEXT, api_key TEXT UNIQUE, tier TEXT DEFAULT 'free', billing TEXT DEFAULT NULL, paddle_subscription_id TEXT DEFAULT NULL, prove_usage INT DEFAULT 0, verify_usage INT DEFAULT 0, last_reset DATE DEFAULT CURRENT_DATE, created_at TIMESTAMP DEFAULT NOW())`);
    await db.query('INSERT INTO api_keys(email, api_key, user_id) VALUES($1, $2, $3)', [email, apiKey, user_id]);
    res.json({ apiKey, tier: 'free', billing: null, limits: LIMITS.free });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

// Add autoReset to both routes
app.post('/prove', auth, autoReset, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'prove'), async (req, res) => {
  try {
    const { item } = req.body;
    if (!item) return res.status(400).json({ error: 'item required' });
    const dataset = ['alice', 'bob', 'charlie', 'dave'];
    const tree = new MerkleTree(dataset);
    const index = dataset.indexOf(item);
    if (index === -1) return res.status(404).json({ error: 'item not found' });
    const proof = tree.getProof(index);
    const root = tree.getRoot();
    await db.query('UPDATE api_keys SET prove_usage = prove_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ root, proof, target_index: index, valid: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/verify', auth, autoReset, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'verify'), async (req, res) => {
  try {
    const { root, item, target_index, proof } = req.body;
    const valid = verifyProof(item, proof, root, target_index);
    await db.query('UPDATE api_keys SET verify_usage = verify_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ valid });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/usage', auth, autoReset, (req, res) => {
  const tier = req.user.tier || 'free';
  res.json({
    tier: tier,
    billing: req.user.billing,
    limits: LIMITS[tier],
    rate_limit: RATE_LIMITS[tier],
    usage: { prove: req.user.prove_usage, verify: req.user.verify_usage },
    last_reset: req.user.last_reset
  });
});

// ... Paddle webhook stays the same ...

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));