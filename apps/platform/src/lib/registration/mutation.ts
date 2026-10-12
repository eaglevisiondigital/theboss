import type { Json } from "../supabase/database.types";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { isSameOriginPost } from "../auth/request-security";
import { isRecord, parseRegistrationCommand, projectRegistrationResult, readBoundedJson, uuidPattern } from "./input";

export type RegistrationMutationClient = {
  auth: Parameters<typeof getVerifiedIdentity>[0]["auth"] & { getUser(): Promise<{ data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown }> };
  rpc(name: "boss_registration_mutate", args: { p_request_id: string; p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
};
export const registrationFailure = (code?: string) => {
  const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422 } as Record<string, number>)[code ?? ""] ?? 503;
  const error = ({ 401: "Please sign in again to continue.", 403: "You do not have permission to make this change.", 409: "This record changed or capacity is unavailable. Refresh and review it.", 422: "Review the fields and requirements, then try again.", 503: "Registration changes are unavailable. Please try again." } as Record<number, string>)[status];
  return { status, body: { ok: false as const, error } };
};
export async function verifiedRegistrationCaller(client: RegistrationMutationClient) {
  const identity = await getVerifiedIdentity(client); if (!identity) return false;
  const { data, error } = await client.auth.getUser(); return !error && data.user?.id === identity.subject && data.user.is_anonymous !== true;
}
export async function performRegistrationMutation(request: Request, client: RegistrationMutationClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return registrationFailure("PT403");
  const envelope = await readBoundedJson(request);
  if (!isRecord(envelope) || Object.keys(envelope).some(key => !["request_id", "command"].includes(key)) || typeof envelope.request_id !== "string" || !uuidPattern.test(envelope.request_id)) return registrationFailure("PT422");
  const command = parseRegistrationCommand(envelope.command);
  if (!command || ["document.intent", "document.complete", "document.access", "form.access", "emergency.access"].includes(command.operation)) return registrationFailure("PT422");
  try {
    if (!await verifiedRegistrationCaller(client)) return registrationFailure("PT401");
    const { data, error } = await client.rpc("boss_registration_mutate", { p_request_id: envelope.request_id, p_command: command });
    if (error) return registrationFailure(error.code);
    const result = projectRegistrationResult(data, envelope.request_id);
    return result ? { status: 200, body: { ok: true as const, result } } : registrationFailure();
  } catch { return registrationFailure(); }
}
