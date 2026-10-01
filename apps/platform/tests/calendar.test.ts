import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { SearchParamsContext } from "next/dist/shared/lib/hooks-client-context.shared-runtime";
import { EventEditor } from "../src/components/calendar/event-editor";
import { CalendarConsole } from "../src/components/calendar/console";
import { defaultFeatures, emptyCalendar, type CalendarData, type EventInput, type Occurrence } from "../src/lib/calendar/contracts";
import { parseCalendarCommand, projectCalendarData, projectCalendarMutation, projectCalendarPreview, readCalendarInput } from "../src/lib/calendar/input";
import { performCalendarMutation, type CalendarMutationClient } from "../src/lib/calendar/mutation";
import { addDays, displayDays, groupOccurrences, localDateTime, localToInstant, occurrenceOnDate, parseSelection } from "../src/lib/calendar/temporal";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";

const id = "00000000-0000-4000-8000-000000000001";
const other = "00000000-0000-4000-8000-000000000002";
const third = "00000000-0000-4000-8000-000000000003";
const origin = "https://calendar.boss.invalid";
const input: EventInput = { organization_id: id,title: "Practice",description: null,event_type_key: "practice",start_at: "2026-10-15T21:00:00Z",end_at: "2026-10-15T22:00:00Z",timezone: "America/Chicago",all_day: false,arrival_at: null,status: "scheduled",visibility: "member",publication_state: "unpublished",venue_id: null,resource_id: null,instructions: null,rsvp_mode: "not_required",audience: ["team"],recurrence: null,targets: [{ target_type: "team",target_id: other }],reminders: [],game: null,override_conflicts: false };
const command = { operation: "event.create" as const,input };
const envelope = { command,request_id: third };
function request(value: unknown = envelope, headers: Record<string,string> = {}) { return new Request(`${origin}/app/calendar/mutate`,{ method: "POST",headers: { "content-type": "application/json",host: "calendar.boss.invalid",origin,"sec-fetch-site": "same-origin",...headers },body: JSON.stringify(value) }); }
function mock() {
  let calls = 0;
  const client: CalendarMutationClient = { auth: { getClaims: async () => ({ data: { claims: { sub: id,iss: `${BOSS_SUPABASE_URL}/auth/v1`,role: "authenticated",exp: Math.floor(Date.now()/1000)+120 } },error: null }),getUser: async () => ({ data: { user: { id,is_anonymous: false } },error: null }) },rpc: async name => { calls++; return { data: name === "boss_calendar_preview" ? { conflicts: [],has_conflicts: false,can_override: false } : { request_id: third,resource_type: "event",resource_id: other,version: 1,sql_detail: "PRIVATE_SQL" },error: null }; } };
  return { client,calls: () => calls };
}
function occurrence(overrides: Partial<Occurrence> = {}): Occurrence { return { ...input,event_id: other,occurrence_key: "2026-10-15T16:00:00",targets: [{ target_type: "team",target_id: other,label: "Team A" }],is_exception: false,exception_id: null,version: 2,series_start_at: input.start_at,series_end_at: input.end_at,series_arrival_at: null,series_title: input.title,series_instructions: null,series_status: "scheduled",capabilities: { manage: true,publish: true,override_conflict: false },...overrides }; }
function fixture(): CalendarData {
  const query = parseSelection({ date: "2026-10-15",org: id }).query;
  return { ...emptyCalendar(query),organizations: [{ id,name: "Controlled club",timezone: "America/Chicago" }],teams: [{ id: other,organization_id: id,parent_unit_id: null,season_id: null,name: "Team A" },{ id: third,organization_id: id,parent_unit_id: null,season_id: null,name: "Sibling team" }],event_types: [{ key: "practice",name: "Practice" }],features: defaultFeatures,capabilities: { create: true,manage_venues: false,configure: false,publish: true,override_conflict: false,create_targets: [{ target_type: "team",target_id: other,label: "Team A" }] },occurrences: [occurrence()] };
}
const router: AppRouterInstance = { back() {},forward() {},refresh() {},push() {},replace() {},prefetch() {},bfcacheId: "controlled-test" };
function render(node: ReturnType<typeof createElement>, params = "") { return renderToStaticMarkup(createElement(AppRouterContext.Provider,{ value: router },createElement(SearchParamsContext.Provider,{ value: new URLSearchParams(params) },node))); }

test("calendar wall time uses selected IANA zone and later DST fold", () => {
  assert.equal(localToInstant("2026-11-01T01:30","America/Chicago"),"2026-11-01T07:30:00.000Z");
  assert.equal(localToInstant("2026-03-08T02:30","America/Chicago"),null);
  assert.equal(localToInstant("2026-10-15T16:00","America/Chicago"),"2026-10-15T21:00:00.000Z");
  assert.equal(localToInstant("2026-10-15T16:00","Asia/Kathmandu"),"2026-10-15T10:15:00.000Z");
  assert.equal(localToInstant("2026-02-30T16:00","UTC"),null);
  assert.equal(localToInstant("2026-10-15T25:00","UTC"),null);
  assert.equal(localToInstant("2026-10-15T16:00","Invented/Zone"),null);
});
test("calendar defaults to personal agenda and custom range renders the requested dates", () => {
  const selection = parseSelection({},new Date("2026-10-01T12:00:00Z"));
  assert.equal(selection.display,"agenda"); assert.equal(selection.query.view,"personal");
  assert.equal(Date.parse(selection.query.to)-Date.parse(selection.query.from),14*86_400_000);
  const custom = parseSelection({ date: "2026-10-01",view: "month",from: "2026-10-15",to: "2026-10-17",tz: "America/Chicago" });
  assert.equal(custom.display,"agenda"); assert.equal(custom.invalid,false);
  assert.equal(localDateTime(custom.query.from,custom.timezone),"2026-10-15T00:00:00");
  assert.equal(localDateTime(custom.query.to,custom.timezone),"2026-10-18T00:00:00");
  const html = render(createElement(CalendarConsole,{ data: fixture(),selection: custom }),"date=2026-10-01&view=month&from=2026-10-15&to=2026-10-17&tz=America%2FChicago");
  assert.match(html,/Practice/); assert.match(html,/Thu, Oct 15/); assert.doesNotMatch(html,/Thu, Oct 1<\/h3>/);
});
test("range and identifiers are bounded before database reads", () => {
  for (const params of [{ from: "2026-01-01",to: "2026-12-31" },{ org: "forged" },{ child: "forged" },{ from: "2026-02-30" },{ date: ["2026-10-01", "2026-10-02"] },{ tz: "Invented/Zone" },{ scope: "global" }]) assert.equal(parseSelection(params).invalid,true);
  assert.equal(parseSelection({ from: "2026-10-15",to: "2026-10-14" }).invalid,true);
});
test("month and week grids include Monday boundaries across year changes", () => {
  assert.deepEqual(displayDays("2027-01-01","week"),["2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"]);
  assert.equal(displayDays("2027-01-01","month").length,42);
  assert.equal(addDays("2026-12-31",1),"2027-01-01");
});
test("multi-day and all-day display uses exclusive ends across DST", () => {
  const event = occurrence({ all_day: true,start_at: "2026-10-31T05:00:00Z",end_at: "2026-11-02T06:00:00Z" });
  assert.equal(occurrenceOnDate(event,"2026-10-30","America/Chicago"),false);
  assert.equal(occurrenceOnDate(event,"2026-10-31","America/Chicago"),true);
  assert.equal(occurrenceOnDate(event,"2026-11-01","America/Chicago"),true);
  assert.equal(occurrenceOnDate(event,"2026-11-02","America/Chicago"),false);
  const grouped = groupOccurrences([event],["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"],"America/Chicago");
  assert.deepEqual(Array.from(grouped,([day,events]) => [day,events.length]),[["2026-10-30",0], ["2026-10-31",1], ["2026-11-01",1], ["2026-11-02",0]]);
});
test("finite command input rejects forged capability, unknown fields and unsupported modules", () => {
  assert.ok(parseCalendarCommand(command));
  for (const value of [{ ...command,actor: third },{ ...command,input: { ...input,is_admin: true } },{ operation: "registration.create",input },{ ...command,input: { ...input,targets: [{ target_type: "descendant",target_id: other }] } },{ ...command,input: { ...input,targets: [input.targets[0],input.targets[0]] } },{ ...command,input: { ...input,audience: ["players"] } },{ ...command,input: { ...input,end_at: input.start_at } },{ ...command,input: { ...input,start_at: "2026-02-30T16:00:00Z" } },{ ...command,input: { ...input,description: "a".repeat(4001) } },{ operation: "calendar.configure",input: { organization_id: id,features: { attendance: true } } }]) assert.equal(parseCalendarCommand(value),null);
});
test("recurrence requires finite end, unique ISO weekdays and bounded horizon", () => {
  const good = { ...command,input: { ...input,recurrence: { frequency: "weekly",interval: 1,weekdays: [1,3],count: 20 } } }; assert.ok(parseCalendarCommand(good));
  for (const recurrence of [{ frequency: "daily",interval: 1 },{ frequency: "daily",interval: 1,count: 1001 },{ frequency: "weekly",interval: 1,weekdays: [0],count: 10 },{ frequency: "weekly",interval: 1,weekdays: [1,1],count: 10 },{ frequency: "monthly",interval: 1,weekdays: [1],count: 10 },{ frequency: "daily",interval: 53,count: 10 },{ frequency: "daily",interval: 1,count: 10,until: "2027-01-01" },{ frequency: "daily",interval: 1,until: "2035-01-01" }]) assert.equal(parseCalendarCommand({ ...command,input: { ...input,recurrence } }),null);
});
test("single occurrence keeps original local key and canonical expected version", () => {
  const exception = { operation: "event.exception",input: { event_id: other,expected_version: 2,occurrence_key: "2026-10-15T16:00:00",override_start_at: "2026-10-16T21:00:00Z",override_end_at: "2026-10-16T22:00:00Z",status: "postponed" } };
  assert.ok(parseCalendarCommand(exception));
  assert.equal(parseCalendarCommand({ ...exception,input: { ...exception.input,occurrence_key: "2026-10-15T16:00:00Z" } }),null);
  assert.equal(parseCalendarCommand({ ...exception,input: { ...exception.input,expected_version: 0 } }),null);
  assert.equal(parseCalendarCommand({ ...exception,input: { ...exception.input,override_end_at: undefined } }),null);
});
test("recurrence last date is compared with local anchor and exact five-year horizon", () => {
  const lateLocal = { ...input,start_at: "2026-10-16T04:00:00Z",end_at: "2026-10-16T04:30:00Z",recurrence: { frequency: "daily",interval: 1,until: "2026-10-15" } };
  assert.ok(parseCalendarCommand({ operation: "event.create",input: lateLocal }));
  assert.equal(parseCalendarCommand({ operation: "event.create",input: { ...lateLocal,recurrence: { ...lateLocal.recurrence,until: "2031-10-16" } } }),null);
});
test("reminder settings validate enable and audience without providing delivery", () => {
  assert.ok(parseCalendarCommand({ ...command,input: { ...input,reminders: [{ minutes_before: 60,audience: ["guardians"],enabled: false }] } }));
  for (const reminder of [{ minutes_before: -1,audience: ["guardians"],enabled: true },{ minutes_before: 10081,audience: ["guardians"],enabled: true },{ minutes_before: 60,audience: ["public"],enabled: true },{ minutes_before: 60,audience: ["guardians"],enabled: "true" },{ minutes_before: 60,audience: ["guardians"],enabled: true,delivery: "sms" }]) assert.equal(parseCalendarCommand({ ...command,input: { ...input,reminders: [reminder] } }),null);
  const reminders = Array.from({ length: 8 },(_,index) => ({ minutes_before: index*60,audience: ["guardians"],enabled: true }));
  assert.ok(parseCalendarCommand({ ...command,input: { ...input,reminders } }));
  assert.equal(parseCalendarCommand({ ...command,input: { ...input,reminders: [...reminders,{ minutes_before: 600,audience: ["guardians"],enabled: true }] } }),null);
  const html = render(createElement(EventEditor,{ data: fixture(),date: "2026-10-15",occurrence: occurrence({ reminders }) }));
  assert.match(html,/name="reminder_offset_7"/); assert.doesNotMatch(html,/name="reminder_offset_8"|Add reminder/);
});
test("calendar POST and preview reject cross-origin before RPC or Auth", async () => {
  const m = mock(); let authCalls = 0; m.client.auth.getClaims = async () => { authCalls++; return { data: null,error: null }; };
  const malicious: Record<string,string>[] = [{ origin: "https://attacker.invalid" },{ "sec-fetch-site": "cross-site" },{ host: "attacker.invalid" },{ origin: "" }];
  for (const headers of malicious) assert.equal((await performCalendarMutation(request(envelope,headers),m.client,origin)).status,403);
  assert.equal(authCalls,0); assert.equal(m.calls(),0);
});
test("bounded bodies and preview shape reject hostile or ambiguous envelopes", async () => {
  assert.equal(await readCalendarInput(request(envelope,{ "content-length": "65537" })),null);
  assert.equal(await readCalendarInput(request(envelope,{ "content-type": "text/plain" })),null);
  assert.equal(await readCalendarInput(request({ ...envelope,padding: "x".repeat(65_536) })),null);
  assert.equal(await readCalendarInput(request({ command,actor: id }),true),null);
  assert.equal(await readCalendarInput(request({ command: { operation: "calendar.configure",input: { organization_id: id,features: { conflicts: false } } } }),true),null);
});
test("calendar requires verified and current Auth identities to agree", async () => {
  const m = mock(); m.client.auth.getUser = async () => ({ data: { user: { id: other } },error: null });
  assert.equal((await performCalendarMutation(request(),m.client,origin)).status,401);
  m.client.auth.getUser = async () => ({ data: { user: { id,is_anonymous: true } },error: null });
  assert.equal((await performCalendarMutation(request(),m.client,origin)).status,401);
  m.client.auth.getClaims = async () => ({ data: null,error: null });
  assert.equal((await performCalendarMutation(request(),m.client,origin)).status,401); assert.equal(m.calls(),0);
});
test("calendar results and conflict previews strip SQL, Auth and other unrequested fields", async () => {
  const m = mock(); const result = await performCalendarMutation(request(),m.client,origin);
  assert.deepEqual(result,{ status: 200,body: { ok: true,result: { request_id: third,resource_type: "event",resource_id: other,version: 1 } } });
  assert.doesNotMatch(JSON.stringify(result),/PRIVATE_SQL/);
  assert.equal(projectCalendarMutation({ request_id: third,resource_type: "auth.sessions",resource_id: id,version: 1 }),null);
  const projected = projectCalendarPreview({ conflicts: [{ kind: "team",event_id: null,title: "Busy",start_at: input.start_at,end_at: input.end_at,private_identity: "PRIVATE_PERSON" }],has_conflicts: true,can_override: false,token: "PRIVATE_AUTH" });
  assert.ok(projected); assert.doesNotMatch(JSON.stringify(projected),/PRIVATE_/);
  const read = projectCalendarData({ ...fixture(),auth: "PRIVATE_AUTH",occurrences: [{ ...occurrence(),before_values: "PRIVATE_AUDIT" }] });
  assert.ok(read); assert.doesNotMatch(JSON.stringify(read),/PRIVATE_/);
});
test("calendar database errors and thrown errors never return SQL details", async () => {
  const m = mock();
  for (const [code,status] of [["PT401",401], ["PT403",403], ["PT409",409], ["PT422",422], ["23503",503]] as const) { m.client.rpc = async () => ({ data: null,error: { code,message: "PRIVATE_SQL",details: "PRIVATE_STACK" } }); const result = await performCalendarMutation(request(),m.client,origin); assert.equal(result.status,status); assert.doesNotMatch(JSON.stringify(result),/PRIVATE_/); }
  m.client.rpc = async () => { throw new Error("PRIVATE_STACK"); }; assert.doesNotMatch(JSON.stringify(await performCalendarMutation(request(),m.client,origin)),/PRIVATE_/);
});
test("successful mutation must echo the exact idempotency request", async () => {
  const m = mock(); m.client.rpc = async () => ({ data: { request_id: id,resource_type: "event",resource_id: other,version: 1 },error: null });
  assert.equal((await performCalendarMutation(request(),m.client,origin)).status,503);
});
test("series editor retains canonical anchor, title and status from a canceled later exception", () => {
  const event = occurrence({ title: "Canceled later practice",status: "canceled",start_at: "2026-10-29T21:00:00Z",end_at: "2026-10-29T22:00:00Z",is_exception: true,recurrence: { frequency: "weekly",interval: 1,weekdays: [4],count: 6 },reminders: [{ minutes_before: 60,audience: ["coaches"],enabled: false }] });
  const html = render(createElement(EventEditor,{ data: fixture(),date: "2026-10-29",occurrence: event }));
  assert.match(html,/name="title"[^>]*value="Practice"/);
  assert.match(html,/value="scheduled" selected=""/);
  assert.match(html,/name="start"[^>]*value="2026-10-15T16:00:00"/);
  assert.match(html,/name="reminder_audience_0"[^>]*checked=""[^>]*value="coaches"|name="reminder_audience_0"[^>]*value="coaches"[^>]*checked=""/);
  assert.doesNotMatch(html,/name="reminder_enabled_0"[^>]*checked/);
});
test("creation only advertises exact authorized targets and no sibling scheduling", () => {
  const html = render(createElement(EventEditor,{ data: fixture(),date: "2026-10-15",organizationId: id }));
  assert.match(html,/Team A/); assert.doesNotMatch(html,/Sibling team/);
  assert.match(html,/Audience labels/); assert.match(html,/RSVP setting/); assert.match(html,/Reminder configuration/);
});
test("single all-day exception controls preserve all-day semantics without changing series flag", () => {
  const event = occurrence({ all_day: true,start_at: "2026-10-15T05:00:00Z",end_at: "2026-10-17T05:00:00Z",recurrence: { frequency: "weekly",interval: 1,count: 6 } });
  const html = render(createElement(EventEditor,{ data: fixture(),date: "2026-10-15",occurrence: event,single: true }));
  assert.doesNotMatch(html,/type="checkbox"[^>]*name="all_day"|name="all_day"[^>]*type="checkbox"/);
  assert.match(html,/name="end"[^>]*value="2026-10-16"/);
});
