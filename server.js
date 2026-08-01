import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import db from './db.js';
import path from 'path'; 
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 3000;

// Needed for ES modules to get __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Manual CORS - no package needed
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// SERVE TEST PAGE
app.get('/test', (req, res) => {
  res.sendFile(path.join(__dirname, 'test.html'));
});

// WELCOME PAGE FOR PADDLE REDIRECT
app.get('/welcome', (req, res) => {
  res.send('<h1>Payment Successful!</h1><p>Check Railway logs. Your API key is now upgraded.</p><a href="/test">Back to Test</a>');
});

// Need raw body for Paddle webhook signature verification
app.use((req, res, next) => {
  if (req.path === '/webhooks/paddle') {
    express.raw({type: 'application/json'})(req, res, next);
  } else {
    express.json()(req, res, next);
  }
});

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

// Auto reset usage every new month
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
    await db.query('INSERT INTO api_keys(email, api_key, user_id) VALUES($1, $2, $3)', [email, apiKey, user_id]);
    res.json({ apiKey, tier: 'free', billing: null, limits: LIMITS.free });
  } catch (e) {
    console.error(e);
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

// PADDLE WEBHOOK - with signature verification
app.post('/webhooks/paddle', async (req, res) => {
  try {
    const signature = req.headers['paddle-signature'];
    const secret = process.env.PADDLE_WEBHOOK_SECRET;

    if (!signature ||!secret) return res.status(400).send('Missing signature or secret');

    const [ts, h1] = signature.split(';').map(s => s.split('=')[1]);
    const signedPayload = `${ts}:${req.body.toString()}`;
    const expectedSignature = crypto.createHmac('sha256', secret).update(signedPayload).digest('hex');

    if (h1!== expectedSignature) {
      console.error('Invalid Paddle signature');
      return res.status(401).send('Invalid signature');
    }

    const event = JSON.parse(req.body.toString());
    console.log('Paddle Event:', event.event_type);

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

    if (event.event_type === 'subscription.cancelled' || event.event_type === 'subscription.paused') {
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