const http = require('http');
const fs = require('fs');

const logFile = '/var/log/alerts/alert.log';
fs.mkdirSync('/var/log/alerts', { recursive: true });

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && (req.url === '/webhook' || req.url === '/')) {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      const timestamp = new Date().toISOString();
      let alertInfo = body;
      try {
        const parsed = JSON.parse(body);
        if (parsed.alerts && parsed.alerts.length > 0) {
          const first = parsed.alerts[0];
          alertInfo = `STATUS=${first.status} RULE="${first.labels ? first.labels.alertname : 'Unknown'}" SEVERITY=${first.labels ? first.labels.severity : 'N/A'} SUMMARY="${first.annotations ? first.annotations.summary : ''}"`;
        }
      } catch (e) {}

      const logLine = `[${timestamp}] ALERT_WEBHOOK_RECEIVED: ${alertInfo}\n`;
      console.log(logLine.trim());
      fs.appendFileSync(logFile, logLine);

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', received_at: timestamp }));
    });
  } else if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK\n');
  } else {
    res.writeHead(404);
    res.end();
  }
});

const PORT = 8080;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Alert Sink listening on port ${PORT}...`);
});
