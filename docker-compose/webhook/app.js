const http = require('http');

const requestListener = async function (req, res) {
    const buffers = [];

    for await (const chunk of req) {
        buffers.push(chunk);
    }

    const data = Buffer.concat(buffers).toString();
    res.writeHead(200);
    res.end('Zzzzzzzzzzzzzzzzzzzzzzzzzzzz');
    console.log(req.method + ' ' + req.url + ' user-agent: ' + req.headers['user-agent'] + "\n" + data);
    res.end();
}

const server = http.createServer(requestListener);
server.listen(13000);
