import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { performPaymentMutation, type PaymentClient } from "../src/lib/payments/mutation";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
import { fundraisingDiagnosticRoute, parseFundraisingDiagnostic, FUNDRAISING_DIAGNOSTIC_PREFIX, FUNDRAISING_CORRELATION_HEADER, type FundraisingTrace } from "../src/lib/fundraising/diagnostics";
import { fundraisingRequestTrace, fundraisingResponse } from "../src/lib/fundraising/diagnostics-server";
import { fundraisingFetch, clearFundraisingClientTrace } from "../src/lib/fundraising/diagnostics-client";

const id = "81000000-0000-4000-8000-000000000001", correlation = "81000000-0000-4000-8000-000000000002";
const origin = "https://payments.boss.invalid", trace = { correlationId: correlation, route: "/app/payments/mutate" } as FundraisingTrace;
const policy = { action: "policy.create", request_id: id, input: { organization_id: id, purpose: "fundraising", currency: "USD", organization_basis_points: 7000, platform_basis_points: 3000, product_cost_basis_points: 0, processor_fee_owner: "organization", availability_seconds: 0, platform_fee_minor: 100 } };
const request = (body: unknown = policy, suppliedOrigin = origin) => new Request(`${origin}/app/payments/mutate`, { method: "POST", headers: { host: "payments.boss.invalid", origin: suppliedOrigin, "content-type": "application/json" }, body: JSON.stringify(body) });
function client(code?: string, value: unknown = { id, action: "policy.create", state: "saved" }) {
 let calls = 0;
 const guarded = { auth: { async getClaims() { return { data: { claims: { sub: id, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 60 } }, error: null }; }, async getUser() { return { data: { user: { id } }, error: null }; } }, async rpc() { calls++;return { data: value, error: code ? { code } : null }; } } as PaymentClient;
 return { guarded, calls: () => calls };
}
async function capture(work: () => Promise<unknown>) {
 const old = console.info, lines: string[] = [];
 console.info = value => { if (typeof value === "string" && value.startsWith(FUNDRAISING_DIAGNOSTIC_PREFIX)) lines.push(value); };
 try { await work(); } finally { console.info = old; }
 return lines.map(line => { const record = parseFundraisingDiagnostic(line);assert(record);return record; });
}

test("Payments diagnostic scope includes existing routes and excludes any diagnostic endpoint", () => {
 assert.equal(fundraisingDiagnosticRoute("/app/payments/mutate?secret=PRIVATE"), "/app/payments/mutate");
 assert.equal(fundraisingDiagnosticRoute("/app/payments"), "/app/payments");
 assert.equal(fundraisingDiagnosticRoute("/app/payments/diagnostics"), null);
});
test("authoritative policy rejection is a distinct correlated 403, never a success", async () => {
 const c = client("PT403");
 const records = await capture(async () => { const result = await performPaymentMutation(request(), c.guarded, origin, trace);assert.equal(result.status, 403);assert("error" in result.body);assert.equal(result.body.error, "This payment scope is restricted."); });
 assert.equal(c.calls(), 1);
 assert(records.some(r => r.stage === "mutation_started" && r.operation === "payments.policy.authorize"));
 assert(records.some(r => r.stage === "rpc_failed" && r.operation === "payments.policy.authorize" && r.classification === "scope-denied" && r.http_status === 403));
 assert(records.some(r => r.stage === "http_response" && r.operation === "payments.policy.authorize" && r.http_status === 403));
 assert(records.every(r => r.correlation_id === correlation && r.classification !== "confirmed-success"));
 assert.doesNotMatch(JSON.stringify(records), /organization_basis_points|platform_basis_points|platform_fee_minor|USD|7000|3000/);
});
test("permitted authoritative policy result remains a 200 with safe projection", async () => {
 const c = client(undefined, { id, action: "policy.create", state: "saved", private_payload: "PRIVATE" });
 const records = await capture(async () => { const result = await performPaymentMutation(request(), c.guarded, origin, trace);assert.deepEqual(result, { status: 200, body: { ok: true, id, action: "policy.create", state: "saved" } }); });
 assert.equal(c.calls(), 1);assert(records.some(r => r.operation === "payments.policy.authorize" && r.stage === "rpc_completed" && r.http_status === 200));assert.doesNotMatch(JSON.stringify(records), /PRIVATE/);
});
test("cross-origin rejection is not mislabeled an authoritative policy decision", async () => {
 const c = client();const records = await capture(async () => { assert.equal((await performPaymentMutation(request(policy, "https://unrelated.invalid"), c.guarded, origin, trace)).status, 403); });
 assert.equal(c.calls(), 0);assert(records.some(r => r.operation === "payments.command" && r.http_status === 403));assert(!records.some(r => r.stage === "rpc_failed" || r.stage === "rpc_completed"));
});
test("invalid command is bounded parsing rejection before RPC", async () => {
 const c = client();const records = await capture(async () => { assert.equal((await performPaymentMutation(request({ ...policy, input: { ...policy.input, api_key: "PRIVATE" } }), c.guarded, origin, trace)).status, 422); });
 assert.equal(c.calls(), 0);assert(records.some(r => r.operation === "payments.command" && r.http_status === 422 && r.classification === "confirmed-rejection"));assert.doesNotMatch(JSON.stringify(records), /PRIVATE|api_key/);
});
test("unverified caller cannot reach policy RPC", async () => {
 const c = client();c.guarded.auth.getUser = async () => ({ data: { user: null }, error: Error("PRIVATE") });
 const records = await capture(async () => { assert.equal((await performPaymentMutation(request(), c.guarded, origin, trace)).status, 401); });
 assert.equal(c.calls(), 0);assert(records.some(r => r.http_status === 401 && r.classification === "scope-denied"));assert(!records.some(r => r.stage === "rpc_completed"));
});
test("other Payments command projection and number of RPC calls are unchanged", async () => {
 const body = { action: "account.disable", request_id: id, input: { organization_id: id, account_id: id } }, c = client(undefined, { id, action: "account.disable", state: "disabled", secret_handle: "PRIVATE" });
 const original = await performPaymentMutation(request(body), c.guarded, origin);
 const records = await capture(async () => { assert.deepEqual(await performPaymentMutation(request(body), c.guarded, origin, trace), original); });
 assert.equal(c.calls(), 2);assert(records.some(r => r.operation === "payments.command" && r.http_status === 200));assert.doesNotMatch(JSON.stringify(records), /PRIVATE|secret_handle/);
});
test("invalid upstream contract never emits a successful policy result", async () => {
 const c = client(undefined, null);const records = await capture(async () => { assert.equal((await performPaymentMutation(request(), c.guarded, origin, trace)).status, 503); });
 assert(records.length);assert(!records.some(r => r.classification === "confirmed-success"));
});
test("exceptions and sink failures do not expose details or alter permission denial", async () => {
 const c = client();c.guarded.rpc = async () => { throw Error("PRIVATE provider credential donor information"); };
 const records = await capture(async () => { assert.equal((await performPaymentMutation(request(), c.guarded, origin, trace)).status, 503); });
 assert(records.some(r => r.stage === "server_exception"));assert.doesNotMatch(JSON.stringify(records), /PRIVATE|provider credential|donor information/);
 const old = console.info;console.info = () => { throw Error("PRIVATE"); };
 try { assert.equal((await performPaymentMutation(request(), client("PT403").guarded, origin, trace)).status, 403); } finally { console.info = old; }
});
test("server diagnostic response correlation preserves existing status/cache contract", () => {
 const t = fundraisingRequestTrace(new Request(`${origin}/app/payments/mutate`, { headers: { [FUNDRAISING_CORRELATION_HEADER]: correlation } }), trace.route);
 const response = fundraisingResponse(t, new Response(JSON.stringify({ ok: false }), { status: 403, headers: { "cache-control": "private, no-store" } }));
 assert.equal(response.status, 403);assert.equal(response.headers.get(FUNDRAISING_CORRELATION_HEADER), correlation);assert.equal(response.headers.get("cache-control"), "private, no-store");
});
test("normal policy client fetch connects response correlation without reading session material", async () => {
 const oldWindow = Object.getOwnPropertyDescriptor(globalThis, "window"), oldFetch = globalThis.fetch;
 Object.defineProperty(globalThis, "window", { configurable: true, value: { location: { pathname: "/app/payments" } } });clearFundraisingClientTrace();
 let sent = "";globalThis.fetch = async (_url, init) => { sent = String(init?.body);return new Response("{}", { status: 403, headers: { [FUNDRAISING_CORRELATION_HEADER]: correlation } }); };
 try { const records = await capture(async () => { assert.equal((await fundraisingFetch("/app/payments/mutate", { method: "POST", body: JSON.stringify(policy) }, "payments.policy.authorize")).status, 403); });assert.equal(sent, JSON.stringify(policy));assert(records.some(r => r.correlation_id === correlation && r.http_status === 403 && r.stage === "http_response"));assert.doesNotMatch(JSON.stringify(records), /platform_fee_minor|organization_basis_points/); }
 finally { globalThis.fetch = oldFetch;clearFundraisingClientTrace();if (oldWindow) Object.defineProperty(globalThis, "window", oldWindow);else Reflect.deleteProperty(globalThis, "window"); }
});
test("operator retrieval admits finite payment denial schema and denies unprotected exports", async () => {
 const records = await capture(async () => { await performPaymentMutation(request(), client("PT403").guarded, origin, trace); });assert(records.length);
 const dir = mkdtempSync(join(tmpdir(), "boss-payment-diagnostic."));
 try { const input = join(dir, "protected.log"), output = join(dir, "safe.json");const lines = records.map(r => FUNDRAISING_DIAGNOSTIC_PREFIX + JSON.stringify(r)).join("\n") + "\n";writeFileSync(input, lines, { mode: 0o600 });
  const args = ["--import", "tsx", "scripts/retrieve-fundraising-diagnostics.ts", "--input", input, "--correlation", correlation, "--output"];
  const result = spawnSync(process.execPath, [...args, output], { encoding: "utf8" });assert.equal(result.status, 0, result.stderr);assert.equal(JSON.parse(readFileSync(output, "utf8")).records.length, records.length);
  const unsafe = join(dir, "public.log");writeFileSync(unsafe, lines, { mode: 0o644 });const denied = spawnSync(process.execPath, args.map(a => a === input ? unsafe : a).concat(join(dir, "denied.json")), { encoding: "utf8" });assert.notEqual(denied.status, 0);
 } finally { rmSync(dir, { recursive: true }); }
});
