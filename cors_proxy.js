const http = require('http');
const https = require('https');
const url = require('url');

const TARGET = 'https://api-uniflow.kernelforge.codes';
const PORT = 3333;

const server = http.createServer((req, res) => {
  // Set CORS headers for all requests
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const targetUrl = TARGET + req.url;
  const parsedUrl = url.parse(targetUrl);

  const options = {
    hostname: parsedUrl.hostname,
    port: 443,
    path: parsedUrl.path,
    method: req.method,
    headers: { ...req.headers, host: parsedUrl.hostname },
  };
  delete options.headers['origin'];
  delete options.headers['referer'];

  const proxyReq = https.request(options, (proxyRes) => {
    // Remove CORS headers from backend (we set our own)
    const headers = { ...proxyRes.headers };
    delete headers['access-control-allow-origin'];
    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (e) => {
    res.writeHead(502);
    res.end(JSON.stringify({ error: e.message }));
  });

  req.pipe(proxyReq, { end: true });
});

server.listen(PORT, () => {
  console.log(`🚀 CORS Proxy running at http://localhost:${PORT}`);
  console.log(`   Proxying to ${TARGET}`);
  console.log(`   Use http://localhost:${PORT} as baseUrl in your Flutter app`);
});
