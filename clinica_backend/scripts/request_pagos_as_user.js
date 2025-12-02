const http = require('http');

const options = {
  hostname: '127.0.0.1',
  port: 3000,
  path: '/api/pagos',
  method: 'GET',
  headers: {
    'x-usuario': 'keo',
    'x-clave': 'keo'
  }
};

const req = http.request(options, res => {
  let data = '';
  res.on('data', chunk => data += chunk.toString());
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    try { console.log('Body:', JSON.parse(data)); } catch (e) { console.log('Body:', data); }
  });
});
req.on('error', err => console.error('Request error', err));
req.end();
