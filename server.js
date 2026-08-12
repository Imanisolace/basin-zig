import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import { clerkMiddleware, requireAuth, getAuth, clerkClient } from '@clerk/express';
import db from './db.js';
import path from 'path';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 8080;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const NP_IPN_SECRET = process.env.NP_IPN_SECRET;
if (!NP_IPN_SECRET) throw new Error('NP_IPN_SECRET not set in Railway Variables');

app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.use(express.json());
app.use(clerkMiddleware({ secretKey: process.env.CLERK_SECRET_KEY }));

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-api-key');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

app.use(express.static('public'));

const DATASET = ['alice', 'bob', 'charlie', 'dave'];

class MerkleTree {
  constructor(leaves) {
    this.leaves = leaves.map(x => crypto.createHash('sha256').update(x).digest('hex'));
    this.layers = [this.leaves];
    while (this.layers[this.layers.length - 1].length > 1) {
      this.layers.push(this.getNextLayer(this.layers[this.layers.length - 1]));
    }
  }
  getNextLayer(layer) {
    const nextLayer = [];
    for (let i = 0; i < layer.length; i += 2) {
      const left = layer[i];
      const right = layer[i + 1] || left;
      nextLayer.push(crypto.createHash('sha256').update(left + right).digest('hex'));
    }
    return nextLayer;
  }
  getRoot() { return this.layers[this.layers.length - 1][0]; }
  getProof(index) {
    const proof = [];
    for (let i = 0; i < this.layers.length - 1; i++) {
      const layer = this.layers[i];
      const isRightNode = index % 2;
      const pairIndex = isRightNode? index - 1 : index + 1;
      if (pairIndex < layer.length) {
        proof.push({ position: isRightNode? 'left' : 'right', data: layer[pairIndex] });
      }
      index = Math.floor(index / 2);
    }
    return proof;
  }
}

function verifyProof(leaf, proof, root, index) {
  let hash = crypto.createHash('sha256').update(leaf).digest('hex');
  for (const node of proof) {
    if (node.position === 'left') {
      hash = crypto.createHash('sha256').update(node.data + hash).digest('hex');
    } else {
      hash = crypto.createHash('sha256').update(hash + node.data).digest('hex');
    }
  }
  return hash === root;
}

const LIMITS = { free: { prove: 1000, verify: 5000 }, pro: { prove: Infinity, verify: Infinity } };
const RATE_LIMITS = { free: { windowMs: 60 * 1000, max: 10 }, pro: { windowMs: 60 * 1000, max: 1000 } };
const limiters = {};
for (const tier in RATE_LIMITS) {
  limiters[tier] = rateLimit({
    windowMs: RATE_LIMITS[tier].windowMs,
    max: RATE_LIMITS[tier].max,
    keyGenerator: (req) => req.user?.api_key || 'unknown',
    message: { error: `Rate limit exceeded for ${tier} tier` }
  });
}

async function getUserByApiKey(req, res, next) {
  try {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey) return res.status(401).json({ error: 'Missing x-api-key header' });
    const result = await db.query('SELECT * FROM api_keys WHERE api_key = $1', [apiKey]);
    if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid API key' });
    req.user = result.rows[0];
    if (req.user.expires_at && new Date() >= new Date(req.user.expires_at)) {
      await db.query(`UPDATE api_keys SET tier='free', billing=NULL, expires_at=NULL WHERE id=$1`, [req.user.id]);
      req.user.tier = 'free';
    }
    next();
  } catch (e) {
    console.error("getUserByApiKey ERROR:", e);
    res.status(500).json({ error: e.message });
  }
}

async function getUser(req, res, next) {
  try {
    const { userId } = getAuth(req);
    if (!userId) return res.status(401).json({ error: 'Not authenticated' });
    const result = await db.query('SELECT * FROM api_keys WHERE user_id = $1', [userId]);
    if (result.rows.length === 0) return res.status(401).json({ error: 'No API key. Hit /apikey first' });
    req.user = result.rows[0];
    if (req.user.expires_at && new Date() >= new Date(req.user.expires_at)) {
      await db.query(`UPDATE api_keys SET tier='free', billing=NULL, expires_at=NULL WHERE id=$1`, [req.user.id]);
      req.user.tier = 'free';
    }
    next();
  } catch (e) {
    console.error("getUser ERROR:", e);
    res.status(500).json({ error: e.message });
  }
}

async function autoReset(req, res, next) {
  try {
    const today = new Date();
    const lastReset = req.user.last_reset? new Date(req.user.last_reset) : today;
    const isNewMonth = today.getMonth()!== lastReset.getMonth() || today.getFullYear()!== lastReset.getFullYear();
    if (isNewMonth) {
      await db.query('UPDATE api_keys SET prove_usage=0, verify_usage=0, last_reset=$1 WHERE id=$2', [today, req.user.id]);
      req.user.prove_usage = 0;
      req.user.verify_usage = 0;
    }
    next();
  } catch (e) {
    console.error("autoReset ERROR:", e);
    res.status(500).json({ error: e.message });
  }
}

const dynamicRateLimit = (req, res, next) => {
  const tier = req.user?.tier || 'free';
  const limiter = limiters[tier] || limiters.free;
  return limiter(req, res, next);
};

function checkLimit(req, res, next, type) {
  const tier = req.user?.tier || 'free';
  const limit = LIMITS[tier][type];
  if (limit === Infinity) return next();
  const used = type === 'prove'? req.user.prove_usage : req.user.verify_usage;
  if (used >= limit) return res.status(429).json({ error: `Monthly limit reached. Upgrade` });
  next();
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/apikey', requireAuth(), async (req, res) => {
  try {
    const { userId } = getAuth(req);
    const clerkUser = await clerkClient.users.getUser(userId);
    const email = clerkUser.emailAddresses[0]?.emailAddress || `${userId}@noemail.com`;
    const existing = await db.query('SELECT * FROM api_keys WHERE user_id = $1', [userId]);
    if (existing.rows.length > 0) {
      return res.json({ apiKey: existing.rows[0].api_key, tier: existing.rows[0].tier });
    }
    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');
    await db.query('INSERT INTO api_keys(email, api_key, user_id, last_reset) VALUES($1, $2, $3, $4)', [email, apiKey, userId, new Date()]);
    res.json({ apiKey, tier: 'free' });
  } catch (e) {
    console.error("POST /apikey ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/prove', getUserByApiKey, autoReset, dynamicRateLimit, (req, res, next) => checkLimit(req, res, next, 'prove'), async (req, res) => {
  try {
    const { item } = req.body;
    const tree = new MerkleTree(DATASET);
    const index = DATASET.indexOf(item);
    if (index === -1) return res.status(404).json({ error: 'item not found' });
    const proof = tree.getProof(index);
    const root = tree.getRoot();
    await db.query('UPDATE api_keys SET prove_usage = prove_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ root, proof, target_index: index, valid: true });
  } catch (e) {
    console.error("POST /prove ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/verify', getUserByApiKey, autoReset, dynamicRateLimit, (req, res, next) => checkLimit(req, res, next, 'verify'), async (req, res) => {
  try {
    const { root, item, target_index, proof } = req.body;
    const valid = verifyProof(item, proof, root, target_index);
    await db.query('UPDATE api_keys SET verify_usage = verify_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ valid });
  } catch (e) {
    console.error("POST /verify ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/usage', requireAuth(), getUser, autoReset, (req, res) => {
  try {
    const tier = req.user.tier || 'free';
    res.json({
      email: req.user.email,
      tier: tier,
      billing: req.user.billing,
      limits: LIMITS[tier],
      usage: { prove: req.user.prove_usage, verify: req.user.verify_usage },
      expires_at: req.user.expires_at,
      apiKey: req.user.api_key
    });
  } catch (e) {
    console.error("GET /usage ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/webhook/nowpayments', express.json(), async (req, res) => {
  try {
    const data = req.body;
    const signature = req.headers['x-nowpayments-sig'];
    const sign = crypto.createHmac('sha512', NP_IPN_SECRET).update(JSON.stringify(data)).digest('hex');
    if (signature!== sign) return res.status(400).send('Invalid signature');
    if (data.payment_status!== 'finished') return res.status(200).send('Not finished');
    const userId = data.order_id;
    let billing = data.iid === '4328033905'? 'yearly' : 'monthly';
    let days = billing === 'yearly'? 365 : 30;
    const expiresAt = new Date();
    expiresAt.setUTCDate(expiresAt.getUTCDate() + days);
    await db.query(`UPDATE api_keys SET tier='pro', billing=$1, expires_at=$2 WHERE user_id=$3`, [billing, expiresAt, userId]);
    console.log(`Upgraded ${userId} to pro ${billing}`);
    res.status(200).send('OK');
  } catch (e) {
    console.error("POST /webhook/nowpayments ERROR:", e);
    res.status(500).send('Server error');
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));