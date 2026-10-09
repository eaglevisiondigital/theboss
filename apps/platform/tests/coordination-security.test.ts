import assert from "node:assert/strict";
import test from "node:test";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
import { parseAttendanceCommand, parseAttendanceQuery, projectAttendanceData } from "../src/lib/attendance/input";
import { parseVolunteerCommand, parseVolunteerQuery, projectVolunteerData } from "../src/lib/volunteers/input";
import { performCoordinationMutation, type CoordinationClient } from "../src/lib/coordination/mutation";
import { instant } from "../src/lib/coordination/input";
const actor = "00000000-0000-4000-8000-000000000001", event = "00000000-0000-4000-8000-000000000002", participant = "00000000-0000-4000-8000-000000000003", requestId = "00000000-0000-4000-8000-000000000004", shift = "00000000-0000-4000-8000-000000000005", occurrence = "2026-10-03T18:00:00", origin = "https://coordination.boss.invalid";
const response = { operation: "response.set", input: { event_id: event, occurrence_key: occurrence, person_id: actor, participant_id: participant, subject_kind: "participant", status: "attending", expected_version: 0, reason: null, note: null, arrival_difference_minutes: null, departure_difference_minutes: null } };
function request(command: unknown = response, extra: Record<string, string> = {}, body?: string) { return new Request(`${origin}/app/attendance/mutate`, { method: "POST", headers: { origin, host: "coordination.boss.invalid", "sec-fetch-site": "same-origin", "content-type": "application/json", ...extra }, body: body ?? JSON.stringify({ command, request_id: requestId }) }); }
function mock() {
  const calls: unknown[] = []; let verifications = 0;
  const client: CoordinationClient = { auth: { getClaims: async () => ({ data: { claims: { sub: actor, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 120 } }, error: null }), getUser: async () => { verifications++; return { data: { user: { id: actor, is_anonymous: false } }, error: null }; } }, rpc: async (name, args) => { calls.push({ name, args }); return { data: { request_id: args.p_request_id, operation: (args.p_command as { operation: string }).operation, resource_id: event, version: 1, token: "PRIVATE_TOKEN", note: "PRIVATE_NOTE" }, error: null }; } };
  return { client, calls, verifications: () => verifications };
}
test("attendance finite input rejects injected authority, unrelated operation and forged occurrence syntax", () => {
  assert.ok(parseAttendanceCommand(response));
  for (const value of [{ ...response, actor_id: actor }, { ...response, input: { ...response.input, tenant_override: actor } }, { ...response, input: { ...response.input, occurrence_key: "2026-02-30T18:00:00" } }, { ...response, input: { ...response.input, occurrence_key: `${occurrence}Z` } }, { ...response, input: { ...response.input, participant_id: null } }, { ...response, input: { ...response.input, note: "x".repeat(501) } }, { ...response, input: { ...response.input, reason: "private\u0000reason" } }, { ...response, input: { ...response.input, arrival_difference_minutes: 1441 } }, { ...response, input: { ...response.input, expected_version: -1 } }, { operation: "participant.assign", input: {} }]) assert.equal(parseAttendanceCommand(value), null);
});
test("staff response and check-in retain a separate canonical subject type", () => {
  assert.ok(parseAttendanceCommand({ ...response, input: { ...response.input, participant_id: null, subject_kind: "staff", arrival_difference_minutes: 15 } }));
  assert.ok(parseAttendanceCommand({ operation: "checkin.set", input: { event_id: event, occurrence_key: occurrence, person_id: actor, participant_id: participant, subject_kind: "participant", state: "late", expected_version: 0 } }));
  assert.equal(parseAttendanceCommand({ ...response, input: { ...response.input, subject_kind: "staff" } }), null);
});
test("deadline configuration validates mutually exclusive fixed and recurring deadline models", () => {
  const command = { operation: "event.configure", input: { event_id: event, expected_version: 0, rsvp_mode: "required", deadline_policy: "lock", change_policy: "needs_reconfirmation", audience: ["participants", "staff"], response_deadline_at: null, deadline_offset_minutes: 2880 } }; assert.ok(parseAttendanceCommand(command));
  for (const fields of [{ response_deadline_at: "2026-10-02T20:00:00Z" }, { deadline_offset_minutes: -1 }, { deadline_policy: "always_override" }, { change_policy: "forget" }, { audience: ["participants", "participants"] }, { audience: ["public"] }]) assert.equal(parseAttendanceCommand({ ...command, input: { ...command.input, ...fields } }), null);
});
test("attendance features are finite booleans with bounded self-response policy", () => {
  assert.ok(parseAttendanceCommand({ operation: "attendance.configure", input: { organization_id: actor, configuration: { attendance: true, guardian_rsvp: true, participant_self_response: false, minimum_self_response_age: 18 } } }));
  for (const configuration of [{ is_admin: true }, { guardian_rsvp: "true" }, { minimum_self_response_age: 101 }, { minimum_self_response_age: 17 }, {}]) assert.equal(parseAttendanceCommand({ operation: "attendance.configure", input: { organization_id: actor, configuration } }), null);
});
test("coordination queries reject repeated and malformed IDs and bound actual date windows", () => {
  const query = parseAttendanceQuery({ org: actor, child: participant, from: "2026-10-02", to: "2026-10-04" }); assert.ok(query); assert.equal(query.from, "2026-10-02T00:00:00.000Z"); assert.equal(query.to, "2026-10-05T00:00:00.000Z"); assert.equal(query.child_person_id, participant);
  for (const fields of [{ org: [actor, event] }, { child: "forged" }, { occurrence }, { event, occurrence: "2026-10-02T24:00:00" }, { from: "2026-02-30", to: "2026-03-02" }, { from: "2026-10-02", to: "2027-10-02" }, { view: "public" }]) assert.equal(parseAttendanceQuery(fields), null);
  assert.equal(parseVolunteerQuery({ shift: [actor, shift] }), null); assert.equal(parseVolunteerQuery({ limit: "101" }), null);
  assert.equal(instant("2026-02-30T18:00:00Z"), false); assert.equal(instant("2026-10-02T24:00:00Z"), false);
});
test("attendance projections expose private absence notes only through explicit capability", () => {
  const query = parseAttendanceQuery({ org: actor })!, subject = { person_id: actor, participant_id: participant, subject_kind: "participant", display_name: "Controlled child", response: { id: shift, status: "not_attending", version: 1, note: "PRIVATE_NOTE", reason: "PRIVATE_REASON", arrival_difference_minutes: 7 }, capabilities: { respond: false, manage: false } };
  const occurrenceRow = { event_id: event, organization_id: actor, occurrence_key: occurrence, title: "Practice", start_at: "2026-10-03T18:00:00Z", end_at: "2026-10-03T19:00:00Z", settings: {}, summary: { not_attending: 1 }, subjects: [subject] };
  const data = projectAttendanceData({ features: { attendance: true }, occurrences: [occurrenceRow], token: "PRIVATE_TOKEN" }, query); assert.ok(data); assert.doesNotMatch(JSON.stringify(data), /PRIVATE_/); assert.equal(data.occurrences[0].subjects[0].response?.arrival_difference_minutes, null);
  const authorized = projectAttendanceData({ features: { attendance: true }, occurrences: [{ ...occurrenceRow, subjects: [{ ...subject, capabilities: { view_private_notes: true } }] }] }, query); assert.equal(authorized?.occurrences[0].subjects[0].response?.note, "PRIVATE_NOTE");
});
test("attendance history discards snapshots, notes, responder contact and Auth metadata", () => {
  const data = projectAttendanceData({ features: {}, occurrences: [], history: [{ id: shift, response_id: requestId, event_id: event, person_id: actor, occurrence_key: occurrence, subject_kind: "participant", status: "attending", version: 2, change_kind: "response", created_at: "2026-10-02T18:00:00Z", reason: "PRIVATE_REASON", note: "PRIVATE_NOTE", actor_auth_user_id: "PRIVATE_AUTH", snapshot: { email: "PRIVATE_EMAIL" } }] }, parseAttendanceQuery({ org: actor })!); assert.ok(data); assert.equal(data.history.length, 1); assert.doesNotMatch(JSON.stringify(data), /PRIVATE_/);
});
test("volunteer signup, assignment, capacity and scope inputs reject injection", () => {
  assert.ok(parseVolunteerCommand({ operation: "assignment.signup", input: { shift_id: shift } })); assert.equal(parseVolunteerCommand({ operation: "assignment.signup", input: { shift_id: shift, person_id: actor } }), null);
  const command = { operation: "shift.upsert", input: { organization_id: actor, role_id: event, title: "Controlled concessions", scope_type: "team", scope_id: participant, start_at: "2026-10-03T18:00:00Z", end_at: "2026-10-03T19:00:00Z", capacity: 2, status: "open", visibility: "members" } }; assert.ok(parseVolunteerCommand(command));
  for (const fields of [{ capacity: 0 }, { capacity: 1.5 }, { capacity: 10001 }, { scope_type: "descendants" }, { end_at: "2026-10-03T17:00:00Z" }, { occurrence_key: occurrence }, { override_capacity: true }, { reminder_minutes_before: 10081 }]) assert.equal(parseVolunteerCommand({ ...command, input: { ...command.input, ...fields } }), null);
  assert.ok(parseVolunteerCommand({ operation: "assignment.cancel", input: { assignment_id: shift, expected_version: 1 } })); assert.equal(parseVolunteerCommand({ operation: "assignment.cancel", input: { assignment_id: shift, expected_version: 0 } }), null);
});
test("volunteer announcement and reminder operations remain bounded within existing providers", () => {
  assert.ok(parseVolunteerCommand({ operation: "shift.announce", input: { shift_id: shift, title: "Setup", body: "Controlled announcement" } })); assert.equal(parseVolunteerCommand({ operation: "shift.announce", input: { shift_id: shift, title: "Setup", body: "x".repeat(4001), recipient_ids: [actor] } }), null);
  assert.ok(parseVolunteerCommand({ operation: "reminders.prepare", input: { organization_id: actor, window_start: "2026-10-02T18:00:00Z", window_end: "2026-10-03T18:00:00Z" } })); assert.equal(parseVolunteerCommand({ operation: "reminders.prepare", input: { organization_id: actor, window_start: "2026-10-02T18:00:00Z", window_end: "2026-10-10T18:00:00Z" } }), null);
});
test("volunteer projections omit another volunteer's identity list without management capability", () => {
  const row = { id: shift, role_id: event, scope_id: participant, scope_type: "team", label: "Controlled shift", start_at: "2026-10-03T18:00:00Z", end_at: "2026-10-03T19:00:00Z", capacity: 2, filled: 1, unfilled: 1, status: "open", visibility: "members", assignments: [{ id: requestId, person_id: actor, label: "PRIVATE_VOLUNTEER", status: "active" }], raw_email: "PRIVATE_CONTACT" };
  const data = projectVolunteerData({ features: { volunteers: true }, shifts: [row], detail: row, token: "PRIVATE_TOKEN" }); assert.ok(data); assert.doesNotMatch(JSON.stringify(data), /PRIVATE_/); assert.equal(data.detail?.assignments.length, 0);
});
test("bounded volunteer targets retain a selected scope beyond the default hundred choices", () => {
  const targets = Array.from({ length: 101 }, (_, index) => ({ scope_type: "team", scope_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`, label: `Controlled team ${index + 1}` }));
  const project = (options: typeof targets) => projectVolunteerData({ features: { volunteers: true }, shifts: [], targets: options, options_limited: true });
  const data = project(targets); assert.ok(data); assert.equal(data.targets.length, 101); assert.equal(data.targets.at(-1)?.scope_id, targets.at(-1)?.scope_id); assert.equal(data.options_limited, true);
  assert.equal(project([...targets, targets[0]])?.targets.length, 0);
});
test("volunteer detail preserves valid long locations without accepting oversized content", () => {
  const row = { id: shift, role_id: event, scope_id: participant, scope_type: "team", label: "Controlled shift", start_at: "2026-10-03T18:00:00Z", end_at: "2026-10-03T19:00:00Z", capacity: 2, filled: 1, unfilled: 1, status: "open", visibility: "members" };
  const project = (location: string) => projectVolunteerData({ features: { volunteers: true }, shifts: [row], detail: { ...row, location } });
  assert.equal(project("x".repeat(300))?.detail?.location, "x".repeat(300));
  assert.equal(project("x".repeat(301))?.detail?.location, null);
  assert.equal(project("Controlled location")?.shifts[0].location, null);
});
test("same-origin request and current nonanonymous identity gate all coordination RPCs", async () => {
  const m = mock(); assert.equal((await performCoordinationMutation(request(response, { origin: "https://attacker.invalid" }), m.client, origin, "attendance", parseAttendanceCommand)).status, 403); assert.equal(m.calls.length, 0);
  m.client.auth.getUser = async () => ({ data: { user: { id: event } }, error: null }); assert.equal((await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand)).status, 401); assert.equal(m.calls.length, 0);
  m.client.auth.getUser = async () => ({ data: { user: { id: actor, is_anonymous: true } }, error: null }); assert.equal((await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand)).status, 401);
});
test("retries preserve request ID and reverify caller on every attempt", async () => {
  const m = mock(); for (let attempt = 0; attempt < 2; attempt++) assert.equal((await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand)).status, 200);
  assert.equal(m.verifications(), 2); assert.equal(m.calls.length, 2); assert.deepEqual(m.calls[0], m.calls[1]);
});
test("coordination result echo binds operation and request while stripping sensitive details", async () => {
  const m = mock(), result = await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand); assert.equal(result.status, 200); assert.doesNotMatch(JSON.stringify(result), /PRIVATE_/);
  for (const data of [{ request_id: shift, operation: "response.set", resource_id: event, version: 1 }, { request_id: requestId, operation: "checkin.set", resource_id: event, version: 1 }]) { m.client.rpc = async () => ({ data, error: null }); assert.equal((await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand)).status, 503); }
  m.client.rpc = async () => ({ data: null, error: { code: "PT409", detail: "PRIVATE_SQL" } } as unknown as { data: null; error: { code: string } }); const conflict = await performCoordinationMutation(request(), m.client, origin, "attendance", parseAttendanceCommand); assert.equal(conflict.status, 409); assert.doesNotMatch(JSON.stringify(conflict), /PRIVATE_/);
});
test("malformed and oversized streamed requests never reach coordination RPC", async () => {
  const m = mock(); for (const req of [request(response, { "content-length": "24001" }), request(response, { "content-type": "text/plain" }), request(response, { "content-type": "application/jsonp" }), request(response, {}, "{"), request({ ...response, input: { ...response.input, note: "x".repeat(25000) } })]) assert.equal((await performCoordinationMutation(req, m.client, origin, "attendance", parseAttendanceCommand)).status, 422); assert.equal(m.calls.length, 0);
});
test("volunteer mutations use the volunteer RPC and reauthorize cancellation rather than raw client writes", async () => {
  const m = mock(); assert.equal((await performCoordinationMutation(request({ operation: "assignment.cancel", input: { assignment_id: shift, expected_version: 1 } }), m.client, origin, "volunteers", parseVolunteerCommand)).status, 200); assert.match(JSON.stringify(m.calls[0]), /boss_volunteers_mutate/);
  m.client.rpc = async () => ({ data: null, error: { code: "PT403" } }); assert.equal((await performCoordinationMutation(request({ operation: "assignment.signup", input: { shift_id: shift } }), m.client, origin, "volunteers", parseVolunteerCommand)).status, 403);
});
