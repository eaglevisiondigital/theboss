import type { AdminCommand, AdminMutationResult } from "./contracts";
import { guardianCapabilityKeys } from "./contracts";

export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const statusValues = ["active", "inactive", "pending", "suspended", "archived"];
const person = ["first_name", "middle_name", "last_name", "preferred_name", "display_name", "status"];
const organization = ["name", "legal_name", "slug", "organization_type", "status", "timezone", "country", "default_currency"];
const unit = ["parent_unit_id", "unit_type", "name", "slug", "status", "sort_order"];
const season = ["name", "starts_on", "ends_on", "status"];
const team = ["name", "short_name", "slug", "status", "visibility"];
const household = ["name", "status"];
const flags: readonly string[] = guardianCapabilityKeys;
const guardian = ["authority_status", "ends_at", ...flags];
const operations: Record<string, readonly string[]> = {
  "identity.provision_self": ["display_name"],
  "account.link": ["person_id", "auth_user_id"],
  "person.create": person, "person.update": ["id", ...person],
  "organization.create": organization, "organization.update": ["id", ...organization],
  "module.set": ["organization_id", "module_id", "status"],
  "unit.create": ["organization_id", ...unit], "unit.update": ["id", ...unit],
  "season.create": ["organization_id", "parent_unit_id", ...season], "season.update": ["id", ...season],
  "team.create": ["organization_id", "parent_unit_id", "season_id", ...team], "team.update": ["id", ...team],
  "household.create": household, "household.update": ["id", ...household],
  "participant.create": ["person_id", "participant_type", "status", "organization_id"],
  "participant.update": ["id", "participant_type", "status", "organization_id"],
  "household_membership.add": ["household_id", "person_id", "relationship_type", "starts_at", "is_primary_contact", "status", "ends_at"],
  "household_membership.update": ["id", "is_primary_contact", "status", "ends_at"],
  "guardian.create": ["guardian_person_id", "dependent_person_id", "relationship_type", "starts_at", ...guardian],
  "guardian.update": ["id", ...guardian], "guardian.verify": ["id"],
  "organization_membership.add": ["organization_id", "person_id", "membership_type", "starts_at", "status", "ends_at"],
  "organization_membership.update": ["id", "status", "ends_at"],
  "team_membership.add": ["team_id", "person_id", "participant_id", "membership_type", "starts_at", "status", "ends_at", "jersey_number", "position_label"],
  "team_membership.update": ["id", "status", "ends_at", "jersey_number", "position_label"],
  "role_assignment.add": ["person_id", "role_id", "scope_type", "scope_id", "organization_id", "starts_at", "status", "ends_at"],
  "role_assignment.update": ["id", "status", "ends_at"],
};
const referenceNames = /^[a-z][a-z0-9_]{0,31}$/;
const ownKeys = (value: object, keys: readonly string[]) => Object.keys(value).every((key) => keys.includes(key));
export const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

export function parseAdminInput(value: unknown): { commands: AdminCommand[]; request_id: string } | null {
  if (!isObject(value) || !ownKeys(value, ["commands", "request_id"]) ||
    typeof value.request_id !== "string" || !uuidPattern.test(value.request_id) ||
    !Array.isArray(value.commands) || value.commands.length < 1 || value.commands.length > 12) return null;
  const earlierRefs = new Set<string>();
  for (const command of value.commands) {
    if (!isObject(command) || !ownKeys(command, ["operation", "input", "ref"]) ||
      typeof command.operation !== "string" || !Object.hasOwn(operations, command.operation) || !isObject(command.input)) return null;
    if (command.ref !== undefined && (typeof command.ref !== "string" || !referenceNames.test(command.ref) || earlierRefs.has(command.ref))) return null;
    if (!ownKeys(command.input, operations[command.operation])) return null;
    for (const [key, field] of Object.entries(command.input)) {
      if (key === "id" || key.endsWith("_id")) {
        if (field === null && key !== "id") continue;
        if (typeof field === "string" && uuidPattern.test(field)) continue;
        if (isObject(field) && ownKeys(field, ["$ref"]) && typeof field.$ref === "string" && earlierRefs.has(field.$ref)) continue;
        return null;
      }
      if (flags.includes(key) || key === "is_primary_contact") { if (typeof field !== "boolean") return null; continue; }
      if (key === "sort_order") { if (typeof field !== "number" || !Number.isInteger(field) || Math.abs(field) > 1_000_000) return null; continue; }
      if (field === null) continue;
      if (typeof field !== "string" || field.length > 200 || Array.from(field).some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127)) return null;
      if (["status", "authority_status"].includes(key) && !statusValues.includes(field)) return null;
      if (key === "slug" && !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(field)) return null;
      if (key === "visibility" && !["public", "authenticated", "member", "restricted", "private"].includes(field)) return null;
      if (key === "scope_type" && !["platform", "organization", "organization_unit", "team"].includes(field)) return null;
      if ((key.endsWith("_at") || key.endsWith("_on")) && (!/^\d{4}-\d{2}-\d{2}(?:T|$)/.test(field) || !Number.isFinite(Date.parse(field)))) return null;
      if (key === "country" && !/^[A-Z]{2}$/.test(field)) return null;
      if (key === "default_currency" && !/^[A-Z]{3}$/.test(field)) return null;
      if (key === "timezone") { try { new Intl.DateTimeFormat("en", { timeZone: field }); } catch { return null; } }
    }
    if (command.ref) earlierRefs.add(command.ref);
  }
  return value as { commands: AdminCommand[]; request_id: string };
}

export async function readAdminInput(request: Request) {
  if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/json" || !request.body) return null;
  const declared = request.headers.get("content-length");
  if (declared && (!/^\d+$/.test(declared) || Number(declared) > 65_536)) return null;
  const reader = request.body.getReader();
  let length = 0;
  const chunks: Uint8Array[] = [];
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 65_536) { await reader.cancel(); return null; }
      chunks.push(value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return parseAdminInput(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)));
  } catch { return null; } finally { reader.releaseLock(); }
}

const resourceTypes = ["person", "user_account", "organization", "organization_unit", "season", "team", "household", "participant", "household_membership", "guardian_relationship", "organization_membership", "team_membership", "role_assignment", "organization_module"];
export function projectMutationResults(value: unknown): AdminMutationResult[] | null {
  if (!isObject(value) || !Array.isArray(value.results) || value.results.length > 12) return null;
  const results: AdminMutationResult[] = [];
  for (const row of value.results) {
    if (!isObject(row) || typeof row.resource_type !== "string" || !resourceTypes.includes(row.resource_type) ||
      typeof row.resource_id !== "string" || !uuidPattern.test(row.resource_id) ||
      (row.ref !== undefined && (typeof row.ref !== "string" || !referenceNames.test(row.ref)))) return null;
    results.push({ resource_type: row.resource_type, resource_id: row.resource_id, ...(row.ref ? { ref: row.ref } : {}) });
  }
  return results;
}
