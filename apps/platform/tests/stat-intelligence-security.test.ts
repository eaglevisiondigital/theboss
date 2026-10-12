import test from "node:test";
import assert from "node:assert/strict";
import { parseStatAction } from "../src/lib/stat-intelligence/action";
import { performStatMutation, type StatClient } from "../src/lib/stat-intelligence/mutation";
const id = "10000000-0000-0000-0000-000000000001", other = "10000000-0000-0000-0000-000000000002", origin = "https://platform.boss.invalid";
const action = { operation: "classify", game_id: other, classification: "official", reason: "Synthetic approved eligibility" };
function request(body: unknown = { request_id: id, action }, headers = {}) { return new Request(`${origin}/app/statistics/mutate`, { method: "POST", headers: { origin, host: "platform.boss.invalid", "content-type": "application/json", ...headers }, body: JSON.stringify(body) }); }
function mock() {
  const calls: unknown[] = [];
  const client: StatClient = { auth: { getClaims: async () => ({ data: { claims: { sub: id, iss: "https://ilykgwgmxtrrikreacrz.supabase.co/auth/v1", role: "authenticated", exp: Math.floor(Date.now()/1000)+60 } }, error: null }), getUser: async () => ({ data: { user: { id } }, error: null }) }, rpc: async (name, args) => { calls.push([name,args]); return { data: { id, version: 1, classification: "official", replayed: false, ignored: "PRIVATE_UNNEEDED" }, error: null }; } };
  return { client, calls };
}
test("statistical action parser admits finite native scope only", () => {
  assert.ok(parseStatAction(action)); for (const a of [{ ...action, actor: id }, { ...action, game_id: "forged" }, { ...action, classification: "whatever" }, { ...action, reason: " " }, { operation: "rebuild", query: { organization_id: id, team_id: other, season_id: id, sport_key: "all" } }]) assert.equal(parseStatAction(a), null);
});
test("statistical POST rejects cross-origin before authentication/RPC", async () => { const m=mock(); assert.equal((await performStatMutation(request(undefined, { origin: "https://attacker.invalid" }),m.client,origin)).status,403); assert.equal(m.calls.length,0); });
test("statistical POST rejects malformed/oversized and forged scope before RPC", async () => { const m=mock(); for(const req of [request({request_id:id,action:{...action,actor_id:id}}),request(undefined,{"content-type":"text/plain"}),request({request_id:id,action:{...action,reason:"x".repeat(6001)}})]) assert.equal((await performStatMutation(req,m.client,origin)).status,422); assert.equal(m.calls.length,0); });
test("statistical POST denies anonymous or changed authenticated identity", async () => { const m=mock(); m.client.auth.getUser=async()=>({data:{user:{id:other}},error:null}); assert.equal((await performStatMutation(request(),m.client,origin)).status,401); m.client.auth.getUser=async()=>({data:{user:{id,is_anonymous:true}},error:null}); assert.equal((await performStatMutation(request(),m.client,origin)).status,401); assert.equal(m.calls.length,0); });
test("classification retry preserves UUID and projects no private payload", async () => { const m=mock(); for(let i=0;i<2;i++){const result=await performStatMutation(request(),m.client,origin);assert.equal(result.status,200);assert.doesNotMatch(JSON.stringify(result),/PRIVATE_UNNEEDED/);} assert.deepEqual(m.calls[0],m.calls[1]); });
test("classification receipt mismatch fails closed", async () => { const m=mock(); m.client.rpc=async()=>({data:{id:other,classification:"official",version:1,replayed:false},error:null}); assert.equal((await performStatMutation(request(),m.client,origin)).status,503); });
test("statistical authority conflict does not expose backend errors", async () => { const m=mock(); m.client.rpc=async()=>({data:null,error:{code:"PT403"}}); assert.equal((await performStatMutation(request(),m.client,origin)).status,403); });
test("rebuild projects bounded continuation without aggregate payload", async () => {
 const m=mock();m.client.rpc=async(name,args)=>{m.calls.push([name,args]);return{data:{contract:"intelligence-v1",is_current:false,refresh_pending:true,rebuild_cursor:other,rebuild_complete:false,summary:{private:"PRIVATE_UNNEEDED"}},error:null};};
 const result=await performStatMutation(request({request_id:id,action:{operation:"rebuild",query:{organization_id:id,team_id:other,season_id:id,sport_key:"basketball"}}}),m.client,origin);
 assert.equal(result.status,200);assert.doesNotMatch(JSON.stringify(result),/PRIVATE_UNNEEDED/);assert.deepEqual(result.body,{ok:true,operation:"rebuild",complete:false,cursor:other});
});
