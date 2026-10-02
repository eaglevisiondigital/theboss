import assert from "node:assert/strict";
import test, { mock } from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { AttendanceConsole, AttendanceCard } from "../src/components/attendance/console";
import { VolunteerConsole } from "../src/components/volunteers/console";
import { CoordinationHub } from "../src/components/coordination/hub";
import { parseAttendanceQuery, projectAttendanceData } from "../src/lib/attendance/input";
import { parseVolunteerQuery, projectVolunteerData } from "../src/lib/volunteers/input";
import type { AttendanceData } from "../src/lib/attendance/contracts";
import type { VolunteerData } from "../src/lib/volunteers/contracts";
import { guardianFlags, editFields } from "../src/components/admin/fields";
import { MutationForm } from "../src/components/admin/mutation-form";
const org = "00000000-0000-4000-8000-000000000001", event = "00000000-0000-4000-8000-000000000002", person = "00000000-0000-4000-8000-000000000003", participant = "00000000-0000-4000-8000-000000000004", shift = "00000000-0000-4000-8000-000000000005", role = "00000000-0000-4000-8000-000000000006", team = "00000000-0000-4000-8000-000000000007", assignment = "00000000-0000-4000-8000-000000000008";
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "coordination-ui-test" };
test.beforeEach(() => mock.timers.enable({ apis: ["Date"], now: new Date("2026-10-02T12:00:00Z") }));
test.afterEach(() => mock.timers.reset());
const attendanceQuery = parseAttendanceQuery({ org, from: "2026-10-02", to: "2026-10-09" })!, volunteerQuery = parseVolunteerQuery({ org, from: "2026-10-02", to: "2026-10-09" })!;
function render(node: ReturnType<typeof createElement>) { return renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, node)); }
const occurrenceRow = { event_id: event, organization_id: org, title: "Controlled Falcons practice", occurrence_key: "2026-10-03T18:00:00", start_at: "2026-10-03T23:00:00Z", end_at: "2026-10-04T00:00:00Z", timezone: "America/Chicago", status: "scheduled", rsvp_mode: "required", settings: { deadline_policy: "lock", change_policy: "needs_reconfirmation", response_deadline_at: null, deadline_offset_minutes: 2880, effective_deadline_at: "2026-10-01T23:00:00Z", version: 1 }, summary: { total: 2, attending: 1, pending: 1 }, capabilities: {}, subjects: [{ person_id: person, participant_id: participant, subject_kind: "participant", display_name: "Controlled Child1", capabilities: { respond: true, view_private_notes: true }, response: null }] };
function attendance(overrides: Record<string, unknown> = {}): AttendanceData { const data = projectAttendanceData({ organization_id: org, organizations: [{ id: org, label: "Controlled club" }], features: { attendance: true, rsvp: true, guardian_rsvp: true, checkin: false }, children: [{ person_id: person, participant_id: participant, display_name: "Controlled Child1" }], occurrences: [occurrenceRow], ...overrides }, attendanceQuery); assert.ok(data); return data; }
const shiftRow = { id: shift, label: "Controlled concessions", organization_id: org, role_id: role, role_label: "Concessions", scope_type: "team", scope_id: team, start_at: "2026-10-03T23:00:00Z", end_at: "2026-10-04T00:00:00Z", capacity: 2, filled: 1, unfilled: 1, status: "open", visibility: "members", version: 1, can_signup: true };
function volunteers(overrides: Record<string, unknown> = {}): VolunteerData { const data = projectVolunteerData({ organizationId: org, features: { volunteers: true, self_signup: true }, shifts: [shiftRow], roles: [{ id: role, label: "Concessions", status: "active", version: 1 }], ...overrides }); assert.ok(data); return data; }
test("guardian RSVP controls follow current subject capability and show child status", () => {
  const html = render(createElement(AttendanceConsole, { data: attendance(), query: attendanceQuery })); assert.match(html, /Respond for Controlled Child1/); assert.match(html, /Save response/); assert.match(html, /Whole family/); assert.match(html, /Household membership alone does not authorize/); assert.doesNotMatch(html, /Save check-in|Override a passed deadline|Save attendance configuration/);
  const revoked = render(createElement(AttendanceConsole, { data: attendance({ occurrences: [{ ...occurrenceRow, subjects: [{ ...occurrenceRow.subjects[0], capabilities: {} }] }] }), query: attendanceQuery })); assert.doesNotMatch(revoked, /Save response|Private reason/);
});
test("new guardian attendance checkbox defaults off and old capability flags do not check it", () => {
  const field = guardianFlags.find(field => field.name === "can_respond_attendance"); assert.ok(field); assert.equal(field.value, false);
  const html = render(createElement(MutationForm, { title: "Controlled guardian", operation: "guardian.update", initialInput: { id: person }, fields: editFields(guardianFlags, { id: person, label: "Controlled guardian", fields: { can_register: true, can_manage_payments: true } }) }));
  const checkbox = html.match(/<input[^>]*name="can_respond_attendance"[^>]*>/)?.[0]; assert.ok(checkbox); assert.doesNotMatch(checkbox, /checked/); assert.match(html, /Attendance response capability/);
});
test("disabled RSVP and canceled occurrences do not advertise response actions", () => {
  for (const data of [attendance({ features: { attendance: true, rsvp: false } }), attendance({ occurrences: [{ ...occurrenceRow, status: "canceled" }] })]) { const html = render(createElement(AttendanceConsole, { data, query: attendanceQuery })); assert.doesNotMatch(html, /Save response/); }
  const disabled = render(createElement(AttendanceConsole, { data: attendance({ features: {}, occurrences: [] }), query: attendanceQuery })); assert.match(disabled, /Attendance is not enabled/); assert.doesNotMatch(disabled, /Save response|Team attendance|Response required/);
});
test("staff deadline authority does not advertise responses on completed, postponed or ended events", () => {
  const row = { ...occurrenceRow, capabilities: { manage: true }, subjects: [{ ...occurrenceRow.subjects[0], capabilities: { manage: true, checkin: true } }] };
  for (const occurrence of [{ ...row, status: "completed" }, { ...row, status: "postponed" }, { ...row, start_at: "2000-10-03T23:00:00Z", end_at: "2000-10-04T00:00:00Z" }]) {
    const data = attendance({ occurrences: [occurrence], features: { attendance: true, rsvp: true, checkin: true } });
    const html = render(createElement(AttendanceConsole, { data, query: attendanceQuery })); assert.doesNotMatch(html, /Save response|Override a passed deadline/);
    const hub = render(createElement(CoordinationHub, { family: true, attendance: data, volunteers: volunteers({ commitments: [] }), attendanceQuery, volunteerQuery })); assert.match(hub, /No outstanding required responses/);
    if (occurrence.status === "completed") assert.match(html, /Save check-in/);
    if (occurrence.status === "postponed") assert.doesNotMatch(html, /Save check-in/);
  }
});
test("staff attendance summary includes unknown responses and total without exposing private details", () => {
  const data = attendance({ occurrences: [{ ...occurrenceRow, summary: { ...occurrenceRow.summary, unknown: 3, total: 5 }, capabilities: { view_summary: true } }] });
  const html = render(createElement(AttendanceConsole, { data, query: { ...attendanceQuery, view: "staff" } }));
  assert.match(html, /<dt>Unknown<\/dt><dd>3<\/dd>/); assert.match(html, /<dt>Total<\/dt><dd>5<\/dd>/); assert.doesNotMatch(html, /PRIVATE_/);
});
test("global navigation availability does not enable actions in a disabled selected organization", () => {
  const data = attendance({ navigation_available: true, options_limited: true, features: {}, occurrences: [] }); assert.equal(data.navigation_available, true); const html = render(createElement(AttendanceConsole, { data, query: attendanceQuery })); assert.match(html, /Attendance is not enabled/); assert.match(html, /Organization choices are limited/); assert.doesNotMatch(html, /Save response|Save check-in/);
  const volunteerData = volunteers({ navigation_available: true, features: {}, shifts: [] }); assert.equal(volunteerData.navigation_available, true); const volunteerHtml = render(createElement(VolunteerConsole, { data: volunteerData, query: volunteerQuery })); assert.match(volunteerHtml, /Volunteer signup is not enabled/); assert.doesNotMatch(volunteerHtml, /Sign up for shift|Create volunteer shift/);
});
test("private absence notes remain omitted for ordinary view-only staff", () => {
  const data = attendance({ occurrences: [{ ...occurrenceRow, capabilities: { view_summary: true }, subjects: [{ ...occurrenceRow.subjects[0], capabilities: {}, response: { id: assignment, status: "not_attending", version: 1, reason: "PRIVATE_REASON", note: "PRIVATE_NOTE" } }] }] }); const html = render(createElement(AttendanceConsole, { data, query: { ...attendanceQuery, view: "staff" } })); assert.match(html, /Attendance summary/); assert.match(html, /Pending \/ no response/); assert.doesNotMatch(html, /PRIVATE_|Private response details|Save response/);
});
test("reconfirmation and late markers stay visible without exposing private detail", () => {
  const data = attendance({ occurrences: [{ ...occurrenceRow, subjects: [{ ...occurrenceRow.subjects[0], response: { id: assignment, status: "attending", version: 2, needs_reconfirmation: true, is_late: true } }] }] }); const html = render(createElement(AttendanceConsole, { data, query: attendanceQuery })); assert.match(html, /Please reconfirm after the event change/); assert.match(html, /Reconfirm response/); assert.match(html, /Late response/);
});
test("event settings keep recurring offset separate from fixed deadline while showing effective deadline", () => {
  const data = attendance({ occurrences: [{ ...occurrenceRow, capabilities: { manage: true, view_summary: true } }] }); const html = render(createElement(AttendanceConsole, { data, query: { ...attendanceQuery, view: "staff" } })); assert.match(html, /Respond by Oct 1, 2026, 6:00 PM/); assert.match(html, /name="deadline_offset_minutes"[^>]*value="2880"/); assert.match(html, /name="response_deadline_at"[^>]*value=""/); assert.match(html, /Require reconfirmation/); assert.match(html, /Attendance response history/);
});
test("check-in is a separately feature and permission gated foundation", () => {
  const row = { ...occurrenceRow, subjects: [{ ...occurrenceRow.subjects[0], capabilities: { checkin: true } }] }; const disabled = render(createElement(AttendanceConsole, { data: attendance({ occurrences: [row] }), query: attendanceQuery })); assert.doesNotMatch(disabled, /Save check-in/); const enabled = render(createElement(AttendanceConsole, { data: attendance({ occurrences: [row], features: { attendance: true, checkin: true } }), query: attendanceQuery })); assert.match(enabled, /Save check-in/); assert.match(enabled, /value="excused"/); assert.doesNotMatch(enabled, /Save response/);
});
test("volunteer full and closed shifts hide enrollment while own cancellation remains available", () => {
  const open = render(createElement(VolunteerConsole, { data: volunteers(), query: volunteerQuery })); assert.match(open, /Sign up for shift/); const disabledSignup = render(createElement(VolunteerConsole, { data: volunteers({ features: { volunteers: true, self_signup: false } }), query: volunteerQuery })); assert.doesNotMatch(disabledSignup, /Sign up for shift/);
  for (const row of [{ ...shiftRow, filled: 2, unfilled: 0 }, { ...shiftRow, status: "closed" }, { ...shiftRow, can_signup: false }]) assert.doesNotMatch(render(createElement(VolunteerConsole, { data: volunteers({ shifts: [row] }), query: volunteerQuery })), /Sign up for shift/);
  const commitment = { ...shiftRow, can_signup: false, my_assignment: { id: assignment, status: "active", version: 2, can_cancel: true } }; const own = render(createElement(VolunteerConsole, { data: volunteers({ features: {}, shifts: [], commitments: [commitment] }), query: { ...volunteerQuery, view: "family" } })); assert.match(own, /Cancel my signup/); assert.doesNotMatch(own, /Sign up for shift|Create volunteer shift/);
});
test("coach shift editor contains exact manageable targets without implicit organization scope", () => {
  const data = volunteers({ operations: ["shift.upsert"], targets: [{ scope_type: "team", scope_id: team, label: "Controlled Falcons" }] }); const html = render(createElement(VolunteerConsole, { data, query: { ...volunteerQuery, view: "manage" } })); assert.match(html, /Create volunteer shift/); assert.match(html, new RegExp(`value="team:${team}"`)); assert.doesNotMatch(html, /value="organization:|Volunteer role definitions|Save volunteer configuration|Assign an eligible volunteer/);
});
test("bounded volunteer scope notice names the filters that refine manageable choices", () => {
  const html = render(createElement(VolunteerConsole, { data: volunteers({ options_limited: true }), query: volunteerQuery }));
  assert.match(html, /Available choices are limited/); assert.match(html, /organization, team or unit/);
});
test("volunteer staff assignment and announcement controls require distinct current capabilities", () => {
  const row = { ...shiftRow, can_signup: false, can_manage: true, can_assign: false, can_announce: false, instructions: "Controlled setup instructions" }; const denied = render(createElement(VolunteerConsole, { data: volunteers({ detail: row, candidates: [{ id: person, label: "Controlled parent" }] }), query: volunteerQuery })); assert.match(denied, /Edit volunteer shift/); assert.match(denied, /Controlled setup instructions/); assert.doesNotMatch(denied, /Assign an eligible volunteer|Send volunteer announcement/);
  const allowed = render(createElement(VolunteerConsole, { data: volunteers({ detail: { ...row, can_assign: true, can_announce: true }, candidates: [{ id: person, label: "Controlled parent" }] }), query: volunteerQuery })); assert.match(allowed, /Assign an eligible volunteer/); assert.match(allowed, /Send volunteer announcement/);
});
test("Family Hub uses child-only RSVP filters and actor-owned volunteer commitments", () => {
  const commitments = [{ ...shiftRow, my_assignment: { id: assignment, status: "active", version: 1, can_cancel: true } }]; const html = render(createElement(CoordinationHub, { family: true, attendance: attendance(), volunteers: volunteers({ commitments }), attendanceQuery, volunteerQuery })); assert.match(html, /Family Hub/); assert.match(html, /name="child"/); assert.match(html, /Controlled Child1/); assert.match(html, /Responses needed/); assert.match(html, /My volunteer commitments/); assert.match(html, /Switching a child does not grant access/); assert.match(html, /Cancel my signup/);
});
test("Family Hub preserves the actual selected domain organizations from a context-free URL", () => {
  const volunteerOrg = "00000000-0000-4000-8000-000000000009";
  const html = render(createElement(CoordinationHub, { family: true, attendance: attendance(), volunteers: volunteers({ organizationId: volunteerOrg }), attendanceQuery: { ...attendanceQuery, organization_id: undefined }, volunteerQuery: { ...volunteerQuery, organization_id: undefined } }));
  assert.match(html, new RegExp(`name="org" value="${org}"`));
  const hrefs = [...html.matchAll(/href="([^"]+)"/g)].map(match => match[1]);
  assert.ok(hrefs.some(href => href.startsWith("/app/attendance?") && href.includes(`org=${org}`)));
  assert.ok(hrefs.some(href => href.startsWith("/app/volunteers?") && href.includes(`org=${volunteerOrg}`)));
});
test("coach dashboard compact next event shows counts and exact occurrence link without absence notes", () => {
  const data = attendance({ occurrences: [{ ...occurrenceRow, capabilities: { view_summary: true, manage: true } }] }); const html = render(createElement(AttendanceCard, { occurrence: data.occurrences[0], compact: true })); assert.match(html, /Attendance summary/); assert.match(html, /view=staff/); assert.match(html, /occurrence=2026-10-03T18%3A00%3A00/); assert.doesNotMatch(html, /Private reason|Save response|Save check-in/);
});
test("untrusted event, child and shift labels render as text", () => {
  const html = render(createElement(AttendanceConsole, { data: attendance({ occurrences: [{ ...occurrenceRow, title: '<img src=x onerror="unsafe()">' }] }), query: attendanceQuery })); assert.match(html, /&lt;img/); assert.doesNotMatch(html, /<img/);
  const volunteer = render(createElement(VolunteerConsole, { data: volunteers({ shifts: [{ ...shiftRow, label: '<script>unsafe()</script>' }] }), query: volunteerQuery })); assert.match(volunteer, /&lt;script/); assert.doesNotMatch(volunteer, /<script/);
});
