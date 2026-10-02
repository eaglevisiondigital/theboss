import { isObject, uuidPattern } from "../admin/input";
import type { CalendarCommand, CalendarData, CalendarMutationResult, CalendarPreview } from "./contracts";
import { localDateTime, validDate, validTimezone } from "./temporal";

const statuses = ["draft", "scheduled", "confirmed", "canceled", "postponed", "completed", "archived"];
const visibilities = ["public", "authenticated", "member", "restricted", "private"];
const featureKeys = ["organization_calendar", "team_calendar", "recurrence", "public_schedules", "conflicts", "head_coach_management", "conflict_overrides", "attendance"];
const eventKeys = ["organization_id", "title", "description", "event_type_key", "start_at", "end_at", "timezone", "all_day", "arrival_at", "status", "visibility", "publication_state", "venue_id", "resource_id", "instructions", "rsvp_mode", "audience", "recurrence", "targets", "reminders", "game", "override_conflicts", "reset_exceptions"];
const operations: Record<string, readonly string[]> = {
  "event.create": eventKeys, "event.update": [...eventKeys, "event_id", "expected_version"],
  "event.exception": ["event_id", "expected_version", "occurrence_key", "override_start_at", "override_end_at", "override_arrival_at", "status", "title", "instructions", "override_conflicts"],
  "venue.create": ["organization_id", "name", "timezone", "address_line1", "address_line2", "city", "region", "postal_code", "country_code", "instructions", "status", "is_public"],
  "venue.update": ["organization_id", "name", "timezone", "address_line1", "address_line2", "city", "region", "postal_code", "country_code", "instructions", "status", "is_public", "venue_id", "expected_version"],
  "resource.create": ["organization_id", "venue_id", "name", "resource_type", "status", "is_public"],
  "resource.update": ["organization_id", "venue_id", "name", "resource_type", "status", "is_public", "resource_id", "expected_version"],
  "calendar.configure": ["organization_id", "features"],
};
const keys = (object: Record<string, unknown>, allowed: readonly string[]) => Object.keys(object).every(key => allowed.includes(key));
const text = (value: unknown, max = 4000): value is string => typeof value === "string" && value.length <= max && Array.from(value).every(character => { const code = character.charCodeAt(0); return code !== 127 && (code >= 32 || [9,10,13].includes(code)); });
const uuid = (value: unknown): value is string => typeof value === "string" && uuidPattern.test(value);
const instant = (value: unknown): value is string => typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+-]\d{2}:\d{2})$/.test(value) && Number.isFinite(Date.parse(value)) && validDate(value.slice(0,10));
const integer = (value: unknown, min: number, max: number): value is number => typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
const audienceLabels = ["organization", "unit", "team", "staff", "coaches", "guardians", "participants", "public"];
const labels = (value: unknown): value is string[] => Array.isArray(value) && value.length > 0 && value.length <= 7 && value.every(item => typeof item === "string" && audienceLabels.includes(item)) && new Set(value).size === value.length;
function validRecurrence(value: unknown, start?: string, timezone = "UTC") {
  if (value === null) return true;
  if (!isObject(value) || !keys(value, ["frequency", "interval", "weekdays", "count", "until"]) || !["daily", "weekly", "monthly"].includes(String(value.frequency)) || !integer(value.interval,1,52)) return false;
  if ((value.count === undefined) === (value.until === undefined)) return false;
  if (value.count !== undefined && !integer(value.count,1,1000)) return false;
  if (value.until !== undefined && (typeof value.until !== "string" || !validDate(value.until))) return false;
  if (typeof value.until === "string" && start) {
    if (!validTimezone(timezone) || !instant(start)) return false;
    const anchor = localDateTime(start,timezone).slice(0,10); const date = new Date(`${anchor}T12:00:00Z`);
    const year = date.getUTCFullYear()+5, month = date.getUTCMonth();
    const lastDay = Math.min(date.getUTCDate(),new Date(Date.UTC(year,month+1,0)).getUTCDate());
    const horizon = new Date(Date.UTC(year,month,lastDay,12)).toISOString().slice(0,10);
    if (value.until < anchor || value.until > horizon) return false;
  }
  if (value.weekdays !== undefined && (!Array.isArray(value.weekdays) || !value.weekdays.length || value.weekdays.length > 7 || !value.weekdays.every(day => integer(day,1,7)) || new Set(value.weekdays).size !== value.weekdays.length || value.frequency !== "weekly")) return false;
  return true;
}
function validTargets(value: unknown) {
  return Array.isArray(value) && value.length > 0 && value.length <= 100 && value.every(row => isObject(row) && keys(row, ["target_type", "target_id"]) && ["organization", "unit", "team"].includes(String(row.target_type)) && uuid(row.target_id)) && new Set(value.map(row => `${row.target_type}:${row.target_id}`)).size === value.length;
}
function validReminders(value: unknown) {
  return Array.isArray(value) && value.length <= 8 && value.every(row => isObject(row) && keys(row,["minutes_before", "audience", "enabled"]) && integer(row.minutes_before,0,10080) && labels(row.audience) && !row.audience.includes("public") && typeof row.enabled === "boolean");
}
function validGame(value: unknown) {
  return value === null || (isObject(value) && keys(value,["opponent_team_id", "external_opponent_name", "home_away", "game_status"]) && (value.opponent_team_id === null || uuid(value.opponent_team_id)) && (value.external_opponent_name === null || text(value.external_opponent_name,200)) && !(value.opponent_team_id && value.external_opponent_name) && ["home", "away", "neutral"].includes(String(value.home_away)) && ["scheduled", "postponed", "canceled", "completed"].includes(String(value.game_status)));
}
export function parseCalendarCommand(value: unknown): CalendarCommand | null {
  if (!isObject(value) || !keys(value,["operation", "input"]) || typeof value.operation !== "string" || !Object.hasOwn(operations,value.operation) || !isObject(value.input) || !keys(value.input,operations[value.operation])) return null;
  const input = value.input;
  for (const [key, field] of Object.entries(input)) {
    if (key.endsWith("_id")) { if (field === null && ["venue_id", "resource_id"].includes(key) && value.operation.startsWith("event.")) continue; if (!uuid(field)) return null; }
    else if (key === "expected_version") { if (!integer(field,1,2_147_483_647)) return null; }
    else if (["all_day", "is_public", "override_conflicts", "reset_exceptions"].includes(key)) { if (typeof field !== "boolean") return null; }
    else if (["start_at", "end_at", "arrival_at", "override_start_at", "override_end_at", "override_arrival_at"].includes(key)) { if (field === null && key.includes("arrival")) continue; if (!instant(field)) return null; }
    else if (key === "occurrence_key") { if (typeof field !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/.test(field) || !validDate(field.slice(0,10))) return null; }
    else if (key === "timezone") { if (typeof field !== "string" || !validTimezone(field)) return null; }
    else if (key === "audience") { if (!labels(field)) return null; }
    else if (key === "targets") { if (!validTargets(field)) return null; }
    else if (key === "reminders") { if (!validReminders(field)) return null; }
    else if (key === "recurrence") { if (!validRecurrence(field,typeof input.start_at === "string" ? input.start_at : undefined,typeof input.timezone === "string" ? input.timezone : "UTC")) return null; }
    else if (key === "game") { if (!validGame(field)) return null; }
    else if (key === "features") { if (!isObject(field) || !Object.keys(field).length || !keys(field,featureKeys) || !Object.values(field).every(item => typeof item === "boolean")) return null; }
    else if (field !== null && !text(field,["title", "name", "event_type_key", "resource_type"].includes(key) ? 200 : 4000)) return null;
  }
  if (input.status !== undefined && !(value.operation.startsWith("event.") ? statuses : ["active", "inactive"]).includes(String(input.status))) return null;
  if (value.operation === "event.exception" && ["draft", "archived"].includes(String(input.status))) return null;
  if (input.visibility !== undefined && !visibilities.includes(String(input.visibility))) return null;
  if (input.publication_state !== undefined && !["unpublished", "published"].includes(String(input.publication_state))) return null;
  if (input.rsvp_mode !== undefined && !["not_required", "optional", "required"].includes(String(input.rsvp_mode))) return null;
  if (value.operation === "event.create" || value.operation === "event.update") {
    if (!uuid(input.organization_id) || !text(input.title,200) || !input.title.trim() || !text(input.event_type_key,64) || !/^[a-z][a-z0-9_]*$/.test(input.event_type_key) || !instant(input.start_at) || !instant(input.end_at) || typeof input.timezone !== "string" || !validTimezone(input.timezone) || !validTargets(input.targets)) return null;
    const duration = Date.parse(input.end_at) - Date.parse(input.start_at);
    if (duration <= 0 || duration > 31 * 86_400_000 || (instant(input.arrival_at) && Date.parse(input.arrival_at) > Date.parse(input.start_at))) return null;
    if (input.game && input.event_type_key !== "game") return null;
  } else if (value.operation === "event.exception") {
    if (!uuid(input.event_id) || !integer(input.expected_version,1,2_147_483_647) || typeof input.occurrence_key !== "string" || Object.keys(input).length <= 3) return null;
    if ((input.override_start_at !== undefined) !== (input.override_end_at !== undefined)) return null;
    if (instant(input.override_start_at) && instant(input.override_end_at) && (Date.parse(input.override_end_at) <= Date.parse(input.override_start_at) || Date.parse(input.override_end_at) - Date.parse(input.override_start_at) > 31 * 86_400_000)) return null;
  } else if (value.operation === "calendar.configure") {
    if (!uuid(input.organization_id) || !isObject(input.features)) return null;
  } else {
    if (!uuid(input.organization_id) || !text(input.name,200) || !input.name.trim()) return null;
    if (value.operation.startsWith("venue.") && (typeof input.timezone !== "string" || !validTimezone(input.timezone))) return null;
    if (value.operation.startsWith("resource.") && (!uuid(input.venue_id) || !text(input.resource_type,64))) return null;
  }
  const updateKey = value.operation === "event.update" ? "event_id" : value.operation === "venue.update" ? "venue_id" : "resource_id";
  if (value.operation.endsWith(".update") && (!uuid(input[updateKey]) || !integer(input.expected_version,1,2_147_483_647))) return null;
  return value as CalendarCommand;
}
export async function readCalendarInput(request: Request, preview = false) {
  if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/json" || !request.body) return null;
  const declared = request.headers.get("content-length");
  if (declared && (!/^\d+$/.test(declared) || Number(declared) > 65_536)) return null;
  const reader = request.body.getReader(); const chunks: Uint8Array[] = []; let length = 0;
  try {
    for (;;) { const { done, value } = await reader.read(); if (done) break; length += value.byteLength; if (length > 65_536) { await reader.cancel(); return null; } chunks.push(value); }
    const bytes = new Uint8Array(length); let offset = 0; for (const chunk of chunks) { bytes.set(chunk,offset); offset += chunk.length; }
    const envelope: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (!isObject(envelope) || !keys(envelope,preview ? ["command"] : ["command", "request_id"]) || (!preview && !uuid(envelope.request_id))) return null;
    const command = parseCalendarCommand(envelope.command);
    if (!command || (preview && !command.operation.startsWith("event."))) return null;
    return { command, request_id: typeof envelope.request_id === "string" ? envelope.request_id : "" };
  } catch { return null; } finally { reader.releaseLock(); }
}

// Projections deliberately discard every unknown database field, including audit and Auth data.
type Projector = (value: unknown) => unknown;
const bad = Symbol("invalid");
const scalar = (check: (value: unknown) => boolean): Projector => value => check(value) ? value : bad;
const nullable = (project: Projector): Projector => value => value === null ? null : project(value);
const optional = (project: Projector): Projector => value => value === undefined ? undefined : project(value);
const array = (project: Projector, limit = 10_000): Projector => value => {
  if (!Array.isArray(value) || value.length > limit) return bad; const result = value.map(project); return result.includes(bad) ? bad : result;
};
const shape = (spec: Record<string, Projector>): Projector => value => {
  if (!isObject(value)) return bad; const result: Record<string, unknown> = {};
  for (const [key, project] of Object.entries(spec)) { const field = project(value[key]); if (field === bad) return bad; if (field !== undefined) result[key] = field; }
  return result;
};
const zone = scalar(value => typeof value === "string" && validTimezone(value));
const id = scalar(uuid), str = scalar(value => text(value)), time = scalar(instant), bool = scalar(value => typeof value === "boolean"), version = scalar(value => integer(value,1,2_147_483_647));
const choice = (choices: string[]) => scalar(value => typeof value === "string" && choices.includes(value));
const target = shape({ target_type: choice(["organization", "unit", "team"]), target_id: id, label: str });
const recurrence = nullable(scalar(value => validRecurrence(value)));
const reminder = shape({ minutes_before: scalar(value => integer(value,0,10080)), audience: array(str,20), enabled: bool });
const game = nullable(shape({ opponent_team_id: nullable(id), external_opponent_name: nullable(str), home_away: choice(["home", "away", "neutral"]), game_status: choice(["scheduled", "postponed", "canceled", "completed"]) }));
const occurrence = shape({ event_id: id, organization_id: id, occurrence_key: str, start_at: time, end_at: time, arrival_at: nullable(time), timezone: scalar(value => typeof value === "string" && validTimezone(value)), all_day: bool, title: str, description: nullable(str), event_type_key: str, status: choice(statuses), visibility: choice(visibilities), publication_state: choice(["unpublished", "published"]), rsvp_mode: choice(["not_required", "optional", "required"]), instructions: nullable(str), audience: array(str,20), venue_id: nullable(id), resource_id: nullable(id), targets: array(target,100), game, reminders: array(reminder,8), recurrence, is_exception: bool, exception_id: nullable(id), version, series_start_at: nullable(time), series_end_at: nullable(time), series_arrival_at: nullable(time), series_title: nullable(str), series_instructions: nullable(str), series_status: nullable(choice(statuses)), capabilities: shape({ manage: bool, publish: bool, override_conflict: bool }) });
const dataProjection = shape({ range: shape({ from: time, to: time }), options_limited: optional(bool), organizations: array(shape({ id, name: str, timezone: zone })), units: array(shape({ id, organization_id: id, name: str })), teams: array(shape({ id, organization_id: id, parent_unit_id: nullable(id), season_id: nullable(id), name: str })), seasons: array(shape({ id, organization_id: id, name: str })), children: array(shape({ id, name: str })), event_types: array(shape({ key: str, name: str })), venues: array(shape({ id, organization_id: id, name: str, timezone: zone, instructions: nullable(str), address_line1: nullable(str), address_line2: nullable(str), city: nullable(str), region: nullable(str), postal_code: nullable(str), country_code: nullable(str), is_public: bool, version: optional(version), status: optional(choice(["active", "inactive", "archived"])) })), resources: array(shape({ id, organization_id: id, venue_id: id, name: str, resource_type: str, is_public: bool, version: optional(version), status: optional(choice(["active", "inactive", "archived"])) })), features: shape(Object.fromEntries(featureKeys.map(key => [key,key === "conflict_overrides" ? optional(bool) : bool]))), capabilities: shape({ create: bool, manage_venues: bool, configure: bool, publish: bool, override_conflict: bool, create_targets: array(target,10000) }), occurrences: array(occurrence,10000) });
export function projectCalendarData(value: unknown): CalendarData | null { const projected = dataProjection(value); return projected === bad ? null : projected as CalendarData; }
export function projectCalendarPreview(value: unknown): CalendarPreview | null {
  const projected = shape({ conflicts: array(shape({ kind: choice(["resource", "team", "coach", "participant"]), event_id: nullable(id), title: str, start_at: time, end_at: time }),1000), has_conflicts: bool, can_override: bool })(value);
  return projected === bad ? null : projected as CalendarPreview;
}
export function projectCalendarMutation(value: unknown): CalendarMutationResult | null {
  const projected = shape({ request_id: id, resource_type: choice(["event", "event_exception", "venue", "venue_resource", "calendar_settings", "calendar_configuration", "organization_calendar_settings"]), resource_id: id, version })(value);
  return projected === bad ? null : projected as CalendarMutationResult;
}
