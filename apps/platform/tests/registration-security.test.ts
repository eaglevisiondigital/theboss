import assert from "node:assert/strict";
import test from "node:test";
import { parseRegistrationCommand, parseRegistrationQuery, projectRegistrationData, projectRegistrationResult, readBoundedJson } from "../src/lib/registration/input";
import { performRegistrationMutation } from "../src/lib/registration/mutation";
import { MAX_DOCUMENT_BYTES, PRIVATE_DOCUMENT_BUCKET, performDocumentDownload, performDocumentUpload, readDocumentBytes, validDocumentBytes, type DocumentClient } from "../src/lib/registration/documents";
import { performSensitiveAccess } from "../src/lib/registration/sensitive";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
import type { Json } from "../src/lib/supabase/database.types";

const actor = "00000000-0000-4000-8000-000000000001";
const registration = "00000000-0000-4000-8000-000000000002";
const requestId = "00000000-0000-4000-8000-000000000003";
const document = "00000000-0000-4000-8000-000000000004";
const intentId = "00000000-0000-4000-8000-000000000005";
const completionId = "00000000-0000-4000-8000-000000000006";
const form = "00000000-0000-4000-8000-000000000007";
const origin = "https://registration.boss.invalid";
const path = `${actor}/${registration}/${document}/${intentId}.pdf`;
const pdfText = "%PDF-1.4\nSynthetic acceptance fixture\n%%EOF";
const command = { operation: "registration.save", input: { registration_id: registration, expected_version: 1, context: { grade: 7 } } };
const envelope = { request_id: requestId, command };
const baseHeaders = { origin, host: "registration.boss.invalid", "sec-fetch-site": "same-origin" };
function jsonRequest(value: unknown = envelope, headers: Record<string, string> = {}) {
  return new Request(`${origin}/app/registrations/mutate`, { method: "POST", headers: { ...baseHeaders, "content-type": "application/json", ...headers }, body: JSON.stringify(value) });
}
function uploadRequest(headers: Record<string, string> = {}, content = pdfText) {
  return new Request(`${origin}/app/registrations/documents`, { method: "POST", headers: { ...baseHeaders, "content-type": "application/pdf", "x-document-id": document, "x-upload-request-id": requestId, "x-completion-request-id": completionId, ...headers }, body: content });
}
function mock() {
  const calls: { name: string; args: { p_request_id: string; p_command: Json } }[] = [];
  const storageCalls: { action: string; bucket: string; path: string }[] = [];
  let authCalls = 0;
  const client: DocumentClient = {
    auth: {
      getClaims: async () => { authCalls++; return { data: { claims: { sub: actor, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 120 } }, error: null }; },
      getUser: async () => { authCalls++; return { data: { user: { id: actor, is_anonymous: false } }, error: null }; },
    },
    rpc: async (name, args) => { calls.push({ name, args }); return { data: { request_id: args.p_request_id, resource_type: "registration", resource_id: registration, version: 2, sql_detail: "PRIVATE_SQL" }, error: null }; },
    storage: { from: bucket => ({
      upload: async (objectPath, _bytes, options) => { storageCalls.push({ action: "upload", bucket, path: objectPath }); assert.equal(options.upsert, false); assert.equal(options.cacheControl, "0"); return { error: null }; },
      download: async objectPath => { storageCalls.push({ action: "download", bucket, path: objectPath }); return { data: new Blob([pdfText]), error: null }; },
    }) },
  };
  return { client, calls, storageCalls, authCalls: () => authCalls };
}
function documentRpc(m: ReturnType<typeof mock>, uploadError: string | null = null) {
  m.client.rpc = async (name, args) => {
    m.calls.push({ name, args });
    const input = args.p_command as { operation: string };
    if (input.operation === "document.intent") return { data: { request_id: args.p_request_id, resource_type: "document_upload_intent", resource_id: intentId, intent_id: intentId, document_id: document, object_name: path }, error: null };
    if (input.operation === "document.complete") return uploadError ? { data: null, error: { code: uploadError } } : { data: { request_id: args.p_request_id, resource_type: "registration_document", resource_id: document, version: 3 }, error: null };
    return { data: { request_id: args.p_request_id, resource_type: "registration_document", resource_id: document, object_name: path, mime_type: "application/pdf" }, error: null };
  };
}

test("registration finite commands reject forged authority, actors and future tender", () => {
  assert.ok(parseRegistrationCommand(command));
  for (const value of [
    { ...command, actor }, { ...command, input: { ...command.input, is_admin: true } },
    { operation: "roles.assign", input: {} }, { operation: "payments.charge_card", input: {} },
    { ...command, input: { ...command.input, registration_id: "forged" } },
    { ...command, input: { ...command.input, expected_version: 0 } },
    { ...command, input: { ...command.input, expected_version: 1.5 } },
    { operation: "payment.record_offline", input: { method: "ach" } },
    { operation: "payment.record_offline", input: { method: "boss_bucks" } },
    { operation: "waiver.sign", input: { registration_id: registration, waiver_version_id: form, name: "Synthetic signer", consent: false } },
    { operation: "form.answer", input: { registration_id: registration, form_version_id: form, answers: [], finalize: true } },
  ]) assert.equal(parseRegistrationCommand(value), null);
});
test("registration inputs reject nonfinite values, control bytes, excessive nesting and collections", () => {
  let nested: unknown = true; for (let i = 0; i < 12; i++) nested = { nested };
  for (const context of [{ grade: Infinity }, { note: "bad\u0000value" }, nested, { values: new Array(101).fill(true) }]) assert.equal(parseRegistrationCommand({ ...command, input: { ...command.input, context } }), null);
});
test("registration filters reject repeated parameters and malformed resource IDs", () => {
  assert.deepEqual(parseRegistrationQuery({ org: actor, registration, q: "Synthetic", view: "admin" }), { view: "admin", organization_id: actor, registration_id: registration, query: "Synthetic" });
  for (const input of [{ org: "forged" }, { registration: "forged" }, { view: "public" }, { status: "x".repeat(31) }, { q: "x".repeat(101) }, { org: [actor, registration] }]) assert.equal(parseRegistrationQuery(input), null);
});
test("ordinary registration projection strips credentials, SQL and private object paths recursively", () => {
  const result = projectRegistrationData({ features: { registration: true }, operations: [], detail: { id: registration, forms: [{ answers: { favorite_color: "blue", session_value: "PRIVATE_SESSION", password: "PRIVATE_PASSWORD" }, object_name: path }], sql_detail: "PRIVATE_SQL" }, registrations: [{ id: registration, token: "PRIVATE_TOKEN" }], credential: "PRIVATE_AUTH" });
  assert.ok(result); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_|\.pdf/); assert.match(JSON.stringify(result), /favorite_color/);
});
test("ordinary registration projection rejects malformed operations and oversized collections", () => {
  assert.equal(projectRegistrationData({ features: {}, operations: ["roles.assign"] }), null);
  assert.equal(projectRegistrationData({ features: {}, operations: [], registrations: new Array(101).fill({ id: registration }) }), null);
  assert.equal(projectRegistrationData({ features: {}, operations: [], registrations: [null] }), null);
});
test("mutation result only contains safe identifiers and verifies exact retry identity", () => {
  assert.equal(projectRegistrationResult({ request_id: actor, resource_id: registration, resource_type: "registration" }, requestId), null);
  assert.equal(projectRegistrationResult({ request_id: requestId, resource_id: registration, resource_type: "auth.sessions" }, requestId), null);
  assert.deepEqual(projectRegistrationResult({ request_id: requestId, resource_id: registration, resource_type: "registration", version: 2, object_name: path, token: "PRIVATE_TOKEN", sql_detail: "PRIVATE_SQL" }, requestId), { request_id: requestId, resource_id: registration, resource_type: "registration", version: 2 });
});
test("bounded JSON rejects declared and actual overflow, malformed JSON and invalid UTF-8", async () => {
  assert.equal(await readBoundedJson(jsonRequest(envelope, { "content-length": "999999" })), null);
  assert.equal(await readBoundedJson(jsonRequest(envelope, { "content-length": "-1" })), null);
  assert.equal(await readBoundedJson(jsonRequest(envelope, { "content-type": "text/plain" })), null);
  assert.equal(await readBoundedJson(jsonRequest({ padding: "a".repeat(1024) }), 100), null);
  assert.equal(await readBoundedJson(new Request(origin, { method: "POST", headers: { "content-type": "application/json" }, body: "{" })), null);
  assert.equal(await readBoundedJson(new Request(origin, { method: "POST", headers: { "content-type": "application/json" }, body: new Uint8Array([0xc0, 0xaf]).buffer })), null);
});
test("registration mutations reject cross-origin requests before Auth or RPC", async () => {
  const m = mock();
  const invalidHeaders: Record<string, string>[] = [{ origin: "https://attacker.invalid" }, { host: "attacker.invalid" }, { "sec-fetch-site": "cross-site" }, { origin: "" }];
  for (const headers of invalidHeaders) assert.equal((await performRegistrationMutation(jsonRequest(envelope, headers), m.client, origin)).status, 403);
  assert.equal(m.authCalls(), 0); assert.equal(m.calls.length, 0);
});
test("generic mutation route refuses every sensitive retrieval and raw Storage intent", async () => {
  const m = mock();
  for (const [operation, input] of [
    ["document.intent", { document_id: document, mime_type: "application/pdf", size_bytes: 40 }],
    ["document.complete", { document_id: document, intent_id: intentId }],
    ["document.access", { document_id: document, purpose: "ordinary" }],
    ["emergency.access", { registration_id: registration, purpose: "ordinary" }],
    ["form.access", { registration_id: registration, form_version_id: form }],
  ]) assert.equal((await performRegistrationMutation(jsonRequest({ request_id: requestId, command: { operation, input } }), m.client, origin)).status, 422);
  assert.equal(m.calls.length, 0);
});
test("registration mutations require cryptographically verified and current Auth identities to agree", async () => {
  const m = mock();
  m.client.auth.getUser = async () => ({ data: { user: { id: registration } }, error: null });
  assert.equal((await performRegistrationMutation(jsonRequest(), m.client, origin)).status, 401);
  m.client.auth.getUser = async () => ({ data: { user: { id: actor, is_anonymous: true } }, error: null });
  assert.equal((await performRegistrationMutation(jsonRequest(), m.client, origin)).status, 401);
  m.client.auth.getClaims = async () => ({ data: null, error: null });
  assert.equal((await performRegistrationMutation(jsonRequest(), m.client, origin)).status, 401); assert.equal(m.calls.length, 0);
});
test("successful registration request forwards the same request UUID and finite command", async () => {
  const m = mock(); const result = await performRegistrationMutation(jsonRequest(), m.client, origin);
  assert.deepEqual(m.calls, [{ name: "boss_registration_mutate", args: { p_request_id: requestId, p_command: command } }]);
  assert.deepEqual(result, { status: 200, body: { ok: true, result: { request_id: requestId, resource_type: "registration", resource_id: registration, version: 2 } } });
});
test("database safe errors and thrown failures never expose SQL, credentials or stacks", async () => {
  const m = mock();
  for (const [code, status] of [["PT401", 401], ["PT403", 403], ["PT409", 409], ["PT422", 422], ["23503", 503]] as const) {
    m.client.rpc = async () => ({ data: null, error: { code, message: "PRIVATE_SQL", details: "PRIVATE_STACK" } });
    const response = await performRegistrationMutation(jsonRequest(), m.client, origin); assert.equal(response.status, status); assert.doesNotMatch(JSON.stringify(response), /PRIVATE_/);
  }
  m.client.rpc = async () => { throw new Error("PRIVATE_STACK"); };
  assert.equal((await performRegistrationMutation(jsonRequest(), m.client, origin)).status, 503);
});
test("untrusted or stale mutation results fail closed", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: actor, resource_type: "registration", resource_id: registration }, error: null });
  assert.equal((await performRegistrationMutation(jsonRequest(), m.client, origin)).status, 503);
});
test("document byte validation rejects misleading MIME, truncated formats and oversized content", () => {
  assert.equal(validDocumentBytes(new TextEncoder().encode(pdfText), "application/pdf"), true);
  assert.equal(validDocumentBytes(new TextEncoder().encode("%PDF-1.4\nNo end marker"), "application/pdf"), false);
  assert.equal(validDocumentBytes(new TextEncoder().encode("<script>synthetic</script>"), "application/pdf"), false);
  assert.equal(validDocumentBytes(new TextEncoder().encode(pdfText), "text/html"), false);
  assert.equal(validDocumentBytes(new Uint8Array(MAX_DOCUMENT_BYTES + 1), "application/pdf"), false);
  assert.equal(validDocumentBytes(new Uint8Array([255, 216, 255, 217]), "image/jpeg"), true);
  assert.equal(validDocumentBytes(new Uint8Array([255, 216, 1, 2]), "image/jpeg"), false);
  const png = new Uint8Array(24); png.set([137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(validDocumentBytes(png, "image/png"), true); png[0] = 0; assert.equal(validDocumentBytes(png, "image/png"), false);
});
test("private upload rejects cross-origin, ambiguous identifiers and wrong types before Storage", async () => {
  const m = mock();
  assert.equal((await performDocumentUpload(uploadRequest({ origin: "https://attacker.invalid" }), m.client, origin)).status, 403);
  const invalidHeaders: Record<string, string>[] = [{ "x-document-id": "forged" }, { "x-upload-request-id": completionId }, { "x-completion-request-id": "" }, { "content-type": "text/html" }];
  for (const headers of invalidHeaders) assert.equal((await performDocumentUpload(uploadRequest(headers), m.client, origin)).status, 422);
  assert.equal(m.calls.length, 0); assert.equal(m.storageCalls.length, 0);
});
test("private upload checks current authentication and actual file bytes before creating an intent", async () => {
  const m = mock();
  assert.equal((await performDocumentUpload(uploadRequest({}, "<html>Synthetic</html>"), m.client, origin)).status, 422); assert.equal(m.calls.length, 0);
  m.client.auth.getUser = async () => ({ data: { user: { id: actor, is_anonymous: true } }, error: null });
  assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 401); assert.equal(m.storageCalls.length, 0);
});
test("private byte reader enforces real stream size when Content-Length is absent", async () => {
  let canceled = false;
  const stream = new ReadableStream<Uint8Array>({ start(controller) { controller.enqueue(new Uint8Array(MAX_DOCUMENT_BYTES)); controller.enqueue(new Uint8Array(1)); }, cancel() { canceled = true; } });
  const init: RequestInit & { duplex: "half" } = { method: "POST", body: stream, duplex: "half" };
  const request = new Request(origin, init);
  assert.equal(await readDocumentBytes(request), null); assert.equal(canceled, true);
  assert.equal(await readDocumentBytes(uploadRequest({ "content-length": String(MAX_DOCUMENT_BYTES + 1) })), null);
});
test("upload uses immutable private object intent then transactional completion without returning a URL", async () => {
  const m = mock(); documentRpc(m); const response = await performDocumentUpload(uploadRequest(), m.client, origin);
  assert.equal(response.status, 200); assert.deepEqual(m.storageCalls, [{ action: "upload", bucket: PRIVATE_DOCUMENT_BUCKET, path }]);
  assert.equal(m.calls.length, 2); assert.equal((m.calls[0].args.p_command as { operation: string }).operation, "document.intent");
  assert.equal(m.calls[0].args.p_request_id, requestId); assert.equal(m.calls[1].args.p_request_id, completionId);
  assert.deepEqual(response, { status: 200, body: { ok: true, result: { document_id: document } } }); assert.doesNotMatch(JSON.stringify(response), /https:|object_name|\.pdf/);
});
test("duplicate immutable upload still delegates retry authorization to authoritative completion", async () => {
  const m = mock(); documentRpc(m); m.client.storage.from = bucket => ({ upload: async objectPath => { m.storageCalls.push({ action: "upload", bucket, path: objectPath }); return { error: { message: "Synthetic object already exists" } }; }, download: async () => ({ data: null, error: null }) });
  assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 200); assert.equal(m.calls.length, 2);
});
test("same-size file changes produce distinct server-computed retry digests", async () => {
  const m = mock(); documentRpc(m);
  await performDocumentUpload(uploadRequest(), m.client, origin);
  const first = (m.calls[0].args.p_command as { input: { sha256: string } }).input.sha256;
  assert.match(first, /^[a-f0-9]{64}$/);
  m.calls.length = 0;
  await performDocumentUpload(uploadRequest({}, pdfText.replace("Synthetic", "SynthEtic")), m.client, origin);
  const second = (m.calls[0].args.p_command as { input: { sha256: string } }).input.sha256;
  assert.notEqual(first, second);
});
test("upload refuses a stale or unsafe intent before any Storage operation", async () => {
  const m = mock();
  for (const badPath of ["../private.pdf", "https://external.invalid/private.pdf", "private.html"]) {
    m.client.rpc = async () => ({ data: { request_id: requestId, intent_id: intentId, object_name: badPath }, error: null });
    assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 503);
  }
  m.client.rpc = async () => ({ data: { request_id: actor, intent_id: intentId, object_name: path }, error: null });
  assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 503); assert.equal(m.storageCalls.length, 0);
});
test("failed completion cannot be reported as a successful private document submission", async () => {
  const m = mock(); documentRpc(m, "PT403"); assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 403);
  m.client.rpc = async (_name, args) => (args.p_command as { operation: string }).operation === "document.intent" ? { data: { request_id: requestId, intent_id: intentId, object_name: path }, error: null } : { data: { request_id: completionId, resource_id: actor }, error: null };
  assert.equal((await performDocumentUpload(uploadRequest(), m.client, origin)).status, 503);
});
test("download audits the requested ordinary or exact-team emergency access before Storage", async () => {
  const m = mock(); documentRpc(m);
  const request = jsonRequest({ document_id: document, request_id: requestId, purpose: "emergency", team_id: form });
  const result = await performDocumentDownload(request, m.client, origin);
  assert.equal(result.status, 200); assert.deepEqual(m.calls[0].args.p_command, { operation: "document.access", input: { document_id: document, purpose: "emergency", team_id: form } });
  assert.deepEqual(m.storageCalls, [{ action: "download", bucket: PRIVATE_DOCUMENT_BUCKET, path }]);
  assert.ok("file" in result); if ("file" in result) { assert.equal(result.filename, "private-document.pdf"); assert.equal(await result.file.text(), pdfText); }
});
test("denied document access never invokes Storage and does not expose private paths", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: null, error: { code: "PT403", message: "PRIVATE_PATH" } });
  const result = await performDocumentDownload(jsonRequest({ document_id: document, request_id: requestId, purpose: "ordinary" }), m.client, origin);
  assert.equal(result.status, 403); assert.equal(m.storageCalls.length, 0); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_/);
});
test("download requires document identity echoed by the audited access result", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: requestId, resource_id: actor, object_name: path, mime_type: "application/pdf" }, error: null });
  assert.equal((await performDocumentDownload(jsonRequest({ document_id: document, request_id: requestId, purpose: "ordinary" }), m.client, origin)).status, 503); assert.equal(m.storageCalls.length, 0);
});
test("Storage denial remains fail-closed after an access lease was issued", async () => {
  const m = mock(); documentRpc(m); m.client.storage.from = () => ({ upload: async () => ({ error: null }), download: async () => ({ data: null, error: { message: "PRIVATE_STORAGE" } }) });
  assert.equal((await performDocumentDownload(jsonRequest({ document_id: document, request_id: requestId, purpose: "ordinary" }), m.client, origin)).status, 403);
});
test("sensitive access rejects generic mutations, forged fields and cross-origin input", async () => {
  const m = mock();
  assert.equal((await performSensitiveAccess(jsonRequest(), m.client, origin)).status, 422);
  assert.equal((await performSensitiveAccess(jsonRequest({ request_id: requestId, command: { operation: "emergency.access", input: { registration_id: registration, purpose: "emergency", team_id: form, is_admin: true } } }), m.client, origin)).status, 422);
  assert.equal((await performSensitiveAccess(jsonRequest(envelope, { origin: "https://attacker.invalid" }), m.client, origin)).status, 403); assert.equal(m.calls.length, 0);
});
test("emergency result exposes only necessary audited fields and excludes insurance", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: requestId, resource_id: document, contacts: [{ name: "Synthetic contact", relationship: "Guardian", phone: "Synthetic phone", password: "PRIVATE_PASSWORD" }], medical: { allergies: "Synthetic allergy", hidden: "PRIVATE_MEDICAL" }, physician: { name: "Synthetic physician", secret: "PRIVATE_PHYSICIAN" }, insurance: { provider: "PRIVATE_INSURANCE" }, token: "PRIVATE_TOKEN", version: 1 }, error: null });
  const result = await performSensitiveAccess(jsonRequest({ request_id: requestId, command: { operation: "emergency.access", input: { registration_id: registration, purpose: "emergency", team_id: form } } }), m.client, origin);
  assert.equal(result.status, 200); assert.match(JSON.stringify(result), /Synthetic allergy/); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_|insurance/);
});
test("sensitive form read preserves authorized answers while discarding unknown RPC fields", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: requestId, resource_id: document, form_version_id: form, definition: { fields: [{ key: "medical_condition", type: "short_text", label: "Synthetic question" }] }, answers: { medical_condition: "Synthetic answer" }, status: "submitted", completed_at: "2026-10-01T12:00:00Z", token: "PRIVATE_TOKEN", sql_detail: "PRIVATE_SQL" }, error: null });
  const result = await performSensitiveAccess(jsonRequest({ request_id: requestId, command: { operation: "form.access", input: { registration_id: registration, form_version_id: form } } }), m.client, origin);
  assert.equal(result.status, 200); assert.match(JSON.stringify(result), /Synthetic answer/); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_/);
});
test("first medical form access permits a blank audited definition without fabricating an answer version", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: requestId, resource_type: "form_version", resource_id: form, form_version_id: form, definition: { fields: [{ key: "allergies", type: "short_text", label: "Synthetic medical question" }] }, answers: {}, status: "not_started", completed_at: null, version: null }, error: null });
  const result = await performSensitiveAccess(jsonRequest({ request_id: requestId, command: { operation: "form.access", input: { registration_id: registration, form_version_id: form } } }), m.client, origin);
  assert.equal(result.status, 200); assert.equal(result.body.ok, true);
  if (result.body.ok) { assert.deepEqual(result.body.result.answers, {}); assert.equal(result.body.result.status, "not_started"); assert.equal(result.body.result.version, undefined); }
});
test("sensitive access rejects denied, malformed or stale responses without medical leakage", async () => {
  const m = mock(); const input = { request_id: requestId, command: { operation: "emergency.access", input: { registration_id: registration, purpose: "ordinary" } } };
  m.client.rpc = async () => ({ data: null, error: { code: "PT403", message: "PRIVATE_MEDICAL" } });
  const denied = await performSensitiveAccess(jsonRequest(input), m.client, origin); assert.equal(denied.status, 403); assert.doesNotMatch(JSON.stringify(denied), /PRIVATE_/);
  m.client.rpc = async () => ({ data: { request_id: actor, resource_id: document, contacts: [], medical: {}, physician: {} }, error: null });
  assert.equal((await performSensitiveAccess(jsonRequest(input), m.client, origin)).status, 503);
  m.client.rpc = async () => ({ data: { request_id: requestId, resource_id: document, contacts: new Array(11).fill({}), medical: {}, physician: {} }, error: null });
  assert.equal((await performSensitiveAccess(jsonRequest(input), m.client, origin)).status, 503);
});
