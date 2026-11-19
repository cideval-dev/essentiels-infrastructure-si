const assert = require('node:assert/strict');
const http = require('node:http');
const {server} = require('./server');

server.listen(0, '127.0.0.1', () => {
    const {port} = server.address();
    http.get(`http://127.0.0.1:${port}/health`, (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
            try {
                assert.equal(res.statusCode, 200);
                const data = JSON.parse(body);
                assert.equal(data.status, 'ok');
                console.log('Tests OK: ', data);
                server.close();
            } catch (err) {
                console.error('Tests failed: ', err.message);
                server.close();
                process.exit(1);
            }
        });
    });
});
