import type { CalendarDisplay, CalendarSelection, Occurrence } from "./contracts";
import { uuidPattern } from "../admin/input";

const wallFormatters = new Map<string,Intl.DateTimeFormat>();
const timeFormatters = new Map<string,Intl.DateTimeFormat>();
function formatter(cache: Map<string,Intl.DateTimeFormat>, timezone: string, options: Intl.DateTimeFormatOptions) {
  const existing = cache.get(timezone); if (existing) return existing;
  const created = new Intl.DateTimeFormat("en-US",{ ...options,timeZone: timezone });
  if (cache.size >= 32) { const oldest = cache.keys().next().value; if (oldest !== undefined) cache.delete(oldest); }
  cache.set(timezone,created); return created;
}
const dateFormatter = new Intl.DateTimeFormat("en-US",{ weekday: "short",month: "short",day: "numeric",timeZone: "UTC" });
export function validTimezone(value: string) { try { new Intl.DateTimeFormat("en", { timeZone: value }); return true; } catch { return false; } }
export function localDateTime(instant: string | number, timezone: string): string {
  const parts = formatter(wallFormatters,timezone,{ year: "numeric",month: "2-digit",day: "2-digit",hour: "2-digit",minute: "2-digit",second: "2-digit",hourCycle: "h23" }).formatToParts(new Date(instant));
  const get = (key: string) => parts.find(part => part.type === key)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}:${get("second")}`;
}
export function validDate(value: string) { return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(`${value}T12:00:00Z`)) && new Date(`${value}T12:00:00Z`).toISOString().slice(0, 10) === value; }
/** Resolve wall time in its selected zone. A fold uses the later instant; a gap has no instant. */
export function localToInstant(value: string, timezone: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/.test(value) || !validTimezone(timezone) || !validDate(value.slice(0, 10))) return null;
  const wall = value.length === 16 ? `${value}:00` : value;
  const guess = Date.parse(`${wall}Z`);
  if (!Number.isFinite(guess) || new Date(guess).toISOString().slice(0,19) !== wall) return null;
  const offsets = new Set<number>();
  for (let hours = -36; hours <= 36; hours += 6) {
    const sample = guess + hours * 3_600_000;
    offsets.add(Date.parse(`${localDateTime(sample, timezone)}Z`) - sample);
  }
  const matches = Array.from(offsets).map(offset => guess - offset).filter(candidate => localDateTime(candidate, timezone) === wall);
  return matches.length ? new Date(Math.max(...matches)).toISOString() : null;
}
export function addDays(date: string, days: number): string { const next = new Date(`${date}T12:00:00Z`); next.setUTCDate(next.getUTCDate() + days); return next.toISOString().slice(0, 10); }
export function moveDate(date: string, display: CalendarDisplay, direction: number) {
  if (display !== "month") return addDays(date, direction * (display === "week" ? 7 : display === "agenda" ? 14 : 1));
  const next = new Date(`${date.slice(0,7)}-01T12:00:00Z`); next.setUTCMonth(next.getUTCMonth() + direction); return next.toISOString().slice(0,10);
}
export function displayDays(date: string, display: CalendarDisplay): string[] {
  const anchor = display === "month" ? `${date.slice(0,7)}-01` : date;
  const weekday = new Date(`${anchor}T12:00:00Z`).getUTCDay();
  const first = ["month", "week"].includes(display) ? addDays(anchor, -((weekday + 6) % 7)) : anchor;
  return Array.from({ length: display === "month" ? 42 : display === "week" ? 7 : display === "agenda" ? 14 : 1 }, (_, index) => addDays(first, index));
}
export function occurrenceOnDate(occurrence: Occurrence, date: string, timezone: string) {
  // End is exclusive. A midnight end belongs only to the preceding day.
  return localDateTime(occurrence.start_at, timezone).slice(0,10) <= date && localDateTime(Date.parse(occurrence.end_at) - 1, timezone).slice(0,10) >= date;
}
export function groupOccurrences(occurrences: Occurrence[], days: string[], timezone: string) {
  const grouped = new Map(days.map(day => [day,[] as Occurrence[]]));
  for (const occurrence of occurrences) {
    const first = localDateTime(occurrence.start_at,timezone).slice(0,10), last = localDateTime(Date.parse(occurrence.end_at)-1,timezone).slice(0,10);
    for (const day of days) if (day >= first && day <= last) grouped.get(day)?.push(occurrence);
  }
  return grouped;
}
export function formatDate(date: string) { return dateFormatter.format(new Date(`${date}T12:00:00Z`)); }
export function formatTime(instant: string, timezone: string) { return formatter(timeFormatters,timezone,{ hour: "numeric",minute: "2-digit" }).format(new Date(instant)); }
export function parseSelection(params: Record<string, string | string[] | undefined>, now = new Date()): CalendarSelection {
  let invalid = false;
  const text = (key: string) => { const value = params[key]; if (Array.isArray(value)) invalid = true; return typeof value === "string" ? value : ""; };
  const view = text("view"); let display: CalendarDisplay = ["month", "week", "day", "agenda"].includes(view) ? view as CalendarDisplay : "agenda";
  if (view && view !== display) invalid = true;
  const zone = text("tz"); const timezone = zone && validTimezone(zone) ? zone : "UTC"; if (zone && zone !== timezone) invalid = true;
  const dateValue = text("date"); const date = validDate(dateValue) ? dateValue : localDateTime(now.getTime(), timezone).slice(0,10); if (dateValue && dateValue !== date) invalid = true;
  const days = displayDays(date, display); const requestedFrom = text("from"), requestedTo = text("to");
  const rangeStart = requestedFrom || days[0]; const rangeEnd = requestedTo || (validDate(rangeStart) ? addDays(rangeStart,days.length-1) : days.at(-1)!);
  if (requestedFrom || requestedTo) display = "agenda";
  const start = validDate(rangeStart) ? localToInstant(`${rangeStart}T00:00`, timezone) : null;
  const end = validDate(rangeEnd) ? localToInstant(`${addDays(rangeEnd, 1)}T00:00`, timezone) : null;
  if (!start || !end || Date.parse(end) <= Date.parse(start) || Date.parse(end) - Date.parse(start) > 93 * 86_400_000) invalid = true;
  const scope = text("scope") || "personal"; if (!["personal", "organization", "team"].includes(scope)) invalid = true;
  const query: CalendarSelection["query"] = { from: start ?? now.toISOString(), to: end ?? new Date(now.getTime() + 86_400_000).toISOString(), view: ["personal", "organization", "team"].includes(scope) ? scope as CalendarSelection["query"]["view"] : "personal" };
  for (const [url, key] of [["org", "organization_id"], ["unit", "unit_id"], ["team", "team_id"], ["season", "season_id"], ["child", "child_id"], ["venue", "location_id"]] as const) {
    const value = text(url); if (!value) continue; if (!uuidPattern.test(value)) invalid = true; else query[key] = value;
  }
  const type = text("type"); if (type && /^[a-z][a-z0-9_]{0,63}$/.test(type)) query.event_type_key = type; else if (type) invalid = true;
  return { date, display, timezone, query, invalid };
}
