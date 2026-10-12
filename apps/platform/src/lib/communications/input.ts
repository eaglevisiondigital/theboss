import type { Json } from "../supabase/database.types";
import { communicationOperations, threadKinds, emptyCommunications, type Choice, type CommunicationAttachment, type CommunicationCommand, type CommunicationData, type CommunicationMessage, type CommunicationOperation, type CommunicationQuery, type CommunicationResult, type CommunicationThread, type ThreadKind } from "./contracts";

export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isRecord = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value);
export const uuid = (value: unknown): value is string => typeof value === "string" && uuidPattern.test(value);
export const hasControlCharacters = (value: string) => [...value].some(character => character.charCodeAt(0) < 32 && ![9, 10, 13].includes(character.charCodeAt(0)));
const string = (value: unknown, max = 8000): value is string => typeof value === "string" && value.length <= max && !hasControlCharacters(value);
const integer = (value: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): value is number => typeof value === "number" && Number.isSafeInteger(value) && value >= min && value <= max;
const keys = (value: Record<string, unknown>, allowed: readonly string[]) => Object.keys(value).every(key => allowed.includes(key));
const ids = (value: unknown, max: number) => Array.isArray(value) && value.length <= max && value.every(uuid) && new Set(value).size === value.length;
const fields: Record<CommunicationOperation, string[]> = {
  "thread.create": ["organization_id", "kind", "title", "scope_type", "scope_id", "members", "household_id"], "thread.update": ["thread_id", "expected_version", "title", "status", "members"],
  "message.send": ["thread_id", "body", "attachment_ids"], "message.edit": ["message_id", "expected_version", "body"], "message.remove": ["message_id", "expected_version", "reason"], "message.pin": ["message_id", "expected_version", "pinned"],
  "announcement.send": ["organization_id", "title", "body", "visibility", "targets", "attachment_ids"], "read.message": ["message_id"], "read.thread": ["thread_id", "through_sequence"],
  "report.create": ["message_id", "reason", "detail"], "report.moderate": ["report_id", "status", "remove", "reason"], "communications.configure": ["organization_id", "configuration"], "guardian.configure": ["guardian_relationship_id", "can_receive_communications", "can_send_communications"],
  "attachment.intent": ["thread_id", "file_name", "mime_type", "size_bytes", "content_sha256"], "attachment.complete": ["attachment_id"], "attachment.access": ["attachment_id"],
};
export const configurationKeys = ["communications", "announcements", "team_chat", "direct_messaging", "email_notifications", "guardian_visibility", "participant_messaging", "minor_groups", "attachments", "moderation", "staff_send", "in_app_notifications", "minimum_participant_age", "sender_edit_minutes"] as const;
export function parseCommunicationCommand(value: unknown): CommunicationCommand | null {
  if (!isRecord(value) || !keys(value, ["operation", "input"]) || !communicationOperations.includes(value.operation as CommunicationOperation) || !isRecord(value.input)) return null;
  const operation = value.operation as CommunicationOperation, input = value.input;
  if (!keys(input, fields[operation])) return null;
  for (const [key, item] of Object.entries(input)) {
    if (key.endsWith("_id") && !uuid(item)) return null;
    if (["expected_version", "through_sequence"].includes(key) && !integer(item, 1)) return null;
    if (["title", "file_name"].includes(key) && (!string(item, 200) || !item.trim())) return null;
    if (key === "body" && (!string(item) || !item.trim())) return null;
    if (["reason", "detail"].includes(key) && !string(item, 500)) return null;
    if (["members", "attachment_ids"].includes(key) && !ids(item, key === "members" ? 20 : 5)) return null;
    if (["pinned", "remove", "can_receive_communications", "can_send_communications"].includes(key) && typeof item !== "boolean") return null;
  }
  const required: Partial<Record<CommunicationOperation, string[]>> = { "thread.create": ["organization_id", "kind", "title", "scope_type", "scope_id"], "thread.update": ["thread_id", "expected_version"], "message.send": ["thread_id", "body"], "message.edit": ["message_id", "expected_version", "body"], "message.remove": ["message_id", "expected_version"], "message.pin": ["message_id", "expected_version", "pinned"], "announcement.send": ["organization_id", "title", "body", "targets"], "read.message": ["message_id"], "read.thread": ["thread_id"], "report.create": ["message_id", "reason"], "report.moderate": ["report_id", "status", "reason"], "communications.configure": ["organization_id", "configuration"], "guardian.configure": ["guardian_relationship_id"], "attachment.intent": ["thread_id", "file_name", "mime_type", "size_bytes", "content_sha256"], "attachment.complete": ["attachment_id"], "attachment.access": ["attachment_id"] };
  if ((required[operation] ?? []).some(key => input[key] === undefined)) return null;
  if (input.kind !== undefined && !threadKinds.includes(input.kind as ThreadKind)) return null;
  if (input.scope_type !== undefined && !["organization", "unit", "team"].includes(String(input.scope_type))) return null;
  if (input.visibility !== undefined && !["private", "public"].includes(String(input.visibility))) return null;
  if (operation === "thread.update" && input.status !== undefined && !["active", "archived"].includes(String(input.status))) return null;
  if (operation === "report.create" && !["spam", "harassment", "unsafe", "other"].includes(String(input.reason))) return null;
  if (operation === "report.moderate" && !["reviewed", "dismissed", "actioned"].includes(String(input.status))) return null;
  if (input.targets !== undefined && (!Array.isArray(input.targets) || !input.targets.length || input.targets.length > 50 || input.targets.some(target => !isRecord(target) || !keys(target, ["scope_type", "scope_id", "role_key"]) || !["organization", "unit", "team"].includes(String(target.scope_type)) || !uuid(target.scope_id) || target.role_key !== undefined && (!string(target.role_key, 60) || !/^[a-z][a-z0-9_]*$/.test(target.role_key))))) return null;
  if (input.configuration !== undefined && (!isRecord(input.configuration) || !Object.keys(input.configuration).length || !keys(input.configuration, configurationKeys) || Object.entries(input.configuration).some(([key, item]) => key === "minimum_participant_age" ? !integer(item, 0, 99) : key === "sender_edit_minutes" ? !integer(item, 0, 60) : typeof item !== "boolean"))) return null;
  if (operation === "attachment.intent" && (!["application/pdf", "image/jpeg", "image/png"].includes(String(input.mime_type)) || !integer(input.size_bytes, 1, 5 * 1024 * 1024) || typeof input.content_sha256 !== "string" || !/^[a-f0-9]{64}$/.test(input.content_sha256))) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}
export function parseCommunicationQuery(value: Record<string, string | string[] | undefined>, view: CommunicationQuery["view"]): CommunicationQuery | null {
  const query: CommunicationQuery = { view };
  for (const [param, field] of [["org", "organization_id"], ["team", "team_id"], ["thread", "thread_id"]] as const) { const item = value[param]; if (item !== undefined && item !== "") { if (!uuid(item)) return null; query[field] = item; } }
  if (value.q) { if (!string(value.q, 100)) return null; query.query = value.q.trim(); }
  if (value.before) { if (typeof value.before !== "string" || !/^\d+$/.test(value.before) || !integer(Number(value.before), 1)) return null; query.before_sequence = Number(value.before); }
  return query;
}
export async function readBoundedJson(request: Request, limit = 24_000): Promise<unknown> {
  const length = request.headers.get("content-length"); if (length && (!/^\d+$/.test(length) || Number(length) > limit) || !request.headers.get("content-type")?.toLowerCase().startsWith("application/json") || !request.body) return null;
  const reader = request.body.getReader(), chunks: Uint8Array[] = []; let size = 0;
  try { for (;;) { const { done, value } = await reader.read(); if (done) break; size += value.length; if (size > limit) { await reader.cancel(); return null; } chunks.push(value); } const bytes = new Uint8Array(size); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; } return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); } catch { return null; } finally { reader.releaseLock(); }
}
const text = (row: Record<string, unknown>, key: string, fallback = "", max = 8000) => string(row[key], max) ? row[key] as string : fallback;
const count = (value: unknown) => integer(value) ? value : 0;
const nullable = (value: unknown) => string(value, 100) ? value : null;
const operations = (value: unknown): CommunicationOperation[] => Array.isArray(value) ? value.filter((item): item is CommunicationOperation => communicationOperations.includes(item)) : [];
function collection<T>(value: unknown, project: (row: Record<string, unknown>) => T | null, max = 100): T[] { return Array.isArray(value) && value.length <= max ? value.flatMap(item => { const result = isRecord(item) ? project(item) : null; return result ? [result] : []; }) : []; }
const choice = (row: Record<string, unknown>): Choice | null => uuid(row.id) ? { id: row.id, label: text(row, "label", text(row, "name", text(row, "display_name")), 200), ...(uuid(row.organization_id) ? { organization_id: row.organization_id } : {}), operations: operations(row.operations) } : null;
function thread(row: Record<string, unknown>): CommunicationThread | null { return uuid(row.id) && uuid(row.organization_id) ? { id: row.id, organization_id: row.organization_id, title: text(row, "title", "Conversation", 200), kind: text(row, "thread_type", text(row, "kind"), 60), scope_type: text(row, "scope_type", "", 30), scope_id: uuid(row.scope_id) ? row.scope_id : null, status: text(row, "status", "active", 30), version: count(row.version), unread_count: count(row.unread_count), latest_at: nullable(row.latest_at ?? row.last_message_at ?? row.updated_at), operations: operations(row.operations), members: collection(row.members, choice, 20) } : null; }
function attachment(row: Record<string, unknown>): CommunicationAttachment | null { return uuid(row.id) ? { id: row.id, filename: text(row, "filename", text(row, "file_name", "Private attachment"), 200), mime_type: text(row, "mime_type", "", 100), size_bytes: count(row.size_bytes), status: text(row, "status", "ready", 30), operations: operations(row.operations) } : null; }
function message(row: Record<string, unknown>): CommunicationMessage | null { if (!uuid(row.id)) return null; const status = text(row, "status", text(row, "moderation_status", "visible"), 30); const hidden = ["removed", "hidden", "deleted"].includes(status); return { id: row.id, body: hidden ? null : text(row, "body"), author_name: text(row, "author_name", "Member", 200), author_person_id: uuid(row.author_person_id) ? row.author_person_id : null, sequence: count(row.sequence ?? row.sequence_number), version: count(row.version), created_at: text(row, "created_at", "", 100), edited_at: nullable(row.edited_at), status, pinned: row.pinned === true || typeof row.pinned_at === "string", operations: operations(row.operations), attachments: hidden ? [] : collection(row.attachments, attachment, 5) }; }
export function projectCommunicationData(value: unknown): CommunicationData | null {
  if (!isRecord(value) || !isRecord(value.features) || !Array.isArray(value.threads)) return null;
  const features: CommunicationData["features"] = {}; for (const [key, item] of Object.entries(value.features)) if (configurationKeys.includes(key as typeof configurationKeys[number]) && (typeof item === "boolean" || integer(item, 0, 120))) features[key] = item;
  const result: CommunicationData = { ...emptyCommunications, features, person: isRecord(value.person) ? choice(value.person) : null, organizationId: uuid(value.organizationId) ? value.organizationId : null, operations: operations(value.operations), organizations: collection(value.organizations, choice), threads: collection(value.threads, thread), candidates: collection(value.candidates, choice), teams: collection(value.teams, choice), units: collection(value.units, choice), unread: { messages: isRecord(value.unread) ? count(value.unread.messages) : 0, channels: isRecord(value.unread) ? count(value.unread.channels) : 0 }, more: value.more === true, cursor: integer(value.cursor, 1) ? value.cursor : null, targets: [], audienceRoles: [], households: collection(value.households, choice), reports: [], guardians: [] };
  result.targets = collection(value.targets, row => uuid(row.scope_id) && ["organization", "unit", "team"].includes(String(row.scope_type)) ? { scope_type: row.scope_type as "organization" | "unit" | "team", scope_id: row.scope_id, label: text(row, "label", "Scope", 200), operations: operations(row.operations), thread_kinds: Array.isArray(row.thread_kinds) ? row.thread_kinds.filter((kind): kind is ThreadKind => threadKinds.includes(kind)) : [] } : null);
  result.audienceRoles = collection(value.audience_roles, row => typeof row.key === "string" && /^[a-z][a-z0-9_]{0,59}$/.test(row.key) && Array.isArray(row.allowed_scope_types) ? { key: row.key, label: text(row, "label", row.key, 200), allowed_scope_types: row.allowed_scope_types.filter((scope): scope is string => typeof scope === "string" && ["platform", "organization", "organization_unit", "team"].includes(scope)) } : null);
  result.reports = collection(value.reports, row => uuid(row.id) && uuid(row.message_id) ? { id: row.id, message_id: row.message_id, reason: text(row, "reason", "", 30), status: text(row, "status", "", 30), created_at: text(row, "created_at", "", 100), operations: operations(row.operations) } : null);
  result.guardians = collection(value.guardians, row => uuid(row.id) ? { id: row.id, guardian_name: text(row, "guardian_name", text(row, "guardian_label", "Guardian"), 200), dependent_name: text(row, "dependent_name", text(row, "dependent_label", "Participant"), 200), can_receive_communications: row.can_receive_communications === true, can_send_communications: row.can_send_communications === true, operations: operations(row.operations) } : null);
  if (isRecord(value.detail) && isRecord(value.detail.thread)) { const selected = thread(value.detail.thread); if (selected) result.detail = { thread: selected, messages: collection(value.detail.messages, message, 50) }; }
  return result;
}
export function projectCommunicationResult(value: unknown, requestId: string): CommunicationResult | null { return isRecord(value) && value.request_id === requestId && communicationOperations.includes(value.operation as CommunicationOperation) && uuid(value.resource_id) && integer(value.version) ? { request_id: requestId, operation: value.operation as CommunicationOperation, resource_id: value.resource_id, version: value.version } : null; }
