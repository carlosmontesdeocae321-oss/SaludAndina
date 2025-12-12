const fs = require('fs');
const https = require('https');

const serviceId = process.argv[2] || 'srv-d4nnet1r0fns73den81g';
const apiKey = process.env.RENDER_API_KEY;
if (!apiKey) {
  console.error('RENDER_API_KEY not set');
  process.exit(2);
}

const inFile = 'render_envs.json';
if (!fs.existsSync(inFile)) {
  console.error('render_envs.json not found');
  process.exit(2);
}

let raw = fs.readFileSync(inFile);
// Try to decode as utf8 and strip surrounding garbage/BOM
try {
  raw = raw.toString('utf8');
} catch (e) {
  raw = String(raw);
}
raw = raw.replace(/^\uFEFF/, '');
const firstIdx = raw.indexOf('[');
if (firstIdx > 0) raw = raw.slice(firstIdx);
const parsed = JSON.parse(raw);
// parsed is array of {envVar:{key,value}, cursor:...}
const envs = parsed.map(e => {
  const ev = e.envVar || e;
  return { key: ev.key, value: ev.value, secure: false };
});

// Ensure FORCE_JSON present
if (!envs.find(x => x.key === 'FORCE_JSON')) {
  envs.push({ key: 'FORCE_JSON', value: 'true', secure: false });
}

const body = JSON.stringify(envs);

const options = {
  method: 'PUT',
  hostname: 'api.render.com',
  path: `/v1/services/${serviceId}/env-vars`,
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    try { console.log(JSON.parse(data)); } catch (e) { console.log(data); }
  });
});

req.on('error', (e) => { console.error('Request error', e.message); process.exit(2); });
req.write(body);
req.end();
