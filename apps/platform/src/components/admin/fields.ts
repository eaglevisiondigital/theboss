import type { AdminField, AdminRecord, AdminViewData, FormOption } from "./types";

export const lifecycle: FormOption[] = ["active", "inactive", "pending", "suspended", "archived"].map((value) => ({ value, label: value[0].toUpperCase() + value.slice(1) }));

export function options(records: AdminRecord[] | undefined): FormOption[] {
  return (records ?? []).map((record) => ({ value: record.id, label: record.label }));
}

export function text(name: string, label: string, required = false, hint?: string): AdminField {
  return { name, label, required, hint };
}

export function select(name: string, label: string, records: AdminRecord[] | undefined, required = true): AdminField {
  return { name, label, type: "select", required, options: options(records) };
}

export function status(name = "status"): AdminField {
  return { name, label: "Status", type: "select", required: true, options: lifecycle, value: "active" };
}

export const personFields: AdminField[] = [text("first_name", "First name"), text("middle_name", "Middle name"), text("last_name", "Last name"), text("preferred_name", "Preferred name"), text("display_name", "Display name", true), status()];
export const organizationFields: AdminField[] = [
  text("name", "Organization name", true), text("legal_name", "Legal name"),
  { ...text("slug", "Slug", true, "Lowercase letters and numbers separated by hyphens."), placeholder: "controlled-test-organization" },
  text("organization_type", "Organization type", true),
  { ...text("timezone", "Timezone", true), value: "America/Chicago", hint: "Use a named timezone such as America/Chicago." },
  { ...text("country", "Country code", true), value: "US", maxLength: 2 },
  { ...text("default_currency", "Currency code", true), value: "USD", maxLength: 3 }, status(),
];
export const guardianFlags: AdminField[] = [
  { name: "can_manage_fundraising", label: "Fundraising capability", type: "checkbox", value: false, hint: "Permits accepting and sharing this dependent’s fundraiser only with current campaign and participant eligibility." },
  { name: "can_manage_profile", label: "Manage dependent profile", type: "checkbox", hint: "Permits approved non-sensitive profile changes." },
  { name: "can_register", label: "Registration capability", type: "checkbox" },
  { name: "can_sign_waivers", label: "Waiver capability", type: "checkbox" },
  { name: "can_view_documents", label: "Document capability", type: "checkbox" },
  { name: "can_manage_payments", label: "Payment capability", type: "checkbox" },
  { name: "can_respond_attendance", label: "Attendance response capability", type: "checkbox", value: false, hint: "Permits RSVP only for this dependent when current event, team and attendance policy also authorize it." },
];
export function windowFields(includeStart = true): AdminField[] {
  return [...(includeStart ? [{ name: "starts_at", label: "Starts at", type: "datetime-local" as const }] : []), { name: "ends_at", label: "Ends at", type: "datetime-local" }];
}

export function unitFields(data: AdminViewData): AdminField[] {
  return [text("name", "Unit name", true), text("slug", "Slug", true),
    { name: "unit_type", label: "Unit type", required: true, type: "select", options: ["sport", "program", "campus", "location", "division", "other"].map((value) => ({ value, label: value[0].toUpperCase() + value.slice(1) })) },
    select("parent_unit_id", "Parent unit", data.records.units, false),
    { name: "sort_order", label: "Display order", type: "number", value: 0 }, status()];
}

export function seasonFields(data: AdminViewData, edit = false): AdminField[] {
  return [text("name", "Season name", true), ...(edit ? [] : [select("parent_unit_id", "Organization unit", data.records.units, false)]),
    { name: "starts_on", label: "Starts on", type: "date" }, { name: "ends_on", label: "Ends on", type: "date" }, status()];
}

export function teamFields(data: AdminViewData, edit = false): AdminField[] {
  return [text("name", "Team name", true), text("short_name", "Short name"), text("slug", "Slug", true),
    ...(edit ? [] : [select("parent_unit_id", "Organization unit", data.records.units, false), select("season_id", "Season", data.records.seasons, false)]),
    { name: "visibility", label: "Visibility", type: "select", required: true, value: "private", options: ["private", "restricted", "member", "authenticated", "public"].map((value) => ({ value, label: value[0].toUpperCase() + value.slice(1) })), hint: "Visibility is a foundation setting. It does not publish a team or grant access." }, status()];
}

export function editFields(fields: AdminField[], record: AdminRecord): AdminField[] {
  return fields.map((field) => {
    const value = record.fields[field.name];
    const existingOption = field.type === "select" && typeof value === "string" && value && !field.options?.some((option) => option.value === value)
      ? [{ value, label: field.name.endsWith("_id") ? "Existing scoped record" : value }] : [];
    return { ...field, options: field.type === "select" ? [...(field.options ?? []), ...existingOption] : undefined, value: field.type === "datetime-local" && typeof value === "string" ? localDateTime(value) : Array.isArray(value) ? undefined : value ?? (field.name === "status" ? record.status : undefined) };
  });
}

function localDateTime(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "";
  const offset = parsed.getTimezoneOffset() * 60000;
  return new Date(parsed.getTime() - offset).toISOString().slice(0, 16);
}
