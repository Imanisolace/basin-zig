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

// Manual CORS
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

//... KEEP ALL YOUR MERKLE + AUTH + LIMIT CODE EXACTLY THE SAME...

// PADDLE WEBHOOK - FIXED to use custom_data
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
      const { custom_data, subscription_id, status } = event.data; // CHANGED: custom_data not customData
      if (status === 'completed' && custom_data) {
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