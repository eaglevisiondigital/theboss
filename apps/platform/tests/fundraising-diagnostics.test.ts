import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { emitFundraisingDiagnostic, fundraisingDiagnosticRecord, fundraisingDiagnosticRoute, fundraisingOperation, fundraisingCommandOperation, parseFundraisingDiagnostic, FUNDRAISING_DIAGNOSTIC_PREFIX, FUNDRAISING_CORRELATION_HEADER, FUNDRAISING_PARENT_HEADER, type FundraisingTrace } from "../src/lib/fundraising/diagnostics";
import { clearFundraisingClientTrace, fundraisingClientDiagnostic, fundraisingClientRendered, fundraisingFetch } from "../src/lib/fundraising/diagnostics-client";
import { performCartMutation, type MoneyBoardClient } from "../src/lib/money-board/mutation";
import { performAllocationMutation, type AllocationClient } from "../src/lib/fundraising-allocation/mutation";
import { onRequestError } from "../src/instrumentation";
const a = "10000000-0000-4000-8000-000000000001", b = "10000000-0000-4000-8000-000000000002", c = "10000000-0000-4000-8000-000000000003";
const trace: FundraisingTrace = { correlationId: a, route: "/fundraise/[path]/cart" };
const seed = { ...trace, phase: "server-route", stage: "http_response", observedAt: "src/lib/money-board/mutation.ts", status: 200 } as const;
const line = () => FUNDRAISING_DIAGNOSTIC_PREFIX + JSON.stringify(fundraisingDiagnosticRecord(seed));
async function capture(work: () => unknown) {
 const logs: string[] = [], old = console.info;
 console.info = value => { if (typeof value === "string" && value.startsWith(FUNDRAISING_DIAGNOSTIC_PREFIX)) logs.push(value); };
 try { await work(); } finally { console.info = old; }
 return logs.map(value => { const record = parseFundraisingDiagnostic(value); assert(record); return record; });
}
async function browser(work: () => unknown) {
 const old = Object.getOwnPropertyDescriptor(globalThis, "window");
 Object.defineProperty(globalThis, "window", { configurable: true, value: { location: { pathname: `/fundraise/${"a".repeat(48)}` } } });clearFundraisingClientTrace();
 try { await work(); } finally { clearFundraisingClientTrace();if (old) Object.defineProperty(globalThis, "window", old);else Reflect.deleteProperty(globalThis, "window"); }
}
test("diagnostic routes normalize private paths and ignore unrelated modules", () => {
 assert.equal(fundraisingDiagnosticRoute(`/fundraise/${"a".repeat(48)}/cart?capability=PRIVATE`), "/fundraise/[path]/cart");
 for (const route of ["/app/payments", "/app/partners", "/fundraise/../cart", "/fundraise/a/cart", "/api/diagnostics"]) assert.equal(fundraisingDiagnosticRoute(route), null);
});
test("finite record ignores payloads and rejects invalid correlations", () => {
 const record = fundraisingDiagnosticRecord({ ...seed, donor_email: "PRIVATE", session_capability: "PRIVATE", request_id: c } as typeof seed);
 assert(record);assert.doesNotMatch(JSON.stringify(record), /PRIVATE|request_id|donor|capability/);
 assert.equal(fundraisingDiagnosticRecord({ ...seed, correlationId: "PRIVATE" }), null);
 assert.equal(fundraisingOperation({ toString() { throw Error("PRIVATE"); } }, true), "fundraising.command");
});
test("exceptions retain only category digest and approved source location", () => {
 const record = fundraisingDiagnosticRecord({ ...seed, error: { name: "TypeError", message: "PRIVATE", digest: "12345", stack: "PRIVATE\n at fail (/src/lib/money-board/mutation.ts:22:9)" } });
 assert.equal(record?.exception_category, "TypeError");assert.deepEqual(record?.source, { file: "src/lib/money-board/mutation.ts", line: 22, column: 9 });assert.doesNotMatch(JSON.stringify(record), /PRIVATE/);
 const hostile = Object.defineProperty({}, "stack", { get() { throw Error("PRIVATE"); } });assert.equal(fundraisingDiagnosticRecord({ ...seed, error: hostile })?.source, null);
});
test("diagnostic sinks cannot change execution", () => { assert.doesNotThrow(() => emitFundraisingDiagnostic(seed, () => { throw Error("PRIVATE"); })); });
test("cleanup and policy diagnostics use bounded labels without retaining command fields", () => {
 for (const action of ["release", "board.archive", "fundraiser.end", "delegation.revoke", "destination.archive"]) assert.equal(fundraisingCommandOperation(action), "cleanup");
 assert.equal(fundraisingCommandOperation("campaign.status", "archived"), "cleanup");assert.equal(fundraisingCommandOperation("campaign.status", "active"), "fundraising.command");assert.equal(fundraisingCommandOperation("platform_policy.create"), "policy.authorize");assert.equal(fundraisingCommandOperation("PRIVATE", "PRIVATE"), "fundraising.command");
});
test("retrieval rejects payload smuggling and malformed finite fields", () => {
 assert(parseFundraisingDiagnostic(line()));
 for (const change of [{ donor: "PRIVATE" }, { timestamp: "PRIVATE" }, { source: { file: "PRIVATE", line: 1, column: 2 } }, { operation: "PRIVATE" }, { commit: "PRIVATE" }, { digest: "PRIVATE" }, { http_status: "200" }, { exception_category: "PRIVATE" }, { schema: "PRIVATE" }]) assert.equal(parseFundraisingDiagnostic(FUNDRAISING_DIAGNOSTIC_PREFIX + JSON.stringify({ ...JSON.parse(line().slice(FUNDRAISING_DIAGNOSTIC_PREFIX.length)), ...change })), null);
 assert.equal(parseFundraisingDiagnostic("raw PRIVATE"), null);
});
test("real Next server hook diagnoses fundraising without exporting request material", async () => {
 const rows = await capture(() => onRequestError({ name: "TypeError", message: "PRIVATE", stack: "PRIVATE\n at fail (/src/lib/fundraising/data.ts:9:4)" }, { path: "/app/fundraising?person=PRIVATE", method: "GET", headers: { [FUNDRAISING_CORRELATION_HEADER]: a, [FUNDRAISING_PARENT_HEADER]: b, cookie: "PRIVATE" } }, { routerKind: "App Router", routePath: "PRIVATE", routeType: "render", renderSource: "server-rendering", revalidateReason: undefined }));
 assert.equal(rows.length, 1);assert.equal(rows[0].correlation_id, a);assert.equal(rows[0].parent_correlation_id, b);assert.equal(rows[0].phase, "server-render");assert.doesNotMatch(JSON.stringify(rows), /PRIVATE/);
});
test("local operator retrieves matching correlations into owner-only export", () => {
 const dir = mkdtempSync(join(tmpdir(), "boss-diagnostic-test."));
 try { const input = join(dir, "safe.log"), output = join(dir, "private.json");writeFileSync(input, "Unrelated PRIVATE\n" + line() + "\n", { mode: 0o600 });
  const result = spawnSync(process.execPath, ["--import", "tsx", "scripts/retrieve-fundraising-diagnostics.ts", "--input", input, "--correlation", a, "--output", output], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);const exported = JSON.parse(readFileSync(output, "utf8"));assert.equal(exported.records.length, 1);assert.doesNotMatch(JSON.stringify(exported), /PRIVATE/);
  const repeat = spawnSync(process.execPath, ["--import", "tsx", "scripts/retrieve-fundraising-diagnostics.ts", "--input", input, "--correlation", a, "--output", join(dir, "historical.json"), "--since", "2026-01-01T00:00:00Z"], { encoding: "utf8" });assert.equal(repeat.status, 0);
 } finally { rmSync(dir, { recursive: true }); }
});
test("retrieval refuses readable-by-others input and never overwrites evidence", () => {
 const dir = mkdtempSync(join(tmpdir(), "boss-diagnostic-test."));
 try { const input = join(dir, "unsafe.log"), output = join(dir, "kept.json");writeFileSync(input, line(), { mode: 0o644 });writeFileSync(output, "KEEP", { mode: 0o600 });
  const result = spawnSync(process.execPath, ["--import", "tsx", "scripts/retrieve-fundraising-diagnostics.ts", "--input", input, "--correlation", a, "--output", output], { encoding: "utf8" });assert.notEqual(result.status, 0);assert.equal(readFileSync(output, "utf8"), "KEEP");
 } finally { rmSync(dir, { recursive: true }); }
});
const origin = "https://boss.example", path = "a".repeat(48), command = { action: "open", request_id: c, input: {} };
const request = (value: unknown = command, providedOrigin = origin) => new Request(`${origin}/fundraise/${path}/cart`, { method: "POST", headers: { host: "boss.example", origin: providedOrigin, "content-type": "application/json" }, body: JSON.stringify(value) });
const cart = { version: 1, state: "selection", currency: "USD", items: [], subtotal_minor: 0, max_tiles: 50, max_total_minor: 1_000_000, session_expires_at: "2099-01-01T00:30:00Z", reservation_expires_at: null, payment_available: false };
test("cart confirmation diagnostics exclude the generated secure capability", async () => {
 let secret = "";
 const rows = await capture(async () => { const result = await performCartMutation(request(), { rpc: async (_name, args) => { secret = String(args.session_capability); return { data: { ...cart, session_capability: secret, donor_email: "PRIVATE" }, error: null }; } }, origin, path, undefined, trace);assert.equal(result.status, 200);assert.equal(result.session?.value, secret); });
 assert(rows.some(r => r.operation === "cart.open"));assert(rows.some(r => r.classification === "confirmed-success"));assert(!JSON.stringify(rows).includes(secret));assert.doesNotMatch(JSON.stringify(rows), /PRIVATE|request_id/);
});
test("protected denial remains before RPC with safe correlation", async () => {
 let calls = 0;const client: MoneyBoardClient = { rpc: async () => { calls++;throw Error("PRIVATE"); } };
 const rows = await capture(async () => assert.equal((await performCartMutation(request(command, "https://other.example"), client, origin, path, undefined, trace)).status, 403));assert.equal(calls, 0);assert(rows.some(r => r.classification === "scope-denied" && r.http_status === 403));
});
test("invalid receipt never emits confirmed success", async () => {
 const rows = await capture(async () => assert.equal((await performCartMutation(request(), { rpc: async () => ({ data: { ...cart, payment_available: true }, error: null }) }, origin, path, undefined, trace)).status, 503));assert(!rows.some(r => r.classification === "confirmed-success"));
});
test("allocation policy origin denial retains platform authorization boundaries", async () => {
 const rows = await capture(async () => assert.equal((await performAllocationMutation(request(command, "https://other.example"), { auth: {}, rpc() { throw Error("RPC forbidden"); } } as unknown as AllocationClient, origin, { ...trace, route: "/app/fundraising/allocation/mutate" })).status, 403));assert(rows.some(r => r.operation === "policy.authorize" && r.classification === "scope-denied"));
});
test("caught RPC exception exports a category without its message", async () => {
 const rows = await capture(async () => assert.equal((await performCartMutation(request(), { rpc: async () => { throw new TypeError("PRIVATE"); } }, origin, path, undefined, trace)).status, 503));assert(rows.some(r => r.exception_category === "TypeError"));assert.doesNotMatch(JSON.stringify(rows), /PRIVATE/);
});
test("native client/server correlations preserve the exact original retry body", async () => {
 await browser(async () => { const original = globalThis.fetch, sent: string[] = [];globalThis.fetch = async (_url, init) => { sent.push(String(init?.body));assert(new Headers(init?.headers).get(FUNDRAISING_PARENT_HEADER));if (sent.length === 1) throw Error("PRIVATE");return new Response(JSON.stringify({ ok: true, cart }), { headers: { [FUNDRAISING_CORRELATION_HEADER]: b } }); };
  try { const rows = await capture(async () => { fundraisingClientRendered(a, "src/components/money-board/portal.tsx");await assert.rejects(fundraisingFetch("/fundraise/fixture/cart", { method: "POST", body: JSON.stringify(command) }, "cart.open"));const response = await fundraisingFetch("/fundraise/fixture/cart", { method: "POST", body: JSON.stringify(command) }, "cart.open");assert.equal(response.status, 200);fundraisingClientDiagnostic({ stage: "response_accepted", observedAt: "src/components/money-board/portal.tsx" });fundraisingClientRendered(c, "src/components/money-board/portal.tsx"); });assert.deepEqual(sent, [JSON.stringify(command), JSON.stringify(command)]);assert(rows.some(r => r.stage === "unknown_confirmation"));assert.equal(rows.at(-1)?.parent_correlation_id, b);assert.doesNotMatch(JSON.stringify(rows), /PRIVATE|request_id/);
  } finally { globalThis.fetch = original; }
 });
});
test("error boundary distinguishes confirmed refresh from denied response", async () => {
 await browser(async () => { const rows = await capture(() => { fundraisingClientDiagnostic({ stage: "error_boundary", observedAt: "src/app/error.tsx", error: Error("PRIVATE") });fundraisingClientDiagnostic({ stage: "retry_requested", observedAt: "src/app/error.tsx" });fundraisingClientDiagnostic({ stage: "response_accepted", observedAt: "src/components/fundraising/console.tsx" }, a);fundraisingClientDiagnostic({ stage: "error_boundary", observedAt: "src/app/error.tsx", error: Error("PRIVATE") }); });assert.equal(rows[0].correlation_id, rows[1].correlation_id);assert.notEqual(rows[0].classification, "refresh-failed");assert.equal(rows.at(-1)?.classification, "refresh-failed"); });
});
test("diagnostic setup failure still executes original fetch", async () => {
 const descriptor = Object.getOwnPropertyDescriptor(globalThis, "crypto"), original = globalThis.fetch;let calls = 0;
 Object.defineProperty(globalThis, "crypto", { configurable: true, value: { randomUUID() { throw Error("PRIVATE"); } } });globalThis.fetch = async () => { calls++;return new Response("original"); };
 try { assert.equal(await (await fundraisingFetch("/local", {}, "board.read")).text(), "original");assert.equal(calls, 1); } finally { if (descriptor) Object.defineProperty(globalThis, "crypto", descriptor);globalThis.fetch = original; }
});
