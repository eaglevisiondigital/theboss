import test from "node:test";
import assert from "node:assert/strict";
import { clearPartnerClientTrace, partnerClientDiagnostic, partnerClientMutationStarted, partnerClientRendered, partnerClientResponse } from "../src/lib/partners/diagnostics-client";
import { clearMerchantClientTrace } from "../src/lib/merchants/diagnostics-client";
import { PARTNER_DIAGNOSTIC_PREFIX, partnerDiagnosticRecord } from "../src/lib/partners/diagnostics";

const read = "90000000-0000-4000-8000-000000000001";
const response = "90000000-0000-4000-8000-000000000002";
const nextRead = "90000000-0000-4000-8000-000000000003";
const listeners = new Map<string, (event: { error?: unknown; reason?: unknown }) => void>();
let loaded = false;
async function browser(run: (emit: (kind: "error" | "unhandledrejection", error: unknown) => void, rows: Record<string, unknown>[]) => void, pathname = "/app/partners") {
 const original = Object.getOwnPropertyDescriptor(globalThis, "window"), info = console.info;
 const rows: Record<string, unknown>[] = [];
 Object.defineProperty(globalThis, "window", { configurable: true, value: { location: { pathname }, addEventListener: (type: string, handler: typeof listeners extends Map<string, infer V> ? V : never) => listeners.set(type, handler) } });
 console.info = line => { if (typeof line === "string" && line.startsWith(PARTNER_DIAGNOSTIC_PREFIX)) rows.push(JSON.parse(line.slice(PARTNER_DIAGNOSTIC_PREFIX.length))); };
 clearPartnerClientTrace(); clearMerchantClientTrace();
 try {
  if (!loaded) { await import("../src/instrumentation-client"); loaded = true; }
  run((kind, error) => listeners.get(kind)!({ error, reason: error }), rows);
 } finally {
  clearPartnerClientTrace(); clearMerchantClientTrace(); console.info = info;
  if (original) Object.defineProperty(globalThis, "window", original); else Reflect.deleteProperty(globalThis, "window");
 }
}
test("actual browser listeners distinguish pre-render ErrorEvent and rejection without inferring origin", async () => {
 await browser((emit, rows) => {
  emit("error", new Error("SYNTHETIC_PRIVATE")); emit("unhandledrejection", new Error("SYNTHETIC_PRIVATE"));
  assert.equal(rows[0].classification, "window_error"); assert.equal(rows[1].classification, "unhandled_rejection");
  for (const r of rows) { assert.equal(r.trace_state, "uninitialized"); assert.equal(r.source, null); assert.equal(r.exception_category, "Error"); }
  assert.notEqual(rows[0].correlation_id, rows[1].correlation_id);
  partnerClientRendered(read);
  assert.notEqual(rows[0].correlation_id, read); assert.equal(rows.at(-1)?.correlation_id, read);
 });
});
test("after first render a global error uses the registered read rather than a new request identity", async () => {
 await browser((emit, rows) => { partnerClientRendered(read); emit("error", new Error("SYNTHETIC_PRIVATE")); assert.equal(rows.at(-1)?.trace_state, "read"); assert.equal(rows.at(-1)?.correlation_id, read); });
});
test("pending mutation retains read context; response/refresh uses response trace and boundary preserves confirmed success", async () => {
 await browser((emit, rows) => {
  partnerClientRendered(read); const clientMutation = partnerClientMutationStarted("provider.create", false);
  emit("unhandledrejection", new Error("SYNTHETIC_PRIVATE"));
  assert.equal(rows.at(-1)?.trace_state, "read"); assert.equal(rows.at(-1)?.correlation_id, read);
  assert.notEqual(clientMutation, read);
  partnerClientResponse(response, clientMutation, 200, "provider.create");
  partnerClientDiagnostic({stage:"response_accepted",observedAt:"src/lib/partners/action.ts",classification:"confirmed-success"});
  partnerClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/partners/workspace.tsx"});
  emit("error", new Error("SYNTHETIC_PRIVATE"));
  assert.equal(rows.at(-1)?.trace_state, "mutation_response"); assert.equal(rows.at(-1)?.correlation_id, response);
  partnerClientDiagnostic({stage:"error_boundary",observedAt:"src/app/error.tsx",error:new Error("SYNTHETIC_PRIVATE")});
  assert.equal(rows.at(-1)?.classification,"refresh-failed");
  partnerClientRendered(nextRead); emit("error", new Error("SYNTHETIC_PRIVATE"));
  assert.equal(rows.at(-1)?.trace_state,"read"); assert.equal(rows.at(-1)?.correlation_id,nextRead);
 });
});
test("initial boundary and retry expose registered boundary context without assuming server or client cause", async () => {
 await browser((_emit, rows) => {
  partnerClientDiagnostic({stage:"error_boundary",observedAt:"src/app/error.tsx",error:new Error("SYNTHETIC_PRIVATE")});
  partnerClientDiagnostic({stage:"retry_requested",observedAt:"src/app/error.tsx"});
  assert.equal(rows[0].trace_state,"uninitialized"); assert.equal(rows[1].trace_state,"boundary");
  assert.equal(rows[0].correlation_id,rows[1].correlation_id); assert.equal(rows[0].classification,"event");
 });
});
test("generic framework and application errors stay window_error, not silently recoverable", async () => {
 await browser((emit, rows) => {
  for(const frame of ["Error: SYNTHETIC_PRIVATE\n at bundled (/unlisted.js:1:2)","Error: SYNTHETIC_PRIVATE\n at app (/unlisted.js:1:2)"]){const e=new Error("SYNTHETIC_PRIVATE");e.stack=frame;emit("error",e);}
  for(const r of rows){assert.equal(r.classification,"window_error");assert.equal(r.source,null);}
  assert.doesNotMatch(JSON.stringify(rows),/SYNTHETIC_PRIVATE|unlisted|recoverable_framework_event/);
 });
});
test("known browser event kinds do not retain event objects, private URLs, bodies or raw exception text", async () => {
 await browser((emit, rows) => {
  const e={name:"TypeError",message:"SYNTHETIC_PRIVATE",stack:"TypeError: SYNTHETIC_PRIVATE\n at /private/url?secret=SYNTHETIC_PRIVATE:1:2",digest:"SYNTHETIC_PRIVATE",cookie:"SYNTHETIC_PRIVATE",body:"SYNTHETIC_PRIVATE"};
  emit("error",e);emit("unhandledrejection",new Proxy({},{get(){throw Error("SYNTHETIC_PRIVATE");}}));
  assert.doesNotMatch(JSON.stringify(rows),/SYNTHETIC_PRIVATE|private\/url|cookie|body|message|stack/);
  assert.equal(rows[0].digest,null);assert.equal(rows[0].source,null);
 });
});
test("browser diagnostic sink failure does not recurse or prevent trace initialization", async () => {
 await browser((emit, rows) => {
  const capture=console.info;console.info=()=>{throw Error("SYNTHETIC_PRIVATE");};
  try{assert.doesNotThrow(()=>emit("error",new Error("SYNTHETIC_PRIVATE")));assert.doesNotThrow(()=>partnerClientRendered(read));}finally{console.info=capture;}
  emit("error",new Error("SYNTHETIC_PRIVATE"));assert.equal(rows.at(-1)?.trace_state,"read");
 });
});
test("Merchant and Sales listeners retain their original exception contract and Partner emits nothing off route", async () => {
 for(const route of ["/app/merchants","/app/merchant-sales"]){await browser((emit, rows)=>{
  const captured:string[]=[],old=console.info;console.info=line=>captured.push(String(line));
  try{emit("error",new Error("SYNTHETIC_PRIVATE"));emit("unhandledrejection",new Error("SYNTHETIC_PRIVATE"));}finally{console.info=old;}
  assert.equal(rows.length,0);assert.equal(captured.length,2);
  for(const line of captured){assert.ok(line.startsWith("BOSS_MERCHANT_DIAGNOSTIC "));const r=JSON.parse(line.slice("BOSS_MERCHANT_DIAGNOSTIC ".length));assert.equal(r.classification,"exception");assert.equal(r.stage,"client_exception");assert.ok(!("trace_state"in r));}
 },route);}
});
test("trace metadata is finite, defaults null outside client trace context and rejects arbitrary values", () => {
 const r=partnerDiagnosticRecord({correlationId:read,phase:"server-component",stage:"page_enter",observedAt:"src/app/app/partners/page.tsx",traceState:"SYNTHETIC_PRIVATE"}as never);
 assert.ok(r);assert.equal(Reflect.get(r,"trace_state"),null);assert.doesNotMatch(JSON.stringify(r),/SYNTHETIC_PRIVATE/);
});
