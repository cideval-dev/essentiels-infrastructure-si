const { verify } = require('node:crypto');
const http = require('node:http');

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const DB_HOST = process.env.DB_HOST || 'localhost';

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', version: APP_VERSION, dbHost: DB_HOST }));
        return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ service: 'WebSolutions API', version: APP_VERSION }));
});

if (require.main === module) {
    server.listen(PORT, '0.0.0.0');
}

module.exports = { server };