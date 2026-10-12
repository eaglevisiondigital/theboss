// Disposable loopback-only TLS bridge. No production credentials or external requests.
import https from 'node:https';
import http from 'node:http';
import {readFileSync} from 'node:fs';
const dir=process.env.BOSS_LOCAL_TLS_DIR;
if(!/^\/tmp\/boss-fundraising-tls\.[^/]+$/.test(dir??''))throw Error('Private disposable certificate directory required');
https.createServer({key:readFileSync(dir+'/key.pem'),cert:readFileSync(dir+'/cert.pem')},(request,response)=>{
 const upstream=http.request({hostname:'localhost',port:31408,path:request.url,method:request.method,headers:request.headers},r=>{response.writeHead(r.statusCode,r.headers);r.pipe(response);});
 upstream.on('error',()=>{response.writeHead(503);response.end();});request.pipe(upstream);
}).listen(31443,'localhost');
