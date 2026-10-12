import type { Json } from "../supabase/database.types";
import { attendanceFeatureKeys, attendanceOperations, attendanceStatuses, checkinStates, emptyAttendance, type AttendanceCommand, type AttendanceHistory, type AttendanceData, type AttendanceOccurrence, type AttendanceQuery, type AttendanceSubject } from "./contracts";
import { boundedText, choice, collection, count, dateRange, finiteKeys, integer, isRecord, nullable, oneOf, optionalId, optionalTime, queryTimes, text, uuid, validOccurrenceKey, validTimezone, version } from "../coordination/input";

const operations: Record<typeof attendanceOperations[number], string[]> = {
  "attendance.configure": ["organization_id", "configuration"], "event.configure": ["event_id", "expected_version", "rsvp_mode", "deadline_policy", "change_policy", "audience", "response_deadline_at", "deadline_offset_minutes"],
  "response.set": ["event_id", "occurrence_key", "person_id", "participant_id", "subject_kind", "status", "expected_version", "reason", "note", "arrival_difference_minutes", "departure_difference_minutes", "override_deadline"],
  "checkin.set": ["event_id", "occurrence_key", "person_id", "participant_id", "subject_kind", "state", "expected_version"], "reminders.prepare": ["organization_id", "from", "to", "kind"],
};
export function parseAttendanceCommand(value: unknown): AttendanceCommand | null {
  if (!isRecord(value) || !finiteKeys(value, ["operation", "input"]) || !oneOf(value.operation, attendanceOperations) || !isRecord(value.input)) return null;
  const operation = value.operation as AttendanceCommand["operation"], input = value.input;
  if (!finiteKeys(input, operations[operation])) return null;
  for (const [key, item] of Object.entries(input)) {
    if (["event_id", "person_id", "organization_id"].includes(key) && !uuid(item)) return null;
    if (key === "participant_id" && !nullable(item, uuid)) return null;
    if (key === "expected_version" && !integer(item)) return null;
    if (key === "occurrence_key" && (typeof item !== "string" || !validOccurrenceKey(item))) return null;
    if (["reason", "note"].includes(key) && !nullable(item, value => boundedText(value, 500))) return null;
    if (["arrival_difference_minutes", "departure_difference_minutes"].includes(key) && !nullable(item, value => integer(value, -1440, 1440))) return null;
    if (key === "override_deadline" && typeof item !== "boolean") return null;
  }
  if (operation === "attendance.configure") {
    if (!uuid(input.organization_id) || !isRecord(input.configuration) || !Object.keys(input.configuration).length || !finiteKeys(input.configuration, attendanceFeatureKeys) || Object.entries(input.configuration).some(([key, item]) => key === "minimum_self_response_age" ? !integer(item, 18, 100) : typeof item !== "boolean")) return null;
  } else if (operation === "event.configure") {
    if (!uuid(input.event_id) || !integer(input.expected_version) || !oneOf(input.rsvp_mode, ["not_required", "optional", "required"]) || !oneOf(input.deadline_policy, ["lock", "allow_late"]) || !oneOf(input.change_policy, ["keep", "needs_reconfirmation"]) || !Array.isArray(input.audience) || !input.audience.length || input.audience.length > 2 || !input.audience.every(item => oneOf(item, ["participants", "staff"])) || new Set(input.audience).size !== input.audience.length || !nullable(input.response_deadline_at, optionalTimeCheck) || !nullable(input.deadline_offset_minutes, value => integer(value, 0, 44_640)) || input.response_deadline_at !== null && input.deadline_offset_minutes !== null) return null;
  } else if (operation === "response.set" || operation === "checkin.set") {
    if (!uuid(input.event_id) || !uuid(input.person_id) || typeof input.occurrence_key !== "string" || !validOccurrenceKey(input.occurrence_key) || !nullable(input.participant_id, uuid) || !oneOf(input.subject_kind, ["participant", "staff"]) || !integer(input.expected_version) || input.subject_kind === "participant" && !uuid(input.participant_id) || input.subject_kind === "staff" && input.participant_id !== null) return null;
    if (operation === "response.set" ? !oneOf(input.status, attendanceStatuses) : !oneOf(input.state, checkinStates)) return null;
  } else if (!uuid(input.organization_id) || !dateRange(input.from, input.to) || !oneOf(input.kind, ["requested", "deadline", "no_response"])) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}
const optionalTimeCheck = (value: unknown) => optionalTime(value) !== null;
export function parseAttendanceQuery(params: Record<string, string | string[] | undefined>, now = new Date()): AttendanceQuery | null {
  const range = queryTimes(params, now); if (!range) return null;
  const view = params.view ?? "family"; if (!oneOf(view, ["family", "staff", "history"])) return null;
  const query: AttendanceQuery = { view: view as AttendanceQuery["view"], ...range };
  for (const [param, key] of [["org", "organization_id"], ["event", "event_id"], ["team", "team_id"], ["unit", "unit_id"], ["child", "child_person_id"]] as const) { const value = params[param]; if (value !== undefined && value !== "") { if (!uuid(value)) return null; query[key] = value; } }
  if (params.occurrence !== undefined && params.occurrence !== "") { if (typeof params.occurrence !== "string" || !validOccurrenceKey(params.occurrence) || !query.event_id) return null; query.occurrence_key = params.occurrence; }
  return query;
}
function subject(row: Record<string, unknown>): AttendanceSubject | null {
  if (!uuid(row.person_id) || !oneOf(row.subject_kind, ["participant", "staff"])) return null;
  const raw = isRecord(row.capabilities) ? row.capabilities : {}, capabilities = { respond: raw.respond === true, manage: raw.manage === true, checkin: raw.checkin === true, view_private_notes: raw.view_private_notes === true };
  const response = isRecord(row.response) && uuid(row.response.id) && oneOf(row.response.status, attendanceStatuses) ? { id: row.response.id, status: row.response.status as typeof attendanceStatuses[number], version: version(row.response.version), needs_reconfirmation: row.response.needs_reconfirmation === true, is_late: row.response.is_late === true, reason: capabilities.view_private_notes ? text(row.response, "reason") || null : null, note: capabilities.view_private_notes ? text(row.response, "note") || null : null, arrival_difference_minutes: capabilities.view_private_notes && integer(row.response.arrival_difference_minutes, -1440, 1440) ? row.response.arrival_difference_minutes : null, departure_difference_minutes: capabilities.view_private_notes && integer(row.response.departure_difference_minutes, -1440, 1440) ? row.response.departure_difference_minutes : null } : null;
  return { person_id: row.person_id, participant_id: optionalId(row.participant_id), subject_kind: row.subject_kind as "participant" | "staff", display_name: text(row, "display_name", "Member", 200), response, checkin: isRecord(row.checkin) && uuid(row.checkin.id) && oneOf(row.checkin.state, checkinStates) ? { id: row.checkin.id, state: row.checkin.state as typeof checkinStates[number], version: version(row.checkin.version) } : null, capabilities };
}
function occurrence(row: Record<string, unknown>): AttendanceOccurrence | null {
  if (!uuid(row.event_id) || !uuid(row.organization_id) || typeof row.occurrence_key !== "string" || !validOccurrenceKey(row.occurrence_key) || !optionalTime(row.start_at) || !optionalTime(row.end_at)) return null;
  const settings = isRecord(row.settings) ? row.settings : {}, summary = isRecord(row.summary) ? row.summary : {}, capabilities = isRecord(row.capabilities) ? row.capabilities : {};
  return { event_id: row.event_id, organization_id: row.organization_id, title: text(row, "title", "Event", 200), occurrence_key: row.occurrence_key, start_at: row.start_at as string, end_at: row.end_at as string, timezone: typeof row.timezone === "string" && validTimezone(row.timezone) ? row.timezone : "UTC", status: text(row, "status", "scheduled", 30), rsvp_mode: oneOf(row.rsvp_mode, ["not_required", "optional", "required"]) ? row.rsvp_mode as AttendanceOccurrence["rsvp_mode"] : "not_required", settings: { response_deadline_at: optionalTime(settings.response_deadline_at), effective_deadline_at: optionalTime(settings.effective_deadline_at ?? settings.response_deadline_at), deadline_offset_minutes: integer(settings.deadline_offset_minutes, 0, 44_640) ? settings.deadline_offset_minutes : null, deadline_policy: settings.deadline_policy === "allow_late" ? "allow_late" : "lock", change_policy: settings.change_policy === "needs_reconfirmation" ? "needs_reconfirmation" : "keep", audience: Array.isArray(settings.audience) ? settings.audience.filter((item): item is "participants" | "staff" => oneOf(item, ["participants", "staff"])) : [], version: count(settings.version) }, summary: { attending: count(summary.attending), not_attending: count(summary.not_attending), maybe: count(summary.maybe), pending: count(summary.pending), unknown: count(summary.unknown), needs_reconfirmation: count(summary.needs_reconfirmation), total: count(summary.total) }, capabilities: { view_summary: capabilities.view_summary === true, manage: capabilities.manage === true, checkin: capabilities.checkin === true }, subjects: collection(row.subjects, subject, 1000) };
}
export function projectAttendanceData(value: unknown, query: AttendanceQuery): AttendanceData | null {
  if (!isRecord(value) || !isRecord(value.features) || !Array.isArray(value.occurrences)) return null;
  const features: AttendanceData["features"] = {}; for (const key of attendanceFeatureKeys) { const item = value.features[key]; if (key === "minimum_self_response_age" ? integer(item, 18, 100) : typeof item === "boolean") features[key] = item as boolean | number; }
  return { ...emptyAttendance(query), navigation_available: value.navigation_available === true, options_limited: value.options_limited === true, ...(isRecord(value.range) && dateRange(value.range.from, value.range.to) ? { range: { from: value.range.from as string, to: value.range.to as string } } : {}), organization_id: optionalId(value.organization_id), features, capabilities: { configure: isRecord(value.capabilities) && value.capabilities.configure === true }, organizations: collection(value.organizations, choice, 101), teams: collection(value.teams, choice, 200), units: collection(value.units, choice), children: collection(value.children, row => uuid(row.person_id) && uuid(row.participant_id) ? { person_id: row.person_id, participant_id: row.participant_id, display_name: text(row, "display_name", "Child", 200) } : null), occurrences: collection(value.occurrences, occurrence, 1000), history: collection(value.history, historyEntry, 200) };
}

function historyEntry(row: Record<string, unknown>): AttendanceHistory | null { return uuid(row.id) && uuid(row.response_id) && uuid(row.event_id) && uuid(row.person_id) && typeof row.occurrence_key === "string" && validOccurrenceKey(row.occurrence_key) && optionalTime(row.created_at) && oneOf(row.status, attendanceStatuses) && oneOf(row.subject_kind, ["participant", "staff"]) ? { id: row.id, response_id: row.response_id, event_id: row.event_id, person_id: row.person_id, occurrence_key: row.occurrence_key, created_at: row.created_at as string, version: version(row.version), change_kind: text(row, "change_kind", "Response", 40), status: row.status as typeof attendanceStatuses[number], subject_kind: row.subject_kind as "participant" | "staff", needs_reconfirmation: row.needs_reconfirmation === true } : null; }
