'use strict';

const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 8080;
const VERSION = process.env.APP_VERSION || 'dev';
const startTime = Date.now();

const metrics = {
  requestsTotal: 0,
  requestsByPath: Object.create(null),
};

function recordRequest(path) {
  metrics.requestsTotal += 1;
  metrics.requestsByPath[path] = (metrics.requestsByPath[path] || 0) + 1;
}

function renderMetrics() {
  const uptime = (Date.now() - startTime) / 1000;
  const lines = [
    '# HELP app_uptime_seconds Process uptime in seconds.',
    '# TYPE app_uptime_seconds gauge',
    `app_uptime_seconds ${uptime.toFixed(3)}`,
    '# HELP app_requests_total Total HTTP requests handled.',
    '# TYPE app_requests_total counter',
    `app_requests_total ${metrics.requestsTotal}`,
    '# HELP app_requests_by_path_total HTTP requests by path.',
    '# TYPE app_requests_by_path_total counter',
  ];
  for (const [path, count] of Object.entries(metrics.requestsByPath)) {
    lines.push(`app_requests_by_path_total{path="${path}"} ${count}`);
  }
  return lines.join('\n') + '\n';
}

const server = http.createServer((req, res) => {
  const path = (req.url || '/').split('?')[0];
  recordRequest(path);

  if (path === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    return res.end('ok\n');
  }

  if (path === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    return res.end(renderMetrics());
  }

  if (path === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ message: 'hello', version: VERSION, hostname: os.hostname() }, null, 2) + '\n');
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('not found\n');
});

function shutdown(signal) {
  console.log(`received ${signal}, shutting down`);
  server.close(() => process.exit(0));
}

if (require.main === module) {
  server.listen(PORT, () => console.log(`listening on :${PORT} (version=${VERSION})`));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

module.exports = server;
