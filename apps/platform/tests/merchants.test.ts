import test from "node:test";
import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { parseMerchantCommand, merchantQuery, merchantPageLink } from "../src/lib/merchants/input";
import { validMerchantData, validMerchantTerms, validMerchantReceipt, type MerchantData } from "../src/lib/merchants/contracts";
import { performMerchantMutation, merchantFailure, type MerchantClient } from "../src/lib/merchants/mutation";
import { MerchantPortal, RedemptionConsole } from "../src/components/merchants/portal";
import { MerchantDirectory } from "../src/components/merchants/discovery";
import { MerchantSales } from "../src/components/merchants/sales";
import { TermsSummary } from "../src/components/merchants/shared";
import { safeNotificationDestination, projectNotificationData } from "../src/lib/notifications/input";
import { emptyNotifications } from "../src/lib/notifications/contracts";
const id="80000000-0000-4000-8000-000000000001",other="80000000-0000-4000-8000-000000000002",origin="https://platform.boss.invalid";
const command={action:"token.redeem",request_id:id,input:{merchant_id:id,location_id:other,capability:"c".repeat(64)}};
const terms={title:"Synthetic discount",description:"Synthetic terms",offer_type:"percentage_off",discount_bps:1250,qualification:"none",exclusions:"Synthetic exclusions",stacking:"none"};
const router:AppRouterInstance={bfcacheId:"merchant-test",back(){},forward(){},push(){},replace(){},refresh(){},prefetch(){}};
const render=(node:ReturnType<typeof createElement>)=>renderToStaticMarkup(createElement(AppRouterContext.Provider,{value:router},node));
const request=(body:unknown,source=origin)=>new Request(`${origin}/app/merchants/mutate`,{method:"POST",headers:{host:"platform.boss.invalid",origin:source,"content-type":"application/json"},body:JSON.stringify(body)});
test("redemption binds merchant/location proof and rejects client membership, actor and financial assertions",()=>{
 assert.ok(parseMerchantCommand(command));for(const k of ["actor_id","person_id","membership_id","source_id","role","paid","wallet_id","payment_id","amount_minor","household_id","organization_id","team_id"])assert.equal(parseMerchantCommand({...command,input:{...command.input,[k]:id}}),null);
 for(const capability of [null,"short",["c".repeat(64)],"c".repeat(65),"G".repeat(64)])assert.equal(parseMerchantCommand({...command,input:{...command.input,capability}}),null);
});
test("finite actions exclude merchant billing, retail tender, partner feeds and session impersonation",()=>{for(const action of ["merchant.subscribe","merchant.invoice","merchant.mark_paid","retail.purchase","wallet.redeem","partner.sync","user.impersonate"])assert.equal(parseMerchantCommand({...command,action}),null);});
test("typed merchant input rejects malformed IDs, active content, control characters and duplicate target locations",()=>{
 const c={action:"offer.create",request_id:id,input:{merchant_id:id,family_id:other,location_ids:[id],weekdays:[0,6],title:"Synthetic",offer_type:"percentage_off",qualification:"none",stacking:"none",starts_at:"2026-10-08T00:00:00Z",ends_at:"2026-11-08T00:00:00Z",location_policy:"selected"}};assert.ok(parseMerchantCommand(c));
 for(const changes of [{merchant_id:"forged"},{location_ids:[id,id]},{location_ids:[]},{weekdays:[7]},{weekdays:[0,0]},{title:"<script>"},{title:"bad\u0000text"},{discount_bps:1.5}])assert.equal(parseMerchantCommand({...c,input:{...c.input,...changes}}),null);
});
test("market and offer pagination use separate validated cursors and bounded literal prefix searches",()=>{
 assert.deepEqual(merchantQuery({market_id:id,directory_after:other,after:id,after_location_id:other,search:"Synthetic",category:""},"consumer"),{mode:"consumer",market_id:id,after:id,after_location_id:other,directory_after:other,search:"Synthetic"});
 for(const search of ["%","_","<","x\u0000", "x".repeat(81)])assert.equal(merchantQuery({search},"consumer"),null);
 for(const k of ["merchant_id","location_id","market_id","market_after","directory_after"])assert.equal(merchantQuery({[k]:[id]},"portal"),null);
});
test("merchant projections fail closed on malformed economics, scope and private contact/session fields",()=>{
 assert.ok(validMerchantData({mode:"consumer",items:[],offers:[],categories:[{key:"custom_category",name:"New category"}]}));assert.ok(validMerchantTerms(terms));
 for(const t of [{...terms,discount_bps:10001},{...terms,offer_type:"fixed_amount_off"},{...terms,qualification:"minimum_amount"},{...terms,email:"PRIVATE"}])assert.equal(validMerchantTerms(t),false);
 for(const field of ["password","session","auth_token","credential","email","household_id","sports_records","wallet_balance"])assert.equal(validMerchantData({items:[{id,name:"Synthetic",[field]:"PRIVATE"}]}),false);
 assert.equal(validMerchantData({offers:[{family_id:id,terms}]}),false);assert.equal(validMerchantData({items:Array(51).fill({id,name:"Synthetic"})}),false);assert.equal(validMerchantData({can_review:"true"}),false);
});
test("mutation receipts allow safe terms and immutable receipts while excluding secret or actor expansion",()=>{assert.ok(validMerchantReceipt({action:"token.verify",replayed:false,valid:true,title:terms.title,terms,remaining_uses:2},"token.verify"));for(const extra of [{capability:"PRIVATE"},{person_id:id},{email:"PRIVATE"},{debug:"PRIVATE"}])assert.equal(validMerchantReceipt({action:"token.redeem",replayed:false,...extra},"token.redeem"),false);});
test("cross-origin merchant mutation and oversized JSON are denied before RPC",async()=>{
 const client={rpc:()=>{throw new Error("Must not call");}} as unknown as MerchantClient;
 assert.equal((await performMerchantMutation(request(command,"https://evil.invalid"),client,origin)).status,403);
 assert.equal((await performMerchantMutation(request({...command,input:{...command.input,padding:"x".repeat(33000)}}),client,origin)).status,422);
});
test("merchant writes require a currently verified account and report safe errors",async()=>{
 const client={auth:{getUser:async()=>({data:{user:null},error:null})},rpc:()=>{throw new Error("Must not call");}} as unknown as MerchantClient;
 assert.equal((await performMerchantMutation(request(command),client,origin)).status,401);
 for(const code of ["PT403","PT404","PT409","23514","23505","PRIVATE_DATABASE_DETAIL"])assert.doesNotMatch(JSON.stringify(merchantFailure(code)),/23514|23505|PRIVATE_DATABASE_DETAIL/);
});
test("listing-only public directory exposes no member economics, roles or redemption form",()=>{
 const html=render(createElement(MerchantDirectory,{data:{items:[{id,name:"Synthetic listing",status:"active",description:"Listing only",category:"custom_category",locations:[]}],categories:[{key:"custom_category",name:"Configured category"}]}}));
 assert.match(html,/Synthetic listing|Listing only|Configured category|Initial merchant|initial merchant/i);assert.doesNotMatch(html,/Synthetic discount|12.5%|Redeem offer|One-time member redemption code|Assign operational access/);
});
test("location-scoped workspace links retain the exact location and show no company grants",()=>{
 const html=render(createElement(MerchantPortal,{data:{merchants:[{id,name:"Synthetic",status:"active",preferred_location_id:other}],categories:[]}}));assert.ok(html.includes(`merchant_id=${id}&amp;location_id=${other}`));
 const restricted=render(createElement(MerchantPortal,{data:{restricted:true,merchant:{id,name:"PRIVATE",status:"active"},can_access:true}}));assert.doesNotMatch(restricted,/PRIVATE|Assign operational access|ownership/);
});
test("shared corporate offers hide global editing from local editors",()=>{
 const data:MerchantData={merchant:{id,name:"Synthetic",status:"active",claim_state:"reviewed"},can_offers:true,offers:[{id:other,family_id:id,terms,weekly_special:false,weekdays:[0,1],starts_at:"2026-10-08T00:00:00Z",ends_at:"2026-12-01T00:00:00Z",usage_limit:2,reset_period:"lifetime",can_global_edit:false}]};
 const html=render(createElement(MerchantPortal,{data,merchantId:id,locationId:other}));assert.doesNotMatch(html,/Pause revision|Archive revision|Submit for review/);
});
test("clerk confirmation starts with code verification and hides redeem until verified",()=>{
 const html=render(createElement(RedemptionConsole,{merchantId:id,locationId:other,busy:false,act:async()=>null}));assert.match(html,/Verify current eligibility|type="password"|autoComplete="off"/i);assert.doesNotMatch(html,/>Confirm redemption once</);
});
test("percentage and fixed terms use basis points and currency minor digits",()=>{
 assert.match(renderToStaticMarkup(createElement(TermsSummary,{terms})),/12.5% off/);
 const fixed={...terms,offer_type:"fixed_amount_off",discount_bps:undefined,currency:"JPY",amount_minor:500};const html=renderToStaticMarkup(createElement(TermsSummary,{terms:fixed}));assert.match(html,/500/);assert.doesNotMatch(html,/5\.00/);
});
test("regional manager reassignment is per-opportunity while platform grants stay separate",()=>{
 const data:MerchantData={can_assign:false,leads:[{id,name:"Synthetic lead",market_id:other,state:"new",source:"Synthetic referral",rep_id:id,manager_id:other,merchant_id:null,version:1,can_reassign:true,activities:[]}]};
 const html=render(createElement(MerchantSales,{data}));assert.match(html,/Reassign opportunity/);assert.doesNotMatch(html,/Platform sales assignments|Create exact sales assignment/);
});
test("merchant notifications accept only canonical merchant destinations and preserve organization boundaries",()=>{
 assert.equal(safeNotificationDestination(`/app/merchants?merchant_id=${id}`),`/app/merchants?merchant_id=${id}`);assert.equal(safeNotificationDestination("/app/merchant-sales"),"/app/merchant-sales");
 for(const v of [`/app/merchants?merchant_id=${id}&person_id=${other}`,"https://evil.invalid/app/merchants","/app/merchant-sales?role=admin"])assert.equal(safeNotificationDestination(v),null);
 const n={id,organization_id:null,team_id:null,category:"communications",event_type:"merchant.approved",title:"Merchant review updated",body:"Review in Boss.",destination:`/app/merchants?merchant_id=${other}`,created_at:"2026-10-08T00:00:00Z",read_at:null};
 assert.equal(projectNotificationData({...emptyNotifications,notifications:[n]})?.notifications.length,1);
 assert.equal(projectNotificationData({...emptyNotifications,notifications:[{...n,event_type:"attendance.requested"}]})?.notifications.length,0);
 assert.equal(projectNotificationData({...emptyNotifications,notifications:[{...n,team_id:id}]})?.notifications.length,0);
});

test("merchant paging preserves finite filters and omits secrets and empty optional context",()=>{
 const query=merchantQuery({market_id:id,location_id:"",search:"Synthetic",category:"restaurants",favorites:"true"},"consumer"); assert.ok(query);
 const link=merchantPageLink({...query,capability:"untrusted-proof",session:"private"},{after:other,after_location_id:id});
 const params=new URLSearchParams(link.slice(1)); assert.equal(params.get("market_id"),id); assert.equal(params.get("search"),"Synthetic"); assert.equal(params.get("favorites"),"true"); assert.equal(params.get("after"),other); assert.equal(params.has("capability"),false); assert.equal(params.has("session"),false); assert.equal(params.has("location_id"),false);
});
