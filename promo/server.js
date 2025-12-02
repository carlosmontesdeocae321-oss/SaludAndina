const http = require('http');
const path = require('path');
const fs = require('fs');

const PORT = process.env.PORT || 8080;
const ROOT = __dirname;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.txt': 'text/plain; charset=utf-8'
};

function resolvePath(urlPath) {
  const sanitized = decodeURI(urlPath.split('?')[0]);
  const normalized = path.normalize(sanitized).replace(/^([.][.][/\\])+/, '');
  const candidate = path.join(ROOT, normalized);
  return candidate;
}

function serveFile(filePath, res) {
  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': contentType });
  const stream = fs.createReadStream(filePath);
  stream.pipe(res);
  stream.on('error', () => {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Error interno del servidor');
  });
}

const server = http.createServer((req, res) => {
  const requestedPath = resolvePath(req.url === '/' ? '/index.html' : req.url);

  fs.stat(requestedPath, (err, stats) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Recurso no encontrado');
      return;
    }

    const target = stats.isDirectory() ? path.join(requestedPath, 'index.html') : requestedPath;

    fs.access(target, fs.constants.R_OK, accessErr => {
      if (accessErr) {
        res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Acceso denegado');
        return;
      }

      serveFile(target, res);
    });
  });
});

server.listen(PORT, () => {
  console.log(`Servidor estático listo en http://localhost:${PORT}`);
});
