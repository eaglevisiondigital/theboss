import assert from "node:assert/strict";
import test from "node:test";
import { parseAdminInput, readAdminInput, projectMutationResults } from "../src/lib/admin/input";
import { performAdminMutation, type AdminMutationClient } from "../src/lib/admin/mutation";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";

const id = "00000000-0000-4000-8000-000000000001";
const other = "00000000-0000-4000-8000-000000000002";
const origin = "https://platform.boss.invalid";
const body = { request_id: id, commands: [{ operation: "organization.create", input: { name: "Controlled test", slug: "controlled-test" } }] };
const request = (value: unknown = body, headers: Record<string, string> = {}) => new Request(`${origin}/app/admin/mutate`, {
  method: "POST", headers: { "content-type": "application/json", host: "platform.boss.invalid", origin, "sec-fetch-site": "same-origin", ...headers }, body: JSON.stringify(value),
});
function mock() {
  let calls = 0;
  const client: AdminMutationClient = {
    auth: {
      getClaims: async () => ({ data: { claims: { sub: id, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now()/1000)+120 } }, error: null }),
      getUser: async () => ({ data: { user: { id, is_anonymous: false } }, error: null }),
    },
    rpc: async () => { calls++; return { data: { results: [{ resource_type: "organization", resource_id: other, ignored: "PRIVATE_DETAIL" }] }, error: null }; },
  };
  return { client, calls: () => calls };
}

test("mutations require same-origin POST before authentication or RPC", async () => {
  const m = mock();
  const cases: Record<string,string>[] = [{ origin: "https://attacker.invalid" }, { "sec-fetch-site": "cross-site" }, { host: "attacker.invalid" }, { origin: "" }];
  for (const headers of cases) {
    assert.equal((await performAdminMutation(request(body, headers),m.client,origin)).status,403);
  }
  assert.equal(m.calls(),0);
});
test("bounded streaming bodies reject untrusted shapes and privileged fields", async () => {
  const m = mock();
  for (const value of [null, { ...body, actor: other }, { ...body, commands: [{ operation: "organization.create", input: { ...body.commands[0].input, is_admin: true } }] },
    { ...body, commands: [{ operation: "audit.delete", input: { id } }] }, { ...body, commands: new Array(13).fill(body.commands[0]) }]) {
    assert.equal((await performAdminMutation(request(value),m.client,origin)).status,422);
  }
  assert.equal(await readAdminInput(request(body, { "content-length": "65537" })),null);
  assert.equal(await readAdminInput(request({ ...body, padding: "a".repeat(65_536) })),null);
  assert.equal(await readAdminInput(request(body, { "content-type": "text/plain" })),null);
  assert.equal(m.calls(),0);
});
test("atomic references are backward only and UUID fields are strictly shaped", () => {
  const commands = [{ operation: "person.create", input: { display_name: "Test person" }, ref: "child" },
    { operation: "participant.create", input: { person_id: { $ref: "child" } } }];
  assert.ok(parseAdminInput({ request_id: id, commands }));
  assert.equal(parseAdminInput({ request_id: id, commands: commands.toReversed() }),null);
  assert.equal(parseAdminInput({ ...body, commands: [{ operation: "person.update", input: { id: "not-a-uuid" } }] }),null);
  assert.equal(parseAdminInput({ ...body, commands: [{ operation: "person.create", input: { display_name: { $ref: "child" } } }] }),null);
});
test("current Auth user and verified identity must agree", async () => {
  const m = mock();
  m.client.auth.getUser = async () => ({ data: { user: { id: other } }, error: null });
  assert.equal((await performAdminMutation(request(),m.client,origin)).status,401);
  m.client.auth.getUser = async () => ({ data: { user: { id, is_anonymous: true } }, error: null });
  assert.equal((await performAdminMutation(request(),m.client,origin)).status,401);
  m.client.auth.getClaims = async () => ({ data: null, error: null });
  assert.equal((await performAdminMutation(request(),m.client,origin)).status,401);
  assert.equal(m.calls(),0);
});
test("successful response projects resource identifiers only", async () => {
  const m=mock();
  const result=await performAdminMutation(request(),m.client,origin);
  assert.deepEqual(result,{status:200,body:{ok:true,results:[{resource_type:"organization",resource_id:other}]}});
  assert.equal(m.calls(),1);
  assert.equal(projectMutationResults({results:[{resource_type:"auth.sessions",resource_id:id}]}),null);
});
test("database and upstream errors expose no SQL or stack details", async () => {
  const m=mock();
  const cases: [string,number][] = [["PT401",401],["PT403",403],["PT409",409],["PT422",422],["23503",503]];
  for (const [code,status] of cases) {
    m.client.rpc=async () => ({data:null,error:{code,message:"PRIVATE_SQL_DETAIL",details:"PRIVATE_STACK"}});
    const result=await performAdminMutation(request(),m.client,origin);
    assert.equal(result.status,status);
    assert.doesNotMatch(JSON.stringify(result),/PRIVATE_/);
  }
  m.client.rpc=async () => { throw new Error("PRIVATE_STACK"); };
  assert.doesNotMatch(JSON.stringify(await performAdminMutation(request(),m.client,origin)),/PRIVATE_/);
});
