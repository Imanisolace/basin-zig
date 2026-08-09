import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import { clerkMiddleware, requireAuth } from '@clerk/express'; // <-- FIXED NAME
import db from './db.js';
import path from 'path';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 3000;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const NP_IPN_SECRET = "CYiUIAEpuQDX1RrK2El7Vtwwb02hLCmi"; // Your NowPayments secret

// MIDDLEWARE
app.use(express.json());
app.use(clerkMiddleware({ // <-- FIXED NAME
  secretKey: process.env.CLERK_SECRET_KEY
}));

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

app.use(express.static('public'));

// MERKLE TREE
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
    hash = node.position === 'left'
  ? crypto.createHash('sha256').update(node.data + hash).digest('hex')
      : crypto.createHash('sha256').update(hash + node.data).digest('hex');
  }
  return hash === root;
}

// PLANS
const LIMITS = {
  free: { prove: 1000, verify: 5000 },
  pro: { prove: Infinity, verify: Infinity }
};

const RATE_LIMITS = {
  free: { windowMs: 60 * 1000, max: 10 },
  pro: { windowMs: 60 * 1000, max: 1000 }
};

const limiters = {};
for (const tier in RATE_LIMITS) {
  limiters[tier] = rateLimit({
    windowMs: RATE_LIMITS[tier].windowMs,
    max: RATE_LIMITS[tier].max,
    keyGenerator: (req) => req.user.api_key,
    message: { error: `Rate limit exceeded for ${tier} tier` }
  });
}

async function getUser(req, res, next) {
  const result = await db.query('SELECT * FROM api_keys WHERE user_id = $1', [req.auth.userId]);
  if (result.rows.length === 0) return res.status(401).json({ error: 'No API key. Hit /apikey first' });
  req.user = result.rows[0];

  if (req.user.expires_at && new Date() >= new Date(req.user.expires_at)) {
    await db.query(`UPDATE api_keys SET tier='free', billing=NULL, expires_at=NULL WHERE id=$1`, [req.user.id]);
    req.user.tier = 'free';
  }
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

const dynamicRateLimit = (req, res, next) => {
  const tier = req.user.tier || 'free';
  return limiters[tier](req, res, next);
};

async function checkLimit(req, res, next, type) {
  const tier = req.user.tier || 'free';
  const limit = LIMITS[tier][type];
  if (limit === Infinity) return next();
  const used = type === 'prove'? req.user.prove_usage : req.user.verify_usage;
  if (used >= limit) return res.status(429).json({ error: `Monthly limit reached. Upgrade` });
  next();
}

// API ROUTES - ALL REQUIRE LOGIN
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/apikey', requireAuth(), async (req, res) => {
  try {
    const email = req.auth.sessionClaims.email;
    const user_id = req.auth.userId;

    const existing = await db.query('SELECT * FROM api_keys WHERE user_id = $1', [user_id]);
    if (existing.rows.length > 0) {
      return res.json({ apiKey: existing.rows[0].api_key, tier: existing.rows[0].tier });
    }
    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');
    await db.query('INSERT INTO api_keys(email, api_key, user_id) VALUES($1, $2, $3)', [email, apiKey, user_id]);
    res.json({ apiKey, tier: 'free' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/prove', requireAuth(), getUser, autoReset, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'prove'), async (req, res) => {
  try {
    const { item } = req.body;
    const dataset = ['alice', 'bob', 'charlie', 'dave'];
    const tree = new MerkleTree(dataset);
    const index = dataset.indexOf(item);
    if (index === -1) return res.status(404).json({ error: 'item not found' });
    const proof = tree.getProof(index);
    const root = tree.getRoot();
    await db.query('UPDATE api_keys SET prove_usage = prove_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ root, proof, target_index: index, valid: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/verify', requireAuth(), getUser, autoReset, dynamicRateLimit, async (req, res, next) => checkLimit(req, res, next, 'verify'), async (req, res) => {
  try {
    const { root, item, target_index, proof } = req.body;
    const valid = verifyProof(item, proof, root, target_index);
    await db.query('UPDATE api_keys SET verify_usage = verify_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ valid });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/usage', requireAuth(), getUser, autoReset, (req, res) => {
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
});

// NOWPAYMENTS WEBHOOK - NOW USES USER_ID
app.post('/webhook/nowpayments', express.json(), async (req, res) => {
  try {
    const data = req.body;
    const signature = req.headers['x-nowpayments-sig'];
    const sign = crypto.createHmac('sha512', NP_IPN_SECRET).update(JSON.stringify(data)).digest('hex');
    if (signature!== sign) return res.status(400).send('Invalid signature');
    if (data.payment_status!== 'finished') return res.status(200).send('Not finished');

    const userId = data.order_description; // This is Clerk userId now
    let billing = data.payment_id === '4328033905'? 'yearly' : 'monthly';
    let days = billing === 'yearly'? 365 : 30;

    const expiresAt = new Date();
    expiresAt.setUTCDate(expiresAt.getUTCDate() + days);

    await db.query(
      `UPDATE api_keys SET tier='pro', billing=$1, expires_at=$2 WHERE user_id=$3`,
      [billing, expiresAt, userId]
    );
    console.log(`Upgraded ${userId} to pro ${billing}`);
    res.status(200).send('OK');
  } catch (e) {
    console.error('Webhook error:', e);
    res.status(500).send('Server error');
  }
});

// SPA CATCH ALL
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));