import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import db from './db.js';

const app = express();
app.use(express.json()); // for normal routes
const PORT = process.env.PORT || 3000;

class MerkleTree {
  constructor(items) {
    this.leaves = items.map(i => this.hash(i));
    this.layers = [this.leaves];
    this.buildTree();
  }
  hash(data) {
    return crypto.createHash('sha256').update(String(data)).digest('hex');
  }
  buildTree() {
    let layer = this.leaves;
    while (layer.length > 1) {
      const nextLayer = [];
      for (let i = 0; i < layer.length; i += 2) {
        const left = layer[i];
        const right = layer[i + 1] || left;
        nextLayer.push(this.hash(left + right));
      }
      this.layers.push(nextLayer);
      layer = nextLayer;
    }
  }
  getRoot() { return this.layers[this.layers.length - 1][0] || ''; }
  getProof(index) {
    const proof = [];
    for (let i = 0; i < this.layers.length - 1; i++) {
      const layer = this.layers[i];
      const isRight = index % 2;
      const pairIndex = isRight? index - 1 : index + 1;
      if (layer[pairIndex]) proof.push(layer[pairIndex]);
      index = Math.floor(index / 2);
    }
    return proof;
  }
}

function verifyProof(leaf, proof, root, index) {
  let hash = crypto.createHash('sha256').update(String(leaf)).digest('hex');
  for (const p of proof) {
    if (index % 2 === 0) hash = crypto.createHash('sha256').update(hash + p).digest('hex');
    else hash = crypto.createHash('sha256').update(p + hash).digest('hex');
    index = Math.floor(index / 2);
  }
  return hash === root;
}

// Usage limits per month
const LIMITS = {
  free: { prove: 1000, verify: 5000 },
  pro: { prove: 50000, verify: 200000 },
  team: { prove: 500000, verify: 2000000 },
  unlimited: { prove: Infinity, verify: Infinity }
};

// Rate limits per minute
const RATE_LIMITS = {
  free: { windowMs: 60 * 1000, max: 10 },
  pro: { windowMs: 60 * 1000, max: 100 },
  team: { windowMs: 60 * 1000, max: 1000 },
  unlimited: { windowMs: 60 * 1000, max: 10000 }
};

// Middleware - checks api_keys table
async function auth(req, res, next) {
  const key = req.headers['x-api-key'];
  if (!key) return res.status(401).json({ error: 'Missing x-api-key' });

  const result = await db.query('SELECT * FROM api_keys WHERE api_key = $1', [key]);
  if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid x-api-key' });

  req.user = result.rows[0];
  next();
}

// Dynamic rate limiter per tier + per api_key
const dynamicRateLimit = async (req, res, next) => {
  const tier = req.user.tier || 'free';
  const limits = RATE_LIMITS[tier];

  return rateLimit({
    windowMs: limits.windowMs,
    max: limits.max,
    keyGenerator: () => req.user.api_key, // limit per API key
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: `Rate limit exceeded for ${tier} tier. ${limits.max} req/min` }
  })(req, res, next);
};

// Check monthly usage limits
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

// Create API Key
app.post('/apikey', async (req, res) => {
  try {
    const { email, user_id } = req.body;
    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');

    await db.query(`CREATE TABLE IF NOT EXISTS api_keys (
      id SERIAL PRIMARY KEY,
      user_id TEXT,
      email TEXT,
      api_key TEXT UNIQUE,
      tier TEXT DEFAULT 'free',
      billing TEXT DEFAULT NULL,
      paddle_subscription_id TEXT DEFAULT NULL,
      prove_usage INT DEFAULT 0,
      verify_usage INT DEFAULT 0,
      created_at TIMESTAMP DEFAULT NOW()
    )`);

    await db.query('INSERT INTO api_keys(email, api_key, user_id) VALUES($1, $2, $3)', [email, apiKey, user_id]);

    res.json({ apiKey, tier: 'free', billing: null, limits: LIMITS.free });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/prove', auth, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'prove'), async (req, res) => {
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

app.post('/verify', auth, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'verify'), async (req, res) => {
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

app.get('/usage', auth, (req, res) => {
  const tier = req.user.tier || 'free';
  res.json({
    tier: tier,
    billing: req.user.billing,
    limits: LIMITS[tier],
    rate_limit: RATE_LIMITS[tier],
    usage: { prove: req.user.prove_usage, verify: req.user.verify_usage }
  });
});

// PADDLE WEBHOOK - handles upgrades and cancels
app.post('/webhooks/paddle', express.raw({type: 'application/json'}), async (req, res) => {
  try {
    const event = JSON.parse(req.body.toString());

    if (event.event_type === 'transaction.completed') {
      const { custom_data, subscription_id, status } = event.data;
      if (status === 'completed') {
        await db.query(
          `UPDATE api_keys SET tier=$1, billing=$2, paddle_subscription_id=$3 WHERE user_id=$4`,
          [custom_data.tier, custom_data.billing, subscription_id, custom_data.user_id]
        );
        console.log(`Upgraded ${custom_data.user_id} to ${custom_data.tier} ${custom_data.billing}`);
      }
    }

    if (event.event_type === 'subscription.cancelled') {
      const subscriptionId = event.data.id;
      await db.query(
        `UPDATE api_keys SET tier='free', billing=NULL, paddle_subscription_id=NULL WHERE paddle_subscription_id=$1`,
        [subscriptionId]
      );
      console.log(`Downgraded subscription ${subscriptionId} to free`);
    }

    res.sendStatus(200);
  } catch (e) {
    console.error('Webhook error:', e);
    res.sendStatus(400);
  }
});

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));