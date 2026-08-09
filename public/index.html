<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Basin - ZK Proof API</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0a0a; color: #ddd; margin: 0; padding: 0; line-height: 1.6; }
  .container { max-width: 1000px; margin: 0 auto; padding: 20px; }
  nav { padding: 20px 0; border-bottom: 1px solid #222; }
  nav a { color: #888; margin: 0 15px; text-decoration: none; font-weight: 500; cursor: pointer; }
  nav a:hover { color: #fff; }
 .card { background: #111; padding: 25px; border-radius: 12px; margin-top: 20px; border: 1px solid #222; }
 .pricing { display: flex; gap: 20px; margin-top: 30px; flex-wrap: wrap; }
 .plan { background: #111; padding: 25px; border-radius: 12px; flex: 1; border: 1px solid #333; min-width: 280px; }
 .plan.pro { border: 2px solid #4f46e5; background: #0f0f1a; }
 .btn { background: #4f46e5; color: #fff; padding: 12px 24px; border: none; border-radius: 8px; text-decoration: none; display: inline-block; margin-top: 15px; cursor: pointer; font-weight: 600; }
 .btn:hover { background: #4338ca; }
 .unlimited { color: #22c55e; font-weight: bold; font-size: 18px; }
 code { background: #222; padding: 4px 8px; border-radius: 4px; font-size: 14px; }
 pre { background: #111; padding: 15px; border-radius: 8px; overflow-x: auto; border: 1px solid #333; }
 .copy-btn { background: #333; padding: 6px 12px; font-size: 12px; margin-left: 10px; border: none; color: #fff; border-radius: 6px; cursor: pointer; }
 footer { margin-top: 80px; padding: 30px 0; text-align: center; color: #555; border-top: 1px solid #222; }
 h1 { font-size: 48px; margin-bottom: 10px; }
 h2 { font-size: 32px; margin-top: 40px; }
 .legal { max-width: 800px; }
</style>
</head>
<body>
  <div class="container">
    <nav>
      <a onclick="showPage('home')">Basin</a>
      <a onclick="showPage('docs')">Docs</a>
      <a onclick="showPage('dashboard')">Dashboard</a>
      <a onclick="showPage('terms')">Terms</a>
      <a onclick="showPage('privacy')">Privacy</a>
      <a onclick="showPage('refund')">Refund</a>
    </nav>

    <div id="app"></div>

    <footer>
      <p>© 2026 Basin ZK API. support@basin.ai</p>
    </footer>
  </div>

<script>
const app = document.getElementById('app');

function showPage(page) {
  window.history.pushState({}, '', '/' + page);
  render(page);
}

function render(page) {
  if(page === 'dashboard') renderDashboard();
  else if(page === 'docs') renderDocs();
  else if(page === 'terms') renderTerms();
  else if(page === 'privacy') renderPrivacy();
  else if(page === 'refund') renderRefund();
  else renderHome();
}

// 1. HOME + PRICING
function renderHome() {
  app.innerHTML = `
  <div style="text-align: center; padding: 60px 0;">
    <h1>ZK Proof API</h1>
    <p style="font-size: 20px; color: #aaa;">Generate and verify Merkle proofs in 200ms. No infra needed.</p>
    <button onclick="showPage('docs')" class="btn">View Docs</button>
  </div>
  
  <h2 style="text-align: center;">Simple Pricing</h2>
  <div class="pricing">
    <div class="plan">
      <h3>Free</h3><p style="font-size: 28px; font-weight: bold;">$0</p>
      <p>1000 Prove / 5000 Verify per month</p><p>10 req/min</p>
    </div>
    <div class="plan pro">
      <h3>Pro Monthly</h3><p style="font-size: 28px; font-weight: bold;">$28<span style="font-size: 16px; color: #aaa;">/mo</span></p>
      <p class="unlimited">UNLIMITED Prove & Verify</p><p>1000 req/min</p>
      <a href="https://nowpayments.io/payment/link/4900460102" class="btn">Upgrade Monthly</a>
    </div>
    <div class="plan pro">
      <h3>Pro Yearly</h3><p style="font-size: 28px; font-weight: bold;">$260<span style="font-size: 16px; color: #aaa;">/yr</span></p>
      <p class="unlimited">UNLIMITED Prove & Verify</p><p>1000 req/min</p><p>Save 22%</p>
      <a href="https://nowpayments.io/payment/link/4328033905" class="btn">Upgrade Yearly</a>
    </div>
  </div>`;
}

// 2. DASHBOARD
async function renderDashboard() {
  app.innerHTML = `<h2>Dashboard</h2><div class="card" id="dashboard-card">Loading...</div>`;
  let apiKey = localStorage.getItem('apiKey');
  if(!apiKey) {
    apiKey = prompt("Enter your API Key to view dashboard:");
    if(!apiKey) return document.getElementById('dashboard-card').innerText = 'API Key required';
    localStorage.setItem('apiKey', apiKey);
  }
  
  const res = await fetch('/usage', { headers: { 'x-api-key': apiKey } });
  if(!res.ok) {
    localStorage.removeItem('apiKey');
    return document.getElementById('dashboard-card').innerHTML = 'Invalid API Key. <button class="btn" onclick="renderDashboard()">Try Again</button>';
  }
  const data = await res.json();
  
  const proveLimit = data.limits.prove === Infinity? 'Unlimited' : data.limits.prove.toLocaleString();
  const verifyLimit = data.limits.verify === Infinity? 'Unlimited' : data.limits.verify.toLocaleString();
  
  document.getElementById('dashboard-card').innerHTML = `
    <h3>Account Overview</h3>
    <p><b>Plan:</b> <span style="text-transform: capitalize;">${data.tier}</span> ${data.billing? `(${data.billing})` : ''}</p>
    <p><b>API Key:</b> <code id="key">${apiKey}</code> 
    <button class="copy-btn" onclick="navigator.clipboard.writeText(document.getElementById('key').innerText); this.innerText='Copied!'">Copy</button></p>
    <hr style="border-color: #333; margin: 20px 0;">
    <p><b>Prove Usage:</b> ${data.usage.prove.toLocaleString()} / ${proveLimit}</p>
    <p><b>Verify Usage:</b> ${data.usage.verify.toLocaleString()} / ${verifyLimit}</p>
    <p><b>Rate Limit:</b> ${data.rate_limit.max} requests/min</p>
    <p><b>Expires:</b> ${data.expires_at? new Date(data.expires_at).toLocaleDateString() : 'Never'}</p>
    ${data.tier === 'free'? '<button onclick="showPage(\'home\')" class="btn" style="margin-top: 20px;">Upgrade to Pro</button>' : ''}
  `;
}

// 3. DOCS
function renderDocs() {
  app.innerHTML = `
  <h2>API Documentation</h2>
  <p>Base URL: <code>https://basin-zig-production.up.railway.app</code></p>
  <p>Auth: Send <code>x-api-key</code> header</p>

  <h3>1. Get API Key</h3>
  <pre>POST /apikey
{ "email": "you@email.com", "user_id": "clerk_123" }</pre>

  <h3>2. Generate Proof</h3>
  <pre>curl -X POST https://basin-zig-production.up.railway.app/prove \
-H "x-api-key: zk_YOUR_KEY" \
-H "Content-Type: application/json" \
-d '{"item":"alice"}'</pre>

  <h3>3. Verify Proof</h3>
  <pre>curl -X POST https://basin-zig-production.up.railway.app/verify \
-H "x-api-key: zk_YOUR_KEY" \
-H "Content-Type: application/json" \
-d '{ "root": "...", "item": "alice", "target_index": 0, "proof": [...] }'</pre>

  <h3>4. Check Usage</h3>
  <pre>curl https://basin-zig-production.up.railway.app/usage \
-H "x-api-key: zk_YOUR_KEY"</pre>`;
}

// 4. TERMS
function renderTerms() {
  app.innerHTML = `
  <div class="legal">
    <h2>Terms of Service</h2>
    <p>Last Updated: August 9, 2026</p>
    <p>By using Basin ZK API, you agree to these terms.</p>
    <h3>1. Service</h3><p>Basin provides an API to generate and verify Merkle proofs. We provide the service "as is" with 99.9% uptime goal.</p>
    <h3>2. Usage</h3><p>Free tier has limits. Pro tier is unlimited. You may not abuse, DDoS, or reverse engineer the API.</p>
    <h3>3. Payments</h3><p>Pro subscriptions are billed via NowPayments in crypto. Subscriptions auto-renew monthly or yearly.</p>
    <h3>4. Liability</h3><p>We are not liable for any damages from using the API. Use at your own risk.</p>
    <p>Contact: support@basin.ai</p>
  </div>`;
}

// 5. PRIVACY
function renderPrivacy() {
  app.innerHTML = `
  <div class="legal">
    <h2>Privacy Policy</h2>
    <p>Last Updated: August 9, 2026</p>
    <h3>1. Data We Collect</h3><p>We collect: Email, API Key, Usage stats: prove/verify counts. We do NOT store the data you send to /prove.</p>
    <h3>2. How We Use Data</h3><p>To provide the API, bill you, and prevent abuse. Your API usage is private.</p>
    <h3>3. Payments</h3><p>Payments are processed by NowPayments. We do not store your crypto wallet info.</p>
    <h3>4. Data Deletion</h3><p>Email support@basin.ai to delete your account and data.</p>
  </div>`;
}

// 6. REFUND
function renderRefund() {
  app.innerHTML = `
  <div class="legal">
    <h2>Refund Policy</h2>
    <p>Last Updated: August 9, 2026</p>
    <h3>Crypto Payments</h3>
    <p>Due to the nature of crypto payments, all sales are final. We do not offer refunds for Pro subscriptions.</p>
    <h3>Service Issues</h3>
    <p>If our API is down for more than 48 hours in a month, contact us for account credit.</p>
    <h3>Contact</h3>
    <p>For any issues: support@basin.ai</p>
  </div>`;
}

// Load page based on URL on first load
const initialPage = window.location.pathname.replace('/', '') || 'home';
render(initialPage);
</script>
</body>
</html>