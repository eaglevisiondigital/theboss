import { isRecord, uuid, hasControlCharacters } from "../communications/input";
import { addDays, validDate, validOccurrenceKey, validTimezone } from "../calendar/temporal";
export { isRecord, uuid, validOccurrenceKey, validTimezone };
export const finiteKeys = (value: Record<string, unknown>, allowed: readonly string[]) => Object.keys(value).every(key => allowed.includes(key));
export const boundedText = (value: unknown, max = 500): value is string => typeof value === "string" && value.length <= max && !hasControlCharacters(value);
export const integer = (value: unknown, min = 0, max = 2_147_483_647): value is number => typeof value === "number" && Number.isSafeInteger(value) && value >= min && value <= max;
export const instant = (value: unknown): value is string => typeof value === "string" && /^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,6})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$/.test(value) && validDate(value.slice(0, 10)) && Number.isFinite(Date.parse(value));
export const oneOf = (value: unknown, choices: readonly string[]): value is string => typeof value === "string" && choices.includes(value);
export const nullable = (value: unknown, check: (item: unknown) => boolean) => value === null || check(value);
export const text = (row: Record<string, unknown>, key: string, fallback = "", max = 500) => boundedText(row[key], max) ? row[key] as string : fallback;
export const count = (value: unknown) => integer(value) ? value : 0;
export const version = (value: unknown) => integer(value, 1) ? value : 1;
export const optionalId = (value: unknown) => uuid(value) ? value : null;
export const optionalTime = (value: unknown) => instant(value) ? value : null;
export type Choice = { id: string; label: string };
export function collection<T>(value: unknown, project: (row: Record<string, unknown>) => T | null, max = 100): T[] {
  return Array.isArray(value) && value.length <= max ? value.flatMap(item => { const projected = isRecord(item) ? project(item) : null; return projected ? [projected] : []; }) : [];
}
export const choice = (row: Record<string, unknown>): Choice | null => uuid(row.id) ? { id: row.id, label: text(row, "label", text(row, "name", "Available context"), 200) } : null;
export function dateRange(from: unknown, to: unknown) { return instant(from) && instant(to) && Date.parse(to) > Date.parse(from) && Date.parse(to) - Date.parse(from) <= 93 * 86_400_000; }
export function queryTimes(params: Record<string, string | string[] | undefined>, now = new Date()) {
  const from = typeof params.from === "string" && validDate(params.from) ? `${params.from}T00:00:00.000Z` : params.from ?? now.toISOString();
  const to = typeof params.to === "string" && validDate(params.to) ? `${addDays(params.to, 1)}T00:00:00.000Z` : params.to ?? new Date(now.getTime() + 30 * 86_400_000).toISOString();
  return dateRange(from, to) ? { from: from as string, to: to as string } : null;
}

export type CoordinationResult = { request_id: string; operation: string; resource_id: string; version: number; status?: string; prepared?: number };
export function projectCoordinationResult(value: unknown, requestId: string, operation: string): CoordinationResult | null {
  if (!isRecord(value) || value.request_id !== requestId || value.operation !== operation || !uuid(value.resource_id) || !integer(value.version)) return null;
  return { request_id: requestId, operation, resource_id: value.resource_id, version: value.version, ...(typeof value.status === "string" && value.status.length <= 40 ? { status: value.status } : {}), ...(integer(value.prepared) ? { prepared: value.prepared } : {}) };
}
