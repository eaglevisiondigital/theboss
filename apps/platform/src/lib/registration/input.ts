import type { Json } from "../supabase/database.types";
import { registrationOperations, emptyRegistrationData, type RegistrationCommand, type RegistrationData, type RegistrationOperation, type RegistrationQuery, type RegistrationRow } from "./contracts";

export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value);
const fields: Record<RegistrationOperation, string[]> = {
  "offering.upsert": ["organization_id", "offering_id", "expected_version", "title", "description", "scope_type", "scope_id", "season_id", "event_id", "registration_type", "participant_type", "opens_at", "closes_at", "capacity", "waitlist_enabled", "approval_required", "visibility", "status", "age_min", "age_max", "grade_min", "grade_max", "team_assignment_policy"],
  "offering.publish": ["offering_id", "expected_version"], "form.publish": ["offering_id", "form_key", "title", "definition", "sensitivity", "required", "sort_order"],
  "waiver.publish": ["offering_id", "waiver_key", "title", "body", "signer_type", "effective_from", "effective_until", "required", "sort_order"],
  "document_requirement.upsert": ["offering_id", "key", "title", "classification", "required", "emergency_access", "allowed_mime_types", "max_bytes", "validity_days", "sort_order"],
  "fee.upsert": ["offering_id", "fee_rule_id", "expected_version", "title", "charge_type", "amount_minor", "currency", "due_on", "required", "status"],
  "coupon.upsert": ["offering_id", "coupon_id", "expected_version", "code", "title", "adjustment_type", "amount_minor", "percent_bps", "max_uses", "opens_at", "closes_at", "status"],
  "registration.configure": ["organization_id", "features"], "registration.start": ["offering_id", "participant_id", "household_id", "context"],
  "registration.save": ["registration_id", "expected_version", "context"], "registration.submit": ["registration_id", "expected_version", "coupon_code"],
  "registration.decision": ["registration_id", "expected_version", "decision", "reason"], "registration.withdraw": ["registration_id", "expected_version", "reason"],
  "registration.eligibility": ["registration_id", "expected_version", "status", "reason"], "registration.assign_team": ["registration_id", "expected_version", "team_id"], "registration.remove_team": ["registration_id", "expected_version", "reason"],
  "form.answer": ["registration_id", "form_version_id", "answers", "finalize", "expected_version"], "form.access": ["registration_id", "form_version_id"], "waiver.sign": ["registration_id", "waiver_version_id", "name", "consent"],
  "document.intent": ["document_id", "mime_type", "size_bytes", "sha256"], "document.complete": ["document_id", "intent_id"],
  "document.review": ["document_id", "expected_version", "status", "reason", "expires_on", "renewal_due_on"], "document.access": ["document_id", "purpose", "team_id"],
  "emergency.save": ["registration_id", "contacts", "medical", "physician", "insurance", "expected_version"], "emergency.access": ["registration_id", "purpose", "team_id"],
  "charge.cancel": ["charge_id", "reason"], "payment_plan.cancel": ["charge_id", "reason"], "charge.create": ["registration_id", "title", "charge_type", "amount_minor", "currency", "due_on"], "charge.adjust": ["charge_id", "amount_minor", "adjustment_type", "reason"],
  "payment.record_offline": ["organization_id", "method", "amount_minor", "currency", "payer_person_id", "received_at", "reference", "note", "allocations"], "payment_plan.create": ["charge_id", "title", "installments"],
};
function finiteJson(value: unknown, depth = 0): value is Json {
  if (depth > 10) return false;
  if (value === null || typeof value === "boolean") return true;
  if (typeof value === "number") return Number.isFinite(value) && Math.abs(value) <= Number.MAX_SAFE_INTEGER;
  if (typeof value === "string") return value.length <= 64_000 && ![...value].some(character => character.charCodeAt(0) < 32 && ![9, 10, 13].includes(character.charCodeAt(0)));
  if (Array.isArray(value)) return value.length <= 100 && value.every(item => finiteJson(item, depth + 1));
  return isRecord(value) && Object.keys(value).length <= 100 && Object.entries(value).every(([key, item]) => /^[a-zA-Z][a-zA-Z0-9_]{0,79}$/.test(key) && finiteJson(item, depth + 1));
}
export function parseRegistrationCommand(value: unknown): RegistrationCommand | null {
  if (!isRecord(value) || Object.keys(value).some(key => !["operation", "input"].includes(key)) || !registrationOperations.includes(value.operation as RegistrationOperation) || !isRecord(value.input) || !finiteJson(value.input)) return null;
  const operation = value.operation as RegistrationOperation; const input = value.input;
  if (Object.keys(input).some(key => !fields[operation].includes(key))) return null;
  for (const [key, field] of Object.entries(input)) {
    if (key.endsWith("_id") && field !== null && (typeof field !== "string" || !uuidPattern.test(field))) return null;
    if (key === "expected_version" && (!Number.isSafeInteger(field) || Number(field) < 1)) return null;
  }
  if (operation === "payment.record_offline" && !["cash", "check"].includes(String(input.method))) return null;
  if (operation === "waiver.sign" && input.consent !== true) return null;
  if (operation === "form.answer" && (!isRecord(input.answers) || typeof input.finalize !== "boolean")) return null;
  if (JSON.stringify(value).length > 131_072) return null;
  return { operation, input };
}
export async function readBoundedJson(request: Request, limit = 131_072): Promise<unknown> {
  if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/json" || !request.body) return null;
  const declared = request.headers.get("content-length"); if (declared && (!/^\d+$/.test(declared) || Number(declared) > limit)) return null;
  const reader = request.body.getReader(); const chunks: Uint8Array[] = []; let length = 0;
  try { for (;;) { const { done, value } = await reader.read(); if (done) break; length += value.byteLength; if (length > limit) { await reader.cancel(); return null; } chunks.push(value); }
    const bytes = new Uint8Array(length); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch { return null; } finally { reader.releaseLock(); }
}
export function parseRegistrationQuery(params: Record<string, string | string[] | undefined>): RegistrationQuery | null {
  if (Object.values(params).some(value => Array.isArray(value))) return null;
  const query: RegistrationQuery = { view: params.view === "admin" ? "admin" : "family" };
  if (params.view && !["admin", "family"].includes(String(params.view))) return null;
  for (const [key, name] of [["org", "organization_id"], ["registration", "registration_id"], ["offering", "offering_id"]] as const) {
    const id = params[key]; if (id) { if (typeof id !== "string" || !uuidPattern.test(id)) return null; query[name] = id; }
  }
  if (params.status) { if (!/^[a-z_]{1,30}$/.test(String(params.status))) return null; query.status = String(params.status); }
  if (params.q) { if (String(params.q).length > 100) return null; query.query = String(params.q); }
  return query;
}
// Read projections discard unknown fields recursively; credentials, sessions and
// private object paths never pass through the ordinary client payload.
const readKeys = new Set(("emergency_access_purpose access_purpose line1 line2 city region postal_code country emergency_record_id submitter_name submitter_person_id emergency_teams can_sign_waivers can_manage_payments display_name preferred_name first_name last_name guardian_person_id guardian_relationship household_membership_id needs_sensitive_access start_at balance adjustment_amount_minor applied_amount_minor balance_due_minor sequence_number uploaded_at event_title date_of_birth id label name title description organization_id organizationId scope_type scope_id unit_id team_id season_id event_id status version version_number operations participant_id participant_name participant_label participant_type person_id household_id household_name submitted_by_person_id submitted_by_name offering_id offering_title registration_type opens_at closes_at capacity waitlist_enabled approval_required visibility age_min age_max grade_min grade_max returning_behavior team_assignment_policy form_status waiver_status document_status payment_status eligibility_status approval_status roster_status assigned_team_id assigned_team_name waitlist_position created_at updated_at submitted_at reviewed_at review_reason form_key waiver_key form_version_id waiver_version_id document_requirement_id requirement_id required sort_order definition fields key type section help options show_if required_if source field op value min max max_length content sensitivity body signer_type effective_from effective_until published_at forms waivers documents fees coupons answers answer submission finalized completed_at signed_at signer_name version_snapshot signature signatures snapshot classification emergency_access allowed_mime_types max_bytes validity_days expires_on renewal_due_on upload_mime_type upload_size_bytes submitted_at reviewed_by_name reason reviewed_at context participant_snapshot family_snapshot offering_snapshot offering registration details charges payments adjustments allocations installments charge_id charge_type original_amount_minor amount_minor adjusted_amount_minor applied_minor paid_minor balance_minor balance_due currency due_on adjustment_type code percent_bps max_uses used_count received_at method reference note installment_number installment_id payment_plan_id plan_id plans payment_plans not_started missing remaining forms_remaining signatures_remaining documents_missing amount_due amount_paid participant_age grade payment_plan_selected travel_team_selected mode require_approval require_payment require_documents require_eligibility parent_unit_id timezone can_register can_sign can_view_documents can_pay participant household is_required consent document_id answer_id waiver_signature_id fees_visible can_manage can_review can_upload can_view can_sign can_submit can_start created_by_person_id" ).split(" "));
function projectValue(value: unknown, depth = 0, answers = false): Json | undefined {
  if (depth > 14) return undefined;
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  if (typeof value === "string") return value.length <= 64_000 ? value : undefined;
  if (Array.isArray(value)) { if (value.length > 100) return undefined; return value.map(item => projectValue(item, depth + 1, answers) ?? null); }
  if (!isRecord(value)) return undefined;
  const result: RegistrationRow = {};
  for (const [key, item] of Object.entries(value)) {
    if (!(readKeys.has(key) || answers && /^[a-z][a-z0-9_]{0,59}$/.test(key))) continue;
    if (/token|password|cookie|session|auth_user|object_name/i.test(key)) continue;
    const field = projectValue(item, depth + 1, key === "answers"); if (field !== undefined) result[key] = field;
  } return result;
}
export function projectRegistrationData(value: unknown): RegistrationData | null {
  if (!isRecord(value) || !isRecord(value.features) || !Array.isArray(value.operations) || !value.operations.every(operation => registrationOperations.includes(operation))) return null;
  const result: RegistrationData = { ...emptyRegistrationData, features: {}, definitions: { forms: [], waivers: [], documents: [], fees: [], coupons: [] } };
  for (const [key, enabled] of Object.entries(value.features)) if (/^[a-z_]{1,60}$/.test(key) && typeof enabled === "boolean") result.features[key] = enabled;
  result.operations = value.operations as RegistrationOperation[];
  for (const key of ["organizations", "offerings", "registrations", "participants", "households", "units", "teams", "seasons", "events"] as const) {
    const collection = value[key] ?? (isRecord(value.scopes) ? value.scopes[key] : undefined) ?? []; if (!Array.isArray(collection) || collection.length > 100 || collection.some(row => !isRecord(row))) return null;
    result[key] = collection.map(row => projectValue(row) as RegistrationRow);
  }
  result.organizationScope = isRecord(value.scopes) && isRecord(value.scopes.organization) ? projectValue(value.scopes.organization) as RegistrationRow : null;
  result.person = isRecord(value.person) ? projectValue(value.person) as RegistrationRow : null;
  result.organizationId = typeof value.organizationId === "string" && uuidPattern.test(value.organizationId) ? value.organizationId : null;
  if (isRecord(value.definitions)) for (const key of ["forms", "waivers", "documents", "fees", "coupons"] as const) {
    const collection = value.definitions[key] ?? []; if (!Array.isArray(collection) || collection.length > 100) return null;
    result.definitions[key] = collection.filter(isRecord).map(row => projectValue(row) as RegistrationRow);
  }
  result.detail = isRecord(value.detail) ? projectValue(value.detail) as RegistrationRow : null;
  return result;
}
export function projectRegistrationResult(value: unknown, requestId: string): RegistrationRow | null {
  if (!isRecord(value) || value.request_id !== requestId || typeof value.resource_id !== "string" || !uuidPattern.test(value.resource_id) || typeof value.resource_type !== "string" || !/^[a-z_]{1,60}$/.test(value.resource_type)) return null;
  const result: RegistrationRow = { request_id: requestId, resource_type: value.resource_type, resource_id: value.resource_id };
  if (typeof value.version === "number" && Number.isSafeInteger(value.version)) result.version = value.version;
  return result;
}
