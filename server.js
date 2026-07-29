import express from 'express';
import crypto from 'crypto';
import Stripe from 'stripe';
import db from './db.js'; // <-- we added this

const app = express();
app.use(express.json());

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_123');
const PORT = process.env.PORT || 3000;

// REMOVED: const db = { users: new Map() };

// Simple Merkle Tree that won't crash
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

// Middleware - now checks Postgres
async function auth(req, res, next) {
  const key = req.headers['x-api-key'];
  if (!key) return res.status(401).json({ error: 'Missing x-api-key' });
  
  const result = await db.query('SELECT * FROM users WHERE api_key = $1', [key]);
  if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid x-api-key' });
  
  req.user = result.rows[0];
  next();
}

// Routes
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/apikey', async (req, res) => {
  const { email } = req.body;
  const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');
  
  await db.query(`CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email TEXT,
    api_key TEXT UNIQUE,
    tier TEXT DEFAULT 'free',
    prove_usage INT DEFAULT 0,
    verify_usage INT DEFAULT 0
  )`);
  
  await db.query('INSERT INTO users(email, api_key) VALUES($1, $2)', [email, apiKey]);
  
  res.json({ apiKey, tier: 'free', limits: { prove: 1000, verify: 5000, price: 0 } });
});

app.post('/prove', auth, async (req, res) => {
  try {
    const { item } = req.body;
    if (!item) return res.status(400).json({ error: 'item required' });

    const dataset = ['alice', 'bob', 'charlie', 'dave'];
    const tree = new MerkleTree(dataset);
    const index = dataset.indexOf(item);
    if (index === -1) return res.status(404).json({ error: 'item not found' });

    const proof = tree.getProof(index);
    const root = tree.getRoot();

    await db.query('UPDATE users SET prove_usage = prove_usage + 1 WHERE id = $1', [req.user.id]);

    res.json({ root, proof, target_index: index, valid: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/verify', auth, async (req, res) => {
  try {
    const { root, item, target_index, proof } = req.body;
    const valid = verifyProof(item, proof, root, target_index);
    await db.query('UPDATE users SET verify_usage = verify_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ valid });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/usage', auth, (req, res) => {
  res.json({ 
    tier: req.user.tier, 
    usage: { prove: req.user.prove_usage, verify: req.user.verify_usage } 
  });
});

app.listen(PORT, () => console.log(`Basin ZK API running on ${PORT}`));