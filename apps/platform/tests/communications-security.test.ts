import assert from "node:assert/strict";
import test from "node:test";
import type { Json } from "../src/lib/supabase/database.types";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
import { parseCommunicationCommand, parseCommunicationQuery, projectCommunicationData, readBoundedJson } from "../src/lib/communications/input";
import { performCommunicationMutation } from "../src/lib/communications/mutation";
import { COMMUNICATION_ATTACHMENT_BUCKET, performCommunicationDownload, performCommunicationUpload, safeCommunicationPath, type CommunicationAttachmentClient } from "../src/lib/communications/attachments";
import { parseNotificationCommand, parseNotificationQuery, projectNotificationData, safeNotificationDestination } from "../src/lib/notifications/input";
import { performNotificationMutation, type NotificationClient } from "../src/lib/notifications/mutation";
import { CommunicationUploadRetry } from "../src/lib/communications/upload-retry";

const actor = "00000000-0000-4000-8000-000000000001", thread = "00000000-0000-4000-8000-000000000002", requestId = "00000000-0000-4000-8000-000000000003", attachment = "00000000-0000-4000-8000-000000000004", objectKey = "00000000-0000-4000-8000-000000000005", completionId = "00000000-0000-4000-8000-000000000006";
const origin = "https://communications.boss.invalid", path = `${actor}/${thread}/${attachment}/${objectKey}`, pdf = "%PDF-1.4\nControlled synthetic attachment\n%%EOF";
const command = { operation: "message.send", input: { thread_id: thread, body: "Controlled message" } };
const headers = { origin, host: "communications.boss.invalid", "sec-fetch-site": "same-origin", "content-type": "application/json" };
function request(value: unknown = { request_id: requestId, command }, extra: Record<string, string> = {}) { return new Request(`${origin}/app/communications/mutate`, { method: "POST", headers: { ...headers, ...extra }, body: JSON.stringify(value) }); }
function upload(extra: Record<string, string> = {}, body = pdf) { return new Request(`${origin}/app/communications/upload`, { method: "POST", headers: { ...headers, "content-type": "application/pdf", "x-thread-id": thread, "x-file-name": "controlled.pdf", "x-upload-request-id": requestId, "x-completion-request-id": completionId, ...extra }, body }); }
function mock() {
  const calls: { name: string; args: { p_request_id: string; p_command: Json } }[] = [], storage: { action: string; path: string }[] = [];
  const client: CommunicationAttachmentClient = {
    auth: { getClaims: async () => ({ data: { claims: { sub: actor, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 120 } }, error: null }), getUser: async () => ({ data: { user: { id: actor, is_anonymous: false } }, error: null }) },
    rpc: async (name, args) => { calls.push({ name, args }); const input = args.p_command as { operation: string }; return { data: { request_id: args.p_request_id, operation: input.operation, resource_id: input.operation.startsWith("attachment.") ? attachment : thread, version: 1, attachment_id: attachment, bucket: COMMUNICATION_ATTACHMENT_BUCKET, object_name: path, mime_type: "application/pdf", token: "PRIVATE_TOKEN", sql: "PRIVATE_SQL" }, error: null }; },
    storage: { from: bucket => { assert.equal(bucket, COMMUNICATION_ATTACHMENT_BUCKET); return { upload: async (objectPath, _bytes, options) => { storage.push({ action: "upload", path: objectPath }); assert.equal(options.upsert, false); assert.equal(options.cacheControl, "0"); return { error: null }; }, download: async objectPath => { storage.push({ action: "download", path: objectPath }); return { data: new Blob([pdf], { type: "application/pdf" }), error: null }; } }; } },
  };
  return { client, calls, storage };
}

test("communications finite commands reject authority injection and bounded audience violations", () => {
  assert.ok(parseCommunicationCommand(command));
  for (const value of [{ ...command, actor }, { ...command, input: { ...command.input, is_admin: true } }, { operation: "role.assign", input: {} }, { ...command, input: { thread_id: "forged", body: "message" } }, { ...command, input: { thread_id: thread, body: "x".repeat(8001) } }, { ...command, input: { thread_id: thread, body: "bad\u0000value" } }, { operation: "thread.create", input: { organization_id: actor, kind: "group", title: "Group", scope_type: "team", scope_id: thread, members: new Array(21).fill(attachment) } }, { operation: "announcement.send", input: { organization_id: actor, title: "Notice", body: "Test", targets: [{ scope_type: "team", scope_id: thread, tenant_override: actor }] } }, { operation: "message.edit", input: { message_id: thread, body: "Edit", expected_version: 0 } }]) assert.equal(parseCommunicationCommand(value), null);
});
test("communications configuration matches finite SQL policy fields", () => {
  assert.ok(parseCommunicationCommand({ operation: "communications.configure", input: { organization_id: actor, configuration: { communications: true, announcements: true, in_app_notifications: true, minimum_participant_age: 18 } } }));
  for (const configuration of [{ is_admin: true }, { minimum_participant_age: 100 }, { sender_edit_minutes: 61 }, { attachments: "true" }]) assert.equal(parseCommunicationCommand({ operation: "communications.configure", input: { organization_id: actor, configuration } }), null);
});
test("communications queries reject malformed and repeated identifiers", () => {
  assert.deepEqual(parseCommunicationQuery({ org: actor, thread, before: "25", q: "practice" }, "messages"), { view: "messages", organization_id: actor, thread_id: thread, before_sequence: 25, query: "practice" });
  for (const value of [{ org: [actor, thread] }, { team: "forged" }, { before: "0" }, { q: "x".repeat(101) }]) assert.equal(parseCommunicationQuery(value, "messages"), null);
});
test("communications read projection suppresses private paths, contact details and removed content", () => {
  const data = projectCommunicationData({ features: { communications: true }, threads: [], detail: { thread: { id: thread, organization_id: actor, title: "Controlled", operations: [] }, messages: [{ id: attachment, status: "removed", body: "PRIVATE_REMOVED_BODY", sequence: 1, attachments: [{ id: objectKey, object_name: "PRIVATE_PATH" }] }, { id: objectKey, status: "visible", body: "Safe body", primary_email: "PRIVATE_CONTACT", attachments: [{ id: attachment, filename: "controlled.pdf", object_name: "PRIVATE_PATH", token: "PRIVATE_TOKEN" }] }] }, candidates: [{ id: actor, label: "Name only", date_of_birth: "PRIVATE_DOB", primary_email: "PRIVATE_EMAIL" }], token: "PRIVATE_TOKEN" });
  assert.ok(data); assert.doesNotMatch(JSON.stringify(data), /PRIVATE_/); assert.equal(data.detail?.messages[0].body, null); assert.equal(data.detail?.messages[0].attachments.length, 0); assert.equal(data.detail?.messages[1].body, "Safe body");
});
test("same-origin and current verified identity gate communications before the RPC", async () => {
  const m = mock(); assert.equal((await performCommunicationMutation(request(undefined, { origin: "https://attacker.invalid" }), m.client, origin)).status, 403); assert.equal(m.calls.length, 0);
  m.client.auth.getUser = async () => ({ data: { user: { id: thread } }, error: null }); assert.equal((await performCommunicationMutation(request(), m.client, origin)).status, 401); assert.equal(m.calls.length, 0);
  m.client.auth.getUser = async () => ({ data: { user: { id: actor, is_anonymous: true } }, error: null }); assert.equal((await performCommunicationMutation(request(), m.client, origin)).status, 401);
});
test("mutation envelopes exclude dedicated attachment operations and oversized streamed input", async () => {
  const m = mock(); assert.equal((await performCommunicationMutation(request({ request_id: requestId, command: { operation: "attachment.access", input: { attachment_id: attachment } } }), m.client, origin)).status, 422); assert.equal(m.calls.length, 0);
  assert.equal(await readBoundedJson(request({ body: "x".repeat(25_000) })), null); assert.equal(await readBoundedJson(request(undefined, { "content-length": "999999" })), null);
});
test("communications RPC results bind operation and retry ID while suppressing SQL details", async () => {
  const m = mock(); const successful = await performCommunicationMutation(request(), m.client, origin); assert.equal(successful.status, 200); assert.doesNotMatch(JSON.stringify(successful), /PRIVATE_/);
  m.client.rpc = async () => ({ data: { request_id: completionId, operation: "message.send", resource_id: thread, version: 1 }, error: null }); assert.equal((await performCommunicationMutation(request(), m.client, origin)).status, 503);
  m.client.rpc = async () => ({ data: null, error: { code: "23503", message: "PRIVATE_SQL" } }); assert.doesNotMatch(JSON.stringify(await performCommunicationMutation(request(), m.client, origin)), /PRIVATE_/);
  m.client.rpc = async () => { throw new Error("PRIVATE_STACK"); }; assert.doesNotMatch(JSON.stringify(await performCommunicationMutation(request(), m.client, origin)), /PRIVATE_/);
});
test("real managed attachment UUID path contract supports upload and audited byte download", async () => {
  assert.ok(safeCommunicationPath(path, attachment, thread)); assert.equal(safeCommunicationPath(`${path}.pdf`, attachment, thread), false); assert.equal(safeCommunicationPath(path, objectKey, thread), false); assert.equal(safeCommunicationPath(path, attachment, actor), false);
  const m = mock(); const uploaded = await performCommunicationUpload(upload(), m.client, origin); assert.equal(uploaded.status, 200); assert.equal(m.storage[0].path, path); assert.equal(m.calls.length, 2); assert.equal(m.calls[0].args.p_request_id, requestId); assert.equal(m.calls[1].args.p_request_id, completionId); assert.doesNotMatch(JSON.stringify(uploaded), /object_name|PRIVATE_|bucket/);
  const input = m.calls[0].args.p_command as { input: { content_sha256: string; size_bytes: number } }; assert.match(input.input.content_sha256, /^[a-f0-9]{64}$/); assert.equal(input.input.size_bytes, new TextEncoder().encode(pdf).length);
  const downloaded = await performCommunicationDownload(request({ request_id: requestId, attachment_id: attachment }), m.client, origin); assert.equal(downloaded.status, 200); assert.ok("file" in downloaded); assert.equal(await downloaded.file.text(), pdf); assert.equal(downloaded.filename, "private-attachment.pdf");
});
test("attachments reject MIME lies, oversized data, path substitutions and current revocation", async () => {
  for (const req of [upload({}, "not a PDF"), upload({ "content-type": "text/html" }), upload({ "content-length": "5242881" }), upload({ "x-file-name": "..%2Funsafe.pdf" }), upload({ "x-completion-request-id": requestId })]) { const m = mock(); assert.equal((await performCommunicationUpload(req, m.client, origin)).status, 422); assert.equal(m.storage.length, 0); }
  const m = mock(); m.client.rpc = async (_name, args) => ({ data: { request_id: args.p_request_id, operation: "attachment.access", resource_id: attachment, bucket: COMMUNICATION_ATTACHMENT_BUCKET, object_name: `${actor}/${thread}/${objectKey}/${objectKey}`, mime_type: "application/pdf" }, error: null }); assert.equal((await performCommunicationDownload(request({ request_id: requestId, attachment_id: attachment }), m.client, origin)).status, 503); assert.equal(m.storage.length, 0);
  m.client.rpc = async () => ({ data: null, error: { code: "PT403" } }); assert.equal((await performCommunicationDownload(request({ request_id: requestId, attachment_id: attachment }), m.client, origin)).status, 403); assert.equal(m.storage.length, 0);
});
test("private upload retries still require successful authoritative completion", async () => {
  const m = mock(); m.client.storage.from = () => ({ upload: async () => ({ error: { message: "already uploaded" } }), download: async () => ({ data: null, error: null }) }); assert.equal((await performCommunicationUpload(upload(), m.client, origin)).status, 200);
  const original = m.client.rpc; m.client.rpc = async (name, args) => (args.p_command as { operation: string }).operation === "attachment.complete" ? { data: null, error: { code: "PT403" } } : original(name, args); assert.equal((await performCommunicationUpload(upload(), m.client, origin)).status, 403);
});
test("notification destinations allow only fixed local source links, including payment family index", () => {
  for (const path of [`/app/messages?org=${actor}&thread=${thread}`, `/app/announcements?org=${actor}&thread=${thread}`, `/app/calendar?org=${actor}&event=${thread}`, `/app/registrations?org=${actor}&registration=${thread}`, `/app/registrations?view=family&org=${actor}`]) assert.ok(safeNotificationDestination(path));
  for (const path of ["https://attacker.invalid", "//attacker.invalid/app/messages", `/app/messages?org=${actor}&thread=${thread}&redirect=https://attacker.invalid`, `/app/registrations?view=admin&org=${actor}`, `/app/registrations?view=family&org=${actor}&registration=${thread}`, `/app/messages?org=${actor}&org=${thread}&thread=${thread}`, `/app/messages?org=${actor}&thread=${thread}#hidden`, `/app/messages?org=forged&thread=${thread}`]) assert.equal(safeNotificationDestination(path), null);
});
test("notification inputs reject raw recipient/email/link injection and future delivery channels", () => {
  assert.ok(parseNotificationCommand({ operation: "preference.set", input: { channel: "email", category: "events", enabled: false, organization_id: actor } }));
  for (const command of [{ operation: "notification.read", input: { id: thread, person_id: actor } }, { operation: "preference.set", input: { channel: "sms", category: "events", enabled: true } }, { operation: "preference.set", input: { channel: "email", category: "events", enabled: true, recipient_email: "forged@example.invalid" } }, { operation: "notification.send", input: { destination: "https://attacker.invalid" } }, { operation: "delivery.process", input: { organization_id: actor, limit: 51 } }]) assert.equal(parseNotificationCommand(command), null);
  for (const query of [{ org: [actor, thread] }, { category: "forged" }, { view: "global" }, { before: "invalid" }]) assert.equal(parseNotificationQuery(query), null);
});
test("notification read strips provider/private payloads and unsafe destinations", () => {
  const data = projectNotificationData({ notifications: [{ id: thread, organization_id: actor, category: "fees", title: "Payment recorded", body: "Safe receipt", destination: "https://attacker.invalid", created_at: "2026-10-02T05:00:00Z", provider_key: "PRIVATE_KEY" }], history: [{ id: attachment, status: "sent", recipient_name: "Name", raw_email: "PRIVATE_EMAIL", payload: "PRIVATE_PAYLOAD", provider_reference: "PRIVATE_PROVIDER" }], availability: { in_app: true, email: "not_configured", sms: "future", push: "future" }, features: { delivery_history: true }, unread_count: 4 });
  assert.ok(data); assert.equal(data.notifications[0].destination, null); assert.equal(data.features.delivery_history, true); assert.equal(data.unread_count, 4); assert.doesNotMatch(JSON.stringify(data), /PRIVATE_/);
});
test("notification mutations require current Auth, matching retry identity and safe failure responses", async () => {
  const m = mock(); const client: NotificationClient = { auth: m.client.auth, rpc: async (_name, args) => ({ data: { request_id: args.p_request_id, operation: "notification.read", resource_id: thread, version: 1, email: "PRIVATE_EMAIL" }, error: null }) };
  const input = { request_id: requestId, command: { operation: "notification.read", input: { id: thread } } }; const result = await performNotificationMutation(request(input), client, origin); assert.equal(result.status, 200); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_/);
  assert.equal((await performNotificationMutation(request(input, { origin: "https://attacker.invalid" }), client, origin)).status, 403);
  client.rpc = async () => ({ data: { request_id: completionId, operation: "notification.read", resource_id: thread, version: 1 }, error: null }); assert.equal((await performNotificationMutation(request(input), client, origin)).status, 503);
  client.auth.getUser = async () => ({ data: { user: null }, error: null }); assert.equal((await performNotificationMutation(request(input), client, origin)).status, 401);
});

test("calendar notification destinations allow only real calendar dates on calendar links", () => {
  assert.ok(safeNotificationDestination(`/app/calendar?org=${actor}&event=${thread}&date=2026-10-02`));
  for (const suffix of ["date=2026-02-31", "date=2026-13-01", "date=invalid", "date=2026-10-02&date=2026-10-03", "date=2026-10-02&scope=organization"]) assert.equal(safeNotificationDestination(`/app/calendar?org=${actor}&event=${thread}&${suffix}`), null);
  assert.equal(safeNotificationDestination(`/app/messages?org=${actor}&thread=${thread}&date=2026-10-02`), null);
});

test("calendar notification links preserve finite timezone and exact moved occurrence", () => {
  const base = `/app/calendar?org=${actor}&event=${thread}`;
  const key = "2026-10-01T23%3A30%3A00";
  const destination = safeNotificationDestination(`${base}&date=2026-10-02&tz=America%2FChicago&occurrence=${key}`);
  assert.ok(destination);
  assert.equal(new URL(destination, origin).searchParams.get("occurrence"), "2026-10-01T23:30:00");
  assert.ok(safeNotificationDestination(`${base}&date=2026-10-02&tz=Etc%2FGMT%2B5&occurrence=${key}`));
  for (const suffix of [`date=2026-10-02&occurrence=${key}`, `tz=UTC&occurrence=${key}`, `date=2026-10-02&tz=Invented%2FZone&occurrence=${key}`, `date=2026-10-02&tz=UTC&tz=America%2FChicago&occurrence=${key}`, `date=2026-10-02&tz=UTC&occurrence=${key}&occurrence=${key}`, "date=2026-10-02&tz=UTC&occurrence=2026-02-30T12%3A00%3A00", "date=2026-10-02&tz=UTC&occurrence=2026-10-01T24%3A00%3A00", "date=2026-10-02&tz=UTC&occurrence=2026-10-01T12%3A00%3A00Z", "date=2026-10-02&tz=UTC&redirect=https%3A%2F%2Fattacker.invalid"]) assert.equal(safeNotificationDestination(`${base}&${suffix}`), null);
  assert.equal(safeNotificationDestination(`/app/messages?org=${actor}&thread=${thread}&date=2026-10-02&tz=UTC&occurrence=${key}`), null);
});

test("same-file upload identities survive uncertainty but reset after confirmed success", () => {
  const retry = new CommunicationUploadRetry(); let sequence = 0; const newId = () => `controlled-${++sequence}`;
  const first = retry.request("same-thread:file.pdf:bytes-A", newId);
  assert.deepEqual(retry.request("same-thread:file.pdf:bytes-A", newId), first);
  retry.confirmed();
  const nextMessage = retry.request("same-thread:file.pdf:bytes-A", newId);
  assert.notEqual(nextMessage.request, first.request); assert.notEqual(nextMessage.completion, first.completion);
  assert.deepEqual(retry.request("same-thread:file.pdf:bytes-A", newId), nextMessage);
  const changedBytes = retry.request("same-thread:file.pdf:bytes-B", newId);
  assert.notEqual(changedBytes.request, nextMessage.request); assert.notEqual(changedBytes.request, changedBytes.completion);
});

test("confirmed completed upload replay recovers safely without new Storage writes", async () => {
  for (const status of ["ready", "attached"]) {
    const m = mock(), original = m.client.rpc;
    m.client.rpc = async (name, args) => { const result = await original(name, args); return { ...result, data: { ...(result.data as Record<string, Json>), completed: true, status } }; };
    const replay = await performCommunicationUpload(upload(), m.client, origin);
    assert.equal(replay.status, 200); assert.equal(m.calls.length, 1); assert.equal(m.storage.length, 0);
    assert.doesNotMatch(JSON.stringify(replay), /PRIVATE_|object_name|bucket|completed/);
  }
  const invalid = mock(), original = invalid.client.rpc;
  invalid.client.rpc = async (name, args) => { const result = await original(name, args); return { ...result, data: { ...(result.data as Record<string, Json>), completed: true, status: "upload_pending" } }; };
  assert.equal((await performCommunicationUpload(upload(), invalid.client, origin)).status, 503); assert.equal(invalid.storage.length, 0);
  invalid.client.rpc = async () => ({ data: null, error: { code: "PT403" } });
  assert.equal((await performCommunicationUpload(upload(), invalid.client, origin)).status, 403); assert.equal(invalid.storage.length, 0);
  const unconfirmed = mock(), before = unconfirmed.client.rpc;
  unconfirmed.client.rpc = async (name, args) => { const result = await before(name, args); return { ...result, data: { ...(result.data as Record<string, Json>), completed: false, status: "ready" } }; };
  assert.equal((await performCommunicationUpload(upload(), unconfirmed.client, origin)).status, 200); assert.equal(unconfirmed.storage.length, 1); assert.equal(unconfirmed.calls.length, 2);
});
