import { hasControlCharacters, isRecord, uuid } from "../communications/input";
import { validDate, validOccurrenceKey, validTimezone } from "../calendar/temporal";
import type { Json } from "../supabase/database.types";
import { emptyNotifications, notificationCategories, notificationOperations, type NotificationCategory, type NotificationCommand, type NotificationData, type NotificationOperation, type NotificationQuery, type NotificationResult } from "./contracts";
const integer = (value: unknown, max = Number.MAX_SAFE_INTEGER) => typeof value === "number" && Number.isSafeInteger(value) && value >= 0 && value <= max;
const text = (value: unknown, max = 4000) => typeof value === "string" && value.length <= max && !hasControlCharacters(value) ? value : "";
const category = (value: unknown): value is NotificationCategory => notificationCategories.includes(value as NotificationCategory);
const date = (value: unknown): value is string => typeof value === "string" && value.length <= 50 && /^\d{4}-\d{2}-\d{2}T/.test(value) && Number.isFinite(Date.parse(value));
export function safeNotificationDestination(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 512 || !value.startsWith("/app/") || (value.includes("\\") || value.includes("#") || [...value].some(character => character.charCodeAt(0) <= 32))) return null;
  try { const url = new URL(value, "https://boss.invalid"); if (url.origin !== "https://boss.invalid" || url.searchParams.getAll("org").length !== 1 || !uuid(url.searchParams.get("org"))) return null;
    if (url.pathname === "/app/registrations" && url.searchParams.get("view") === "family" && url.searchParams.getAll("view").length === 1 && [...url.searchParams.keys()].every(key => ["org", "view"].includes(key))) return `${url.pathname}?${url.searchParams.toString()}`;
    const key = ({ "/app/calendar": "event", "/app/registrations": "registration", "/app/messages": "thread", "/app/announcements": "thread", "/app/attendance": "event", "/app/volunteers": url.searchParams.has("event") ? "event" : "shift" } as Record<string, string>)[url.pathname];
    const allowed = url.pathname === "/app/calendar" ? ["org", key, "date", "tz", "occurrence"] : url.pathname === "/app/attendance" ? ["org", key, "occurrence"] : ["org", key];
    if (!key || [...url.searchParams.keys()].some(param => !allowed.includes(param)) || url.searchParams.getAll(key).length !== 1 || !uuid(url.searchParams.get(key))) return null;
    if (url.searchParams.has("date") && (url.searchParams.getAll("date").length !== 1 || !validDate(url.searchParams.get("date")!))) return null;
    if (url.searchParams.has("tz")) { const timezone = url.searchParams.get("tz")!; if (url.searchParams.getAll("tz").length !== 1 || !url.searchParams.has("date") || timezone.length > 100 || !/^[A-Za-z0-9_+\-/]+$/.test(timezone) || !validTimezone(timezone)) return null; }
    if (url.searchParams.has("occurrence") && (url.searchParams.getAll("occurrence").length !== 1 || (url.pathname !== "/app/attendance" && (!url.searchParams.has("date") || !url.searchParams.has("tz"))) || !validOccurrenceKey(url.searchParams.get("occurrence")!))) return null;
    if (url.pathname === "/app/attendance" && !url.searchParams.has("occurrence")) return null;
    return `${url.pathname}?${url.searchParams.toString()}`; } catch { return null; }
}
export function parseNotificationCommand(value: unknown): NotificationCommand | null {
  if (!isRecord(value) || Object.keys(value).some(key => !["operation", "input"].includes(key)) || !notificationOperations.includes(value.operation as NotificationOperation) || !isRecord(value.input)) return null;
  const operation = value.operation as NotificationOperation, input = value.input;
  const fields: Record<NotificationOperation, string[]> = { "notification.read": ["id"], "notification.read_all": ["organization_id"], "preference.set": ["channel", "category", "organization_id", "team_id", "enabled"], "delivery.process": ["organization_id", "limit"], "reminder.generate": ["organization_id", "window_start", "window_end"] };
  if (Object.keys(input).some(key => !fields[operation].includes(key))) return null;
  for (const [key, item] of Object.entries(input)) if ((key === "id" || key.endsWith("_id")) && !uuid(item)) return null;
  if (operation === "notification.read" && !uuid(input.id) || ["delivery.process", "reminder.generate"].includes(operation) && !uuid(input.organization_id)) return null;
  if (operation === "preference.set" && (!["in_app", "email"].includes(String(input.channel)) || !category(input.category) || typeof input.enabled !== "boolean" || input.team_id && !input.organization_id)) return null;
  if (input.limit !== undefined && (!integer(input.limit, 50) || input.limit === 0)) return null;
  for (const key of ["window_start", "window_end"]) if (input[key] !== undefined && !date(input[key])) return null;
  if (input.window_start && input.window_end && Date.parse(String(input.window_end)) <= Date.parse(String(input.window_start))) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}
export function parseNotificationQuery(value: Record<string, string | string[] | undefined>): NotificationQuery | null {
  const view = value.view ?? "inbox"; if (typeof view !== "string" || !["inbox", "summary", "preferences", "history"].includes(view)) return null; const result: NotificationQuery = { view: view as NotificationQuery["view"], limit: 30 };
  if (value.org) { if (!uuid(value.org)) return null; result.organization_id = value.org; }
  if (value.category) { if (!category(value.category)) return null; result.category = value.category; }
  if (value.before) { if (!date(value.before)) return null; result.before = value.before; }
  return result;
}
export function projectNotificationData(value: unknown): NotificationData | null {
  if (!isRecord(value) || !Array.isArray(value.notifications) || value.notifications.length > 50 || !isRecord(value.availability)) return null;
  const result: NotificationData = { ...emptyNotifications, notifications: [], preferences: [], history: [], organizations: [], features: {}, operations: Array.isArray(value.operations) ? value.operations.filter((operation): operation is NotificationOperation => notificationOperations.includes(operation)) : [], unread_count: integer(value.unread_count) ? value.unread_count as number : 0, organizationId: uuid(value.organizationId) ? value.organizationId : null, availability: { in_app: value.availability.in_app === true, email: value.availability.email === "available" ? "available" : "not_configured", sms: "future", push: "future" } };
  for (const row of value.notifications) if (isRecord(row) && uuid(row.id) && uuid(row.organization_id) && category(row.category)) result.notifications.push({ id: row.id, organization_id: row.organization_id, team_id: uuid(row.team_id) ? row.team_id : null, category: row.category, event_type: text(row.event_type, 100), title: text(row.title, 200), body: text(row.body), destination: safeNotificationDestination(row.destination), created_at: text(row.created_at, 50), read_at: date(row.read_at) ? row.read_at : null });
  if (Array.isArray(value.preferences) && value.preferences.length <= 100) for (const row of value.preferences) if (isRecord(row) && uuid(row.id) && ["in_app", "email"].includes(String(row.channel)) && category(row.category)) result.preferences.push({ id: row.id, channel: row.channel as "in_app" | "email", category: row.category, organization_id: uuid(row.organization_id) ? row.organization_id : null, team_id: uuid(row.team_id) ? row.team_id : null, enabled: row.enabled === true });
  if (Array.isArray(value.history) && value.history.length <= 50) for (const row of value.history) if (isRecord(row) && uuid(row.id)) result.history.push({ id: row.id, event_type: text(row.event_type, 100), channel: text(row.channel, 30), status: text(row.status, 30), created_at: text(row.created_at, 50), sent_at: date(row.sent_at) ? row.sent_at : null, failure_category: text(row.failure_category, 100) || null, attempts: integer(row.attempts) ? row.attempts as number : 0, recipient_name: text(row.recipient_name, 200) });
  if (Array.isArray(value.organizations) && value.organizations.length <= 100) for (const row of value.organizations) if (isRecord(row) && uuid(row.id)) result.organizations.push({ id: row.id, label: text(row.label ?? row.name, 200) });
  if (isRecord(value.features)) for (const key of ["notifications", "in_app_notifications", "email_notifications", "history_available", "delivery_history"]) if (typeof value.features[key] === "boolean") result.features[key] = value.features[key];
  return result;
}
export function projectNotificationResult(value: unknown, requestId: string): NotificationResult | null { if (!isRecord(value) || value.request_id !== requestId || !notificationOperations.includes(value.operation as NotificationOperation) || !uuid(value.resource_id) || !integer(value.version)) return null; const result: NotificationResult = { request_id: requestId, operation: value.operation as NotificationOperation, resource_id: value.resource_id, version: value.version as number }; for (const key of ["processed", "generated", "suppressed"] as const) if (integer(value[key], 10_000)) result[key] = value[key] as number; return result; }
