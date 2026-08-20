import 'dotenv/config';
import express from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import { clerkMiddleware, requireAuth, getAuth, clerkClient } from '@clerk/express';
import db from './db.js';
import pool from './pool.js';
import path from 'path';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 8080;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const NP_IPN_SECRET = process.env.NP_IPN_SECRET;
const NP_API_KEY = process.env.NOWPAYMENTS_API_KEY;

if (!NP_IPN_SECRET) throw new Error('NP_IPN_SECRET not set in Railway Variables');
if (!NP_API_KEY) throw new Error('NOWPAYMENTS_API_KEY not set in Railway Variables');

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
    const lastReset = req.user.last_reset ? new Date(req.user.last_reset) : today;
    const isNewMonth = today.getMonth() !== lastReset.getMonth() || today.getFullYear() !== lastReset.getFullYear();
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

function checkLimit(type) {
  return (req, res, next) => {
    const tier = req.user?.tier || 'free';
    const limit = LIMITS[tier][type];
    if (limit === Infinity) return next();
    const used = type === 'prove' ? req.user.prove_usage : req.user.verify_usage;
    if (used >= limit) return res.status(429).json({ error: `Monthly limit reached. Upgrade` });
    next();
  }
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/apikey', requireAuth(), async (req, res) => {
  try {
    const { userId } = getAuth(req);
    const clerkUser = await clerkClient.users.getUser(userId);
    const email = clerkUser.emailAddresses[0]?.emailAddress || `${userId}@noemail.com`;

    const apiKey = 'zk_' + crypto.randomBytes(16).toString('hex');

    const result = await db.query(`
      INSERT INTO api_keys(email, api_key, user_id, last_reset)
      VALUES($1, $2, $3, $4)
      ON CONFLICT (user_id)
      DO UPDATE SET email = EXCLUDED.email
      RETURNING api_key, tier
    `, [email, apiKey, userId, new Date()]);

    res.json({ apiKey: result.rows[0].api_key, tier: result.rows[0].tier });
  } catch (e) {
    console.error("POST /apikey ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/create-payment', requireAuth(), async (req, res) => {
  try {
    const { userId } = getAuth(req);
    const { plan } = req.body;

    if (!['monthly', 'yearly'].includes(plan)) {
      return res.status(400).json({ error: 'plan must be monthly or yearly' });
    }

    const amount = plan === 'yearly' ? 260 : 28;
    const orderId = `${userId}_${Date.now()}`;

    const paymentRes = await fetch('https://api.nowpayments.io/v1/invoice', {
      method: 'POST',
      headers: {
        'x-api-key': NP_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        price_amount: amount,
        price_currency: "usd",
        order_id: orderId,
        order_description: `Basin Pro ${plan}`,
        ipn_callback_url: "https://basin-zig-production.up.railway.app/webhook/nowpayments",
        success_url: "https://basin-zig-production.up.railway.app/dashboard",
        cancel_url: "https://basin-zig-production.up.railway.app/dashboard"
      })
    });

    const paymentData = await paymentRes.json();
    if (!paymentData.invoice_url) throw new Error(paymentData.message || 'Failed to create payment');

    res.json({ payment_url: paymentData.invoice_url });
  } catch (e) {
    console.error("POST /create-payment ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

// Must stay in sync with wasm.zig: MAX_LEAVES and MAX_LEAF_DATA.
const MAX_ITEMS = 10000;              // matches wasm.zig MAX_LEAVES
const MAX_TOTAL_BYTES = 1024 * 1024 * 8; // matches wasm.zig MAX_LEAF_DATA (8MB)
const MAX_ITEM_LEN_VERIFY = 65536;    // matches wasm.zig MAX_VERIFY_LEAF

app.post('/prove', getUserByApiKey, autoReset, dynamicRateLimit, checkLimit('prove'), async (req, res) => {
  try {
    const { items, target_index } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items must be a non-empty array' });
    }
    if (items.length > MAX_ITEMS) {
      return res.status(400).json({ error: `too many items (max ${MAX_ITEMS})` });
    }
    if (!items.every(i => typeof i === 'string')) {
      return res.status(400).json({ error: 'items must all be strings' });
    }
    const totalBytes = items.reduce((sum, i) => sum + Buffer.byteLength(i, 'utf8'), 0);
    if (totalBytes > MAX_TOTAL_BYTES) {
      return res.status(400).json({ error: `combined item size too large (max ${MAX_TOTAL_BYTES} bytes)` });
    }
    if (!Number.isInteger(target_index) || target_index < 0 || target_index >= items.length) {
      return res.status(400).json({ error: 'target_index out of range' });
    }

    const result = await pool.dispatch({ type: 'prove', items, target_index });
    await db.query('UPDATE api_keys SET prove_usage = prove_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ root: result.root, proof: result.proof, target_index });
  } catch (e) {
    console.error("POST /prove ERROR:", e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/verify', getUserByApiKey, autoReset, dynamicRateLimit, checkLimit('verify'), async (req, res) => {
  try {
    const { item, root, proof } = req.body;

    if (typeof item !== 'string' || Buffer.byteLength(item, 'utf8') > MAX_ITEM_LEN_VERIFY) {
      return res.status(400).json({ error: `invalid item (max ${MAX_ITEM_LEN_VERIFY} bytes)` });
    }
    if (typeof root !== 'string' || !/^0x[0-9a-f]{64}$/.test(root)) {
      return res.status(400).json({ error: 'invalid root' });
    }
    if (!proof || !Array.isArray(proof.steps) || proof.steps.length === 0) {
      return res.status(400).json({ error: 'invalid proof' });
    }

    const result = await pool.dispatch({ type: 'verify', item, root, proof });
    await db.query('UPDATE api_keys SET verify_usage = verify_usage + 1 WHERE id = $1', [req.user.id]);
    res.json({ valid: result.valid });
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
    const expectedSig = crypto.createHmac('sha512', NP_IPN_SECRET).update(JSON.stringify(data)).digest('hex');

    const sigBuf = Buffer.from(signature || '', 'utf8');
    const expectedBuf = Buffer.from(expectedSig, 'utf8');
    const signaturesMatch =
      sigBuf.length === expectedBuf.length &&
      crypto.timingSafeEqual(sigBuf, expectedBuf);
    if (!signaturesMatch) return res.status(400).send('Invalid signature');

    if (data.payment_status !== 'finished') return res.status(200).send('Not finished');

    const userId = data.order_id.substring(0, data.order_id.lastIndexOf('_'));

    let billing = data.price_amount == 260 ? 'yearly' : 'monthly';
    let days = billing === 'yearly' ? 365 : 30;
    const expiresAt = new Date();
    expiresAt.setUTCDate(expiresAt.getUTCDate() + days);

    const result = await db.query(
      `UPDATE api_keys SET tier='pro', billing=$1, expires_at=$2 WHERE user_id=$3`,
      [billing, expiresAt, userId]
    );
    if (result.rowCount === 0) {
      console.error(`Webhook: no api_keys row matched user_id=${userId} (order_id=${data.order_id})`);
    } else {
      console.log(`Upgraded ${userId} to pro ${billing}`);
    }
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