import test from "node:test";
import assert from "node:assert/strict";
import { validMerchantReceipt } from "../src/lib/merchants/contracts";
import { performMerchantMutation, type MerchantClient } from "../src/lib/merchants/mutation";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
const id="80000000-0000-4000-8000-000000000001", other="80000000-0000-4000-8000-000000000002", origin="https://platform.boss.invalid";
const command={action:"lead.create",request_id:id,input:{market_id:other,name:"Synthetic lead",category:"automotive",source:"Synthetic referral"}};
const receipt={action:"lead.create",lead_id:id,merchant_id:null,version:1,replayed:false};
const request=()=>new Request(`${origin}/app/merchants/mutate`,{method:"POST",headers:{host:"platform.boss.invalid",origin,"content-type":"application/json"},body:JSON.stringify(command)});
const client=(rpc:MerchantClient["rpc"])=>({auth:{getClaims:async()=>({data:{claims:{sub:id,iss:`${BOSS_SUPABASE_URL}/auth/v1`,role:"authenticated",exp:Math.floor(Date.now()/1000)+3600}},error:null}),getUser:async()=>({data:{user:{id}},error:null})},rpc}) as MerchantClient;
test("canonical unconverted lead receipt is accepted after RPC commit",async()=>{
 let commits=0;
 const result=await performMerchantMutation(request(),client(async()=>{commits++;return {data:receipt,error:null};}),origin);
 assert.equal(commits,1);assert.equal(result.status,200);assert.deepEqual(result.body,{ok:true,...receipt});
});
test("only unconverted lead create/state/reassign receipts permit null merchant_id",()=>{
 for(const action of ["lead.create","lead.state","lead.reassign"])assert.equal(validMerchantReceipt({...receipt,action},action),true);
 for(const action of ["lead.convert","merchant.create","offer.status","lead.activity","sales.grant"])assert.equal(validMerchantReceipt({...receipt,action},action),false);
 for(const extra of [{merchant_id:"bad"},{lead_id:null},{resource_id:null},{person_id:id},{debug:"PRIVATE"},{_permission:"sales"}])assert.equal(validMerchantReceipt({...receipt,...extra},"lead.create"),false);
});

import { requestMerchantMutation } from "../src/lib/merchants/action";
import { parseMerchantCommand } from "../src/lib/merchants/input";
import { MERCHANT_DIAGNOSTIC_PREFIX, MERCHANT_CORRELATION_HEADER } from "../src/lib/merchants/diagnostics";
import { clearMerchantClientTrace, merchantClientRendered } from "../src/lib/merchants/diagnostics-client";
const parsed=()=>{const c=parseMerchantCommand(command);assert.ok(c);return c;};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{[MERCHANT_CORRELATION_HEADER]:id}});
function syntheticRpc() {
 let count=0;const receipts=new Map<string,{input:string;receipt:typeof receipt}>();
 const rpc:MerchantClient["rpc"]=async(_,{command:raw})=>{
  const c=raw as unknown as typeof command,previous=receipts.get(c.request_id),input=JSON.stringify(c);
  if(previous)return previous.input===input?{data:{...previous.receipt,replayed:true},error:null}:{data:null,error:{code:"PT409"}};
  count++;receipts.set(c.request_id,{input,receipt});return {data:receipt,error:null};
 };
 return {rpc,count:()=>count};
}
test("all canonical sales action receipts match finite fields before and after conversion",()=>{
 for(const action of ["lead.create","lead.state","lead.reassign","lead.convert"]){
  assert.ok(validMerchantReceipt({...receipt,action,merchant_id:other,replayed:true},action));
  for(const field of ["lead_id","merchant_id","version"]) {const v:Record<string,unknown>={...receipt,action};delete v[field];assert.equal(validMerchantReceipt(v,action),false);}
 }
 for(const action of ["sales.grant","sales.end"])assert.ok(validMerchantReceipt({action,replayed:false,resource_id:id},action));
 assert.ok(validMerchantReceipt({action:"lead.activity",replayed:false,lead_id:id,resource_id:other},"lead.activity"));
 for(const action of ["lead.activity","sales.grant"])assert.equal(validMerchantReceipt({action,replayed:false,lead_id:id,resource_id:other,version:1},action),false);
});
test("successful response, missing HTTP, bad JSON, rejected contract and non-2xx remain distinct",async()=>{
 assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:true,...receipt}))).outcome,"confirmed-success");
 assert.equal((await requestMerchantMutation(parsed(),async()=>{throw new TypeError("PRIVATE");})).outcome,"unknown");
 assert.equal((await requestMerchantMutation(parsed(),async()=>new Response("unreadable PRIVATE",{status:200}))).outcome,"unknown");
 assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:true,...receipt,debug:"PRIVATE"}))).outcome,"unknown");
 for(const status of [403,409])assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:false,outcome:"rejected",error:"Synthetic rejection"},status))).outcome,"confirmed-rejection");
 assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:false,outcome:"unknown"},503))).outcome,"unknown");
 assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:false,error:"Proxy error"},403))).outcome,"unknown");
 assert.equal((await requestMerchantMutation(parsed(),async()=>response({ok:true,...receipt},500))).outcome,"unknown");
});
test("lost post-commit response replays identical request and changed input conflicts without another lead",async()=>{
 const rpc=syntheticRpc(),c=client(rpc.rpc);let lose=true;
 const transport:typeof fetch=async(_,init)=>{
  assert.equal(init?.credentials,"same-origin");const body=JSON.parse(String(init?.body));
  const result=await performMerchantMutation(new Request(`${origin}/app/merchants/mutate`,{method:"POST",headers:{host:"platform.boss.invalid",origin,"content-type":"application/json"},body:JSON.stringify(body)}),c,origin);
  if(lose){lose=false;throw new TypeError("Synthetic lost response");}return response(result.body,result.status);
 };
 assert.equal((await requestMerchantMutation(parsed(),transport)).outcome,"unknown");assert.equal(rpc.count(),1);
 const retry=await requestMerchantMutation(parsed(),transport);assert.equal(retry.outcome,"confirmed-success");if(retry.outcome==="confirmed-success")assert.equal(retry.receipt.replayed,true);
 assert.equal((await requestMerchantMutation({...parsed(),input:{...parsed().input,name:"Changed synthetic name"}},transport)).outcome,"confirmed-rejection");assert.equal(rpc.count(),1);
});
test("server contract rejection after commit is explicitly unknown and does not forward raw fields",async()=>{
 const result=await performMerchantMutation(request(),client(async()=>({data:{...receipt,private_source:"PRIVATE"},error:null})),origin);
 assert.equal(result.status,503);assert.equal(result.body.ok,false);assert.equal("outcome" in result.body&&result.body.outcome,"unknown");assert.doesNotMatch(JSON.stringify(result),/PRIVATE|private_source/);
});
test("safe sales diagnostics cover transport, HTTP, JSON, receipt acceptance and refresh correlation",async()=>{
 const descriptor=Object.getOwnPropertyDescriptor(globalThis,"window"),original=console.info,rows:Record<string,unknown>[]=[];
 Object.defineProperty(globalThis,"window",{configurable:true,value:{location:{pathname:"/app/merchant-sales"}}});
 console.info=(line:string)=>{if(line.startsWith(MERCHANT_DIAGNOSTIC_PREFIX))rows.push(JSON.parse(line.slice(MERCHANT_DIAGNOSTIC_PREFIX.length)));};
 try {
  clearMerchantClientTrace();merchantClientRendered(other,true);
  await requestMerchantMutation(parsed(),async()=>{throw new Error("PRIVATE_PAYLOAD");});
  await requestMerchantMutation(parsed(),async()=>response({ok:false,outcome:"rejected",error:"Synthetic denial"},403));
  await requestMerchantMutation(parsed(),async()=>new Response("PRIVATE_BODY",{status:200,headers:{[MERCHANT_CORRELATION_HEADER]:id}}));
  await requestMerchantMutation(parsed(),async()=>response({ok:true,...receipt,debug:"PRIVATE_RESPONSE"}));
  await requestMerchantMutation(parsed(),async()=>response({ok:true,...receipt}));merchantClientRendered(other,true);
  const stages=rows.map(r=>r.stage);for(const stage of ["response_not_received","http_rejected","operation_rejected","json_rejected","receipt_rejected","response_accepted","client_rendered"])assert.ok(stages.includes(stage));
  assert.equal(rows.at(-1)?.parent_correlation_id,id);assert.ok(rows.every(r=>r.route==="/app/merchant-sales"));assert.doesNotMatch(JSON.stringify(rows),/PRIVATE|Synthetic lead|80000000-0000-4000-8000-000000000002.*name/);
 }finally{console.info=original;clearMerchantClientTrace();if(descriptor)Object.defineProperty(globalThis,"window",descriptor);else Reflect.deleteProperty(globalThis,"window");}
});
