import { isSameOriginPost } from "../auth/request-security";
import { registrationFailure, verifiedRegistrationCaller, type RegistrationMutationClient } from "./mutation";
import { isRecord, parseRegistrationCommand, readBoundedJson, uuidPattern } from "./input";
import type { RegistrationRow } from "./contracts";

// Sensitive data is returned only in an explicitly requested, audited POST.
// Ordinary page projections contain neither medical answers nor emergency data.
export async function performSensitiveAccess(request: Request, client: RegistrationMutationClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return registrationFailure("PT403");
  const input = await readBoundedJson(request, 8192);
  if (!isRecord(input) || Object.keys(input).some(key => !["command", "request_id"].includes(key)) || typeof input.request_id !== "string" || !uuidPattern.test(input.request_id)) return registrationFailure("PT422");
  const command = parseRegistrationCommand(input.command);
  if (!command || !["form.access", "emergency.access"].includes(command.operation)) return registrationFailure("PT422");
  try {
    if (!await verifiedRegistrationCaller(client)) return registrationFailure("PT401");
    const { data, error } = await client.rpc("boss_registration_mutate", { p_request_id: input.request_id, p_command: command });
    if (error) return registrationFailure(error.code);
    if (!isRecord(data) || data.request_id !== input.request_id || typeof data.resource_id !== "string" || !uuidPattern.test(data.resource_id)) return registrationFailure();
    const result: RegistrationRow = {};
    if (command.operation === "form.access") {
      if (!isRecord(data.definition) || !Array.isArray(data.definition.fields) || !isRecord(data.answers) && data.answers !== null) return registrationFailure();
      // Definitions/answers were validated by the published form DSL in PostgreSQL.
      // Never project RPC context, actor credentials or unknown response fields.
      result.definition = data.definition as RegistrationRow; result.answers = (data.answers ?? {}) as RegistrationRow;
      for (const key of ["form_version_id", "status", "completed_at"]) if (typeof data[key] === "string") result[key] = data[key];
      if (typeof data.version === "number") result.version = data.version;
    } else {
      if (!Array.isArray(data.contacts) || data.contacts.length > 10 || !isRecord(data.medical) || !isRecord(data.physician)) return registrationFailure();
      const clean = (value: Record<string, unknown>, keys: string[]) => Object.fromEntries(keys.flatMap(key => typeof value[key] === "string" && value[key].length <= 2000 ? [[key, value[key]]] : [])) as RegistrationRow;
      result.contacts = data.contacts.filter(isRecord).map(value => clean(value, ["name", "relationship", "phone", "email"]));
      result.medical = clean(data.medical, ["allergies", "conditions", "medications", "instructions"]);
      result.physician = clean(data.physician, ["name", "phone"]);
      if (command.input.purpose === "ordinary" && isRecord(data.insurance)) result.insurance = clean(data.insurance, ["provider", "policy_reference"]);
      if (typeof data.version === "number" && Number.isSafeInteger(data.version)) result.version = data.version;
    }
    return { status: 200, body: { ok: true as const, result } };
  } catch { return registrationFailure(); }
}
