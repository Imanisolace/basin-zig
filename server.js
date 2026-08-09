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
const NP_IPN_SECRET = "CYiUIAEpuQDX1RrK2El7Vtwwb02hLCmi"; // NowPayments secret

// Manual CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// SERVE STATIC FILES
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

// PLANS - PRO IS UNLIMITED
const LIMITS = {
  free: { prove: 1000, verify: 5000 },
  pro: { prove: Infinity, verify: Infinity },
  team: { prove: Infinity, verify: Infinity },
  unlimited: { prove: Infinity, verify: Infinity }
};

const RATE_LIMITS = {
  free: { windowMs: 60 * 1000, max: 10 },
  pro: { windowMs: 60 * 1000, max: 1000 },
  team: { windowMs: 60 * 1000, max: 5000 },
  unlimited: { windowMs: 60 * 1000, max: 10000 }
};

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

  // Auto downgrade if expired
  if (req.user.expires_at && new Date() >= new Date(req.user.expires_at)) {
    await db.query(`UPDATE api_keys SET tier='free', billing=NULL, expires_at=NULL WHERE id=$1`, [req.user.id]);
    req.user.tier = 'free';
    req.user.billing = null;
    req.user.expires_at = null;
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
  if (limit === Infinity) return next(); // Skip check for unlimited
  const used = type === 'prove'? req.user.prove_usage : req.user.verify_usage;
  if (used >= limit) return res.status(429).json({ error: `Monthly limit reached for ${tier} tier. Upgrade at /` });
  next();
}

app.use(express.json());

// API ROUTES
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'Basin ZK API' }));

app.post('/apikey', async (req, res) => {
  try {
    const { email, user_id } = req.body;
    if (!email ||!user_id) return res.status(400).json({ error: 'email and user_id required' });
    const existing = await db.query('SELECT * FROM api_keys WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.json({ apiKey: existing.rows[0].api_key, tier: existing.rows[0].tier, billing: existing.rows[0].billing, limits: LIMITS[existing.rows[0].tier] });
    }
    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');
    await db.query('INSERT INTO api_keys(email, api_key, user_id) VALUES($1, $2, $3)', [email, apiKey, user_id]);
    res.json({ apiKey, tier: 'free', billing: null, limits: LIMITS.free });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

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
    last_reset: req.user.last_reset,
    expires_at: req.user.expires_at
  });
});

// NOWPAYMENTS WEBHOOK
app.post('/webhook/nowpayments', express.json(), async (req, res) => {
  try {
    const data = req.body;
    const signature = req.headers['x-nowpayments-sig'];

    const sign = crypto.createHmac('sha512', NP_IPN_SECRET)
                .update(JSON.stringify(data))
                .digest('hex');

    if (signature!== sign) {
      console.error("Invalid NowPayments signature");
      return res.status(400).send('Invalid signature');
    }

    if (data.payment_status!== 'finished') {
      return res.status(200).send('Not finished yet');
    }

    const iid = data.payment_id;
    const email = data.order_description; // make sure you set this in NowPayments link

    let billing = 'monthly';
    let days = 30;

    if (iid === '4900460102') { // Monthly $28
      billing = 'monthly';
      days = 30;
    } else if (iid === '4328033905') { // Yearly $260
      billing = 'yearly';
      days = 365;
    } else {
      return res.status(400).send('Unknown iid');
    }

    const expiresAt = new Date();
    expiresAt.setUTCDate(expiresAt.getUTCDate() + days);
    expiresAt.setUTCHours(23, 59, 59, 999);

    await db.query(
      `UPDATE api_keys SET tier='pro', billing=$1, expires_at=$2 WHERE email=$3`,
      [billing, expiresAt, email]
    );
    console.log(`Upgraded ${email} to pro ${billing}`);
    res.status(200).send('OK');
  } catch (e) {
    console.error('NowPayments webhook error:', e);
    res.status(500).send('Server error');
  }
});

// CATCH ALL - SERVE INDEX.HTML FOR SPA ROUTING
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));