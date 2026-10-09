import { adminViews, emptyAdminView, type AdminView, type AdminViewData, type AdminRecord } from "./contracts";
import { isObject, uuidPattern } from "./input";

type AdminReadRequest = { p_view: AdminView; p_organization_id: string | null; p_query: string | null };
type AdminReader = (request: AdminReadRequest) => PromiseLike<{ data: unknown; error: unknown }>;

const collections = ["organizations", "units", "seasons", "teams", "people", "households", "participants", "household_memberships", "guardians", "organization_memberships", "team_memberships", "role_assignments", "roles", "modules", "audit"];
function parseRecords(value: unknown): AdminRecord[] | null {
  if (!Array.isArray(value) || value.length > 100) return null;
  const rows: AdminRecord[] = [];
  for (const row of value) {
    if (!isObject(row) || typeof row.id !== "string" || !uuidPattern.test(row.id) || typeof row.label !== "string" ||
      !isObject(row.fields) || (row.status !== undefined && row.status !== null && typeof row.status !== "string") ||
      (row.operations !== undefined && (!Array.isArray(row.operations) || !row.operations.every((op) => typeof op === "string")))) return null;
    if (!Object.values(row.fields).every((field) => field === null || ["string", "number", "boolean"].includes(typeof field) ||
      (Array.isArray(field) && field.every((item) => typeof item === "string")))) return null;
    rows.push({ id: row.id, label: row.label, ...(typeof row.status === "string" ? { status: row.status } : {}),
      operations: row.operations as string[] | undefined, fields: row.fields as AdminRecord["fields"] });
  }
  return rows;
}
function projectAdminView(value: unknown): AdminViewData | null {
  if (!isObject(value) || typeof value.provisioned !== "boolean" || !Array.isArray(value.operations) ||
    !value.operations.every((op) => typeof op === "string") || !Array.isArray(value.navigation) ||
    !value.navigation.every((view) => adminViews.includes(view) && !["home", "account"].includes(view)) || !isObject(value.records)) return null;
  const organizations = parseRecords(value.organizations);
  if (!organizations || (value.organizationId !== null && (typeof value.organizationId !== "string" || !uuidPattern.test(value.organizationId)))) return null;
  const person = value.person;
  if (person !== null && (!isObject(person) || typeof person.id !== "string" || !uuidPattern.test(person.id) || typeof person.label !== "string")) return null;
  const records: Record<string, AdminRecord[]> = {};
  for (const [key, rows] of Object.entries(value.records)) {
    if (!collections.includes(key)) return null;
    const safe = parseRecords(rows);
    if (!safe) return null;
    records[key] = safe;
  }
  return { provisioned: value.provisioned, person: person as AdminViewData["person"], organizations,
    organizationId: value.organizationId as string | null, operations: value.operations, navigation: value.navigation as AdminViewData["navigation"], records };
}

export async function readAdminView(view: AdminView, read: AdminReader, organizationId?: unknown, query?: unknown): Promise<AdminViewData> {
  const unavailable = () => ({ ...emptyAdminView, unavailable: true });
  if ((organizationId !== undefined && organizationId !== null && organizationId !== "" && (typeof organizationId !== "string" || !uuidPattern.test(organizationId))) ||
    (query !== undefined && (typeof query !== "string" || query.length > 100))) return unavailable();
  try {
    const { data, error } = await read({ p_view: view, p_organization_id: typeof organizationId === "string" && organizationId ? organizationId : null,
      p_query: typeof query === "string" ? query.trim() : null });
    if (error) return isObject(error) && error.code === "PT403" ? { ...emptyAdminView, accessDenied: true } : unavailable();
    return projectAdminView(data) ?? unavailable();
  } catch { return unavailable(); }
}
