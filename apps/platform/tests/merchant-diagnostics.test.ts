import test from "node:test";
import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import ErrorPage from "../src/app/error";
import { onRequestError } from "../src/instrumentation";
import { emitMerchantDiagnostic, merchantDiagnosticRecord, merchantErrorDetails, merchantDiagnosticPath, MERCHANT_CORRELATION_HEADER, MERCHANT_DIAGNOSTIC_PREFIX, type MerchantDiagnosticInput } from "../src/lib/merchants/diagnostics";
import { clearMerchantClientTrace, merchantClientDiagnostic, merchantClientRendered, merchantClientReceipt } from "../src/lib/merchants/diagnostics-client";
const id="90000000-0000-4000-8000-000000000001",next="90000000-0000-4000-8000-000000000002";
const base:MerchantDiagnosticInput={correlationId:id,stage:"server_exception",phase:"server-component",observedAt:"src/instrumentation.ts",classification:"exception"};
const capture=(run:()=>void)=>{const lines:string[]=[],original=console.info;console.info=(line:string)=>{lines.push(line);};try{run();}finally{console.info=original;}return lines.map(line=>{assert.ok(line.startsWith(MERCHANT_DIAGNOSTIC_PREFIX));return JSON.parse(line.slice(MERCHANT_DIAGNOSTIC_PREFIX.length));});};
test("diagnostic record reconstructs only explicit fields and never serializes confidential error or caller properties",()=>{
 const sentinel="SYNTHETIC_CONFIDENTIAL_SENTINEL";
 const error=Object.assign(new TypeError(sentinel),{digest:"123456789",password:sentinel,cookie:sentinel,session:sentinel,proof:sentinel,capability:sentinel,body:{person_id:sentinel},headers:{authorization:sentinel}});
 error.stack=`TypeError: ${sentinel}\n    at fail (/private/${sentinel}/src/components/merchants/portal.tsx:30:14)\n    at ${sentinel} (/private/unknown.ts:1:2)`;
 const record=merchantDiagnosticRecord({...base,error,request:sentinel,merchant_id:sentinel,user_id:sentinel,url:sentinel} as MerchantDiagnosticInput);
 assert.ok(record);assert.doesNotMatch(JSON.stringify(record),new RegExp(sentinel));
 assert.deepEqual(Object.keys(record).sort(),["schema","timestamp","commit","deployment","route","phase","stage","correlation_id","parent_correlation_id","observed_at","classification","operation","http_status","exception_category","digest","source"].sort());
 assert.equal(record.exception_category,"TypeError");assert.equal(record.digest,"123456789");
 assert.deepEqual(record.source,{file:"src/components/merchants/portal.tsx",line:30,column:14});
 assert.match(record.timestamp,/^\d{4}-\d{2}-\d{2}T.*Z$/);assert.equal(record.route,"/app/merchants");
});
test("source capture ignores message lines, query-bearing frames, unlisted files and unbounded positions",()=>{
 for(const stack of ["Error: src/components/merchants/portal.tsx:30:14", "Error\n at /private/unlisted.ts:1:2", "Error\n at /src/components/merchants/portal.tsx:30:14?secret=PRIVATE", "Error\n at /src/components/merchants/portal.tsx:0:0", "x".repeat(32001)])assert.equal(merchantErrorDetails({stack}).source,null);
 assert.deepEqual(merchantErrorDetails({stack:"Error\n at render (webpack://src/app/app/merchants/page.tsx:8:22)"}).source,{file:"src/app/app/merchants/page.tsx",line:8,column:22});
});
test("unknown exception names, confidential digests, arbitrary phases/stages and unsafe build identifiers are not logged",()=>{
 assert.deepEqual(merchantErrorDetails({name:"PRIVATE_NAME",digest:"PRIVATE_DIGEST",message:"PRIVATE"}),{exception_category:"UnknownError",digest:null,source:null});
 for(const extra of [{correlationId:"PRIVATE"},{stage:"PRIVATE"},{phase:"PRIVATE"},{observedAt:"PRIVATE"}])assert.equal(merchantDiagnosticRecord({...base,...extra} as MerchantDiagnosticInput),null);
 const previousCommit=process.env.BOSS_DIAGNOSTIC_COMMIT,previousDeploy=process.env.BOSS_DIAGNOSTIC_DEPLOY;
 try{process.env.BOSS_DIAGNOSTIC_COMMIT="PRIVATE";process.env.BOSS_DIAGNOSTIC_DEPLOY="PRIVATE";const r=merchantDiagnosticRecord({...base,status:NaN});assert.equal(r?.commit,"local");assert.equal(r?.deployment,"local");assert.equal(r?.http_status,null);}finally{if(previousCommit===undefined)delete process.env.BOSS_DIAGNOSTIC_COMMIT;else process.env.BOSS_DIAGNOSTIC_COMMIT=previousCommit;if(previousDeploy===undefined)delete process.env.BOSS_DIAGNOSTIC_DEPLOY;else process.env.BOSS_DIAGNOSTIC_DEPLOY=previousDeploy;}
});
test("untrusted error getters and failing diagnostic sinks cannot break application work",()=>{
 const error=new Proxy({}, {get(){throw new Error("PRIVATE");}});
 assert.doesNotThrow(()=>emitMerchantDiagnostic({...base,error},()=>{throw new Error("PRIVATE");}));
 assert.equal(merchantErrorDetails(error).exception_category,"UnknownError");
});
test("Next server hook captures merchant failures, keeps the request correlation, and omits headers/query/context values",()=>{
 const result=capture(()=>onRequestError(Object.assign(new TypeError("PRIVATE"),{digest:"4567"}),{path:"/app/merchants?merchant_id=PRIVATE&token=PRIVATE",method:"PRIVATE",headers:{[MERCHANT_CORRELATION_HEADER]:id,cookie:"PRIVATE",authorization:"PRIVATE"}},{routerKind:"App Router",routePath:"PRIVATE",routeType:"render",renderSource:"server-rendering",revalidateReason:undefined}));
 assert.equal(result.length,1);assert.equal(result[0].correlation_id,id);assert.equal(result[0].phase,"server-render");assert.equal(result[0].digest,"4567");assert.equal(result[0].http_status,null);assert.doesNotMatch(JSON.stringify(result),/PRIVATE/);
});
test("Next hook emits nothing for unrelated routes and never guesses an HTTP 500 for a streamed error",()=>{
 const result=capture(()=>onRequestError(new Error("PRIVATE"),{path:"/app/account?secret=PRIVATE",method:"GET",headers:{}},{routerKind:"App Router",routePath:"PRIVATE",routeType:"render",revalidateReason:undefined}));assert.deepEqual(result,[]);
 assert.ok(merchantDiagnosticPath("/app/merchants?private=VALUE"));assert.equal(merchantDiagnosticPath("/app/merchants-other"),false);
});
test("browser read, mutation receipt and refreshed read form a finite correlation chain without storing identity",()=>{
 const original=Object.getOwnPropertyDescriptor(globalThis,"window");Object.defineProperty(globalThis,"window",{configurable:true,value:{location:{pathname:"/app/merchants"}}});
 try{clearMerchantClientTrace();const rows=capture(()=>{merchantClientRendered(id);merchantClientReceipt(next,200,"offer.status");merchantClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/merchants/shared.tsx"});merchantClientRendered(id);});assert.equal(rows[1].parent_correlation_id,id);assert.equal(rows[2].correlation_id,next);assert.equal(rows[3].parent_correlation_id,next);}finally{clearMerchantClientTrace();if(original)Object.defineProperty(globalThis,"window",original);else Reflect.deleteProperty(globalThis,"window");}
});
test("browser boundary and runtime diagnostics are merchant-only and do not record arbitrary error text",()=>{
 const original=Object.getOwnPropertyDescriptor(globalThis,"window");const location={pathname:"/app/merchants"};Object.defineProperty(globalThis,"window",{configurable:true,value:{location}});
 try{clearMerchantClientTrace();let rows=capture(()=>merchantClientDiagnostic({stage:"error_boundary",observedAt:"src/app/error.tsx",classification:"exception",error:Object.assign(new Error("PRIVATE"),{digest:"4567"})}));assert.equal(rows[0].phase,"client-boundary");assert.equal(rows[0].digest,"4567");assert.doesNotMatch(JSON.stringify(rows),/PRIVATE/);location.pathname="/app/payments";rows=capture(()=>merchantClientDiagnostic({stage:"client_exception",observedAt:"src/instrumentation-client.ts",error:new Error("PRIVATE")}));assert.deepEqual(rows,[]);}finally{clearMerchantClientTrace();if(original)Object.defineProperty(globalThis,"window",original);else Reflect.deleteProperty(globalThis,"window");}
});
test("error boundary keeps the supported retry interface and never renders exception details",()=>{
 const html=renderToStaticMarkup(createElement(ErrorPage,{error:Object.assign(new Error("PRIVATE"),{digest:"4567"}),retry(){}}));assert.match(html,/We couldn’t load this page|Try again|Go to home/);assert.doesNotMatch(html,/PRIVATE|4567/);
});

test("sales route and finite sales operation categories preserve diagnostic privacy",()=>{
 assert.ok(merchantDiagnosticPath("/app/merchant-sales?person_id=PRIVATE"));assert.equal(merchantDiagnosticPath("/app/merchant-sales-other"),false);
 for(const operation of ["lead.create","lead.activity","lead.state","lead.reassign","lead.convert","sales.grant","sales.end","sales.read"] as const){
  const r=merchantDiagnosticRecord({...base,operation,observedAt:"src/components/merchants/sales.tsx"});assert.equal(r?.route,"/app/merchant-sales");assert.equal(r?.operation,operation);
 }
 const r=merchantDiagnosticRecord({...base,operation:"PRIVATE" as MerchantDiagnosticInput["operation"],route:"PRIVATE" as MerchantDiagnosticInput["route"]});assert.equal(r?.operation,null);assert.equal(r?.route,"/app/merchants");
});
test("sales server errors use the exact sales route and safe known source",()=>{
 const rows=capture(()=>onRequestError({name:"TypeError",message:"PRIVATE",stack:"TypeError: PRIVATE\n at render (/src/app/app/merchant-sales/page.tsx:20:2)"},{path:"/app/merchant-sales?lead=PRIVATE",method:"GET",headers:{[MERCHANT_CORRELATION_HEADER]:id,cookie:"PRIVATE"}},{routerKind:"App Router",routePath:"PRIVATE",routeType:"render",renderSource:"server-rendering",revalidateReason:undefined}));
 assert.equal(rows[0].route,"/app/merchant-sales");assert.deepEqual(rows[0].source,{file:"src/app/app/merchant-sales/page.tsx",line:20,column:2});assert.doesNotMatch(JSON.stringify(rows),/PRIVATE/);
});
test("accepted mutation then error boundary is a refresh failure without losing confirmed response evidence",()=>{
 const original=Object.getOwnPropertyDescriptor(globalThis,"window");Object.defineProperty(globalThis,"window",{configurable:true,value:{location:{pathname:"/app/merchant-sales"}}});
 try{clearMerchantClientTrace();const rows=capture(()=>{merchantClientRendered(id,true);merchantClientReceipt(next,200,"lead.create");merchantClientDiagnostic({stage:"response_accepted",observedAt:"src/lib/merchants/action.ts",classification:"confirmed-success",operation:"lead.create"});merchantClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/merchants/shared.tsx"});merchantClientDiagnostic({stage:"error_boundary",observedAt:"src/app/error.tsx",classification:"exception",error:new TypeError("PRIVATE")});});assert.equal(rows.at(-1).classification,"refresh-failed");assert.equal(rows.at(-1).correlation_id,next);assert.equal(rows[2].classification,"confirmed-success");assert.doesNotMatch(JSON.stringify(rows),/PRIVATE/);}finally{clearMerchantClientTrace();if(original)Object.defineProperty(globalThis,"window",original);else Reflect.deleteProperty(globalThis,"window");}
});
