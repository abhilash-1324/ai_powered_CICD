const http=require('http');http.createServer((q,r)=>{r.writeHead(200,{'content-type':'application/json'});r.end(JSON.stringify({service:'sre-demo',status:'UP'}));}).listen(process.env.PORT||3000);
