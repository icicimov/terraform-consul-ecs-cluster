var http = require('http');
var os = require('os');

//var port = process.argv[2];
var port = 8080;

var server = http.createServer(function (req, res) {
  if (req.url === "/") {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('I am: ' + os.hostname() + '\n');
  }
  else if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end("Service status: RUNNING\n");
  }
  else {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("404 error! Page not found\n");
  }
}).listen(port);
console.log('Server running at http://127.0.0.1:' + port);
