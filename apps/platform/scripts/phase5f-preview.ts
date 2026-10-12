// Isolated local rendered-layout evidence; no backend, identities, credentials or RPC.
import{createServer}from"node:http";import{readFileSync}from"node:fs";
import{renderDiamond}from"../tests/diamond-ui.test";
const css=readFileSync("src/app/globals.css","utf8");
const frame=(full:boolean)=>`<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><style>${css}</style><body style="padding:12px"><main>${renderDiamond("baseball",full)}</main></body>`;
createServer((req,res)=>{res.setHeader("Content-Type","text/html; charset=utf-8");if(req.url?.startsWith("/frame")){res.end(frame(req.url.includes("full")));return;}res.end(`<!doctype html><title>Boss synthetic Diamond responsive preview</title><h1>Local layout evidence only</h1>${[1280,768,390,320].map(w=>`<h2>${w}px</h2><iframe title="Diamond ${w}" width="${w}" height="1100" src="/frame?full" style="border:0;display:block"></iframe>`).join("")}`);}).listen(4175,"127.0.0.1",()=>console.info("Synthetic Diamond layout preview ready on loopback port 4175."));
