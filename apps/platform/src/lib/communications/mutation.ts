import type { Json } from "../supabase/database.types";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { isSameOriginPost } from "../auth/request-security";
import { isRecord, parseCommunicationCommand, projectCommunicationResult, readBoundedJson, uuid } from "./input";

export type GuardedClient = { auth: Parameters<typeof getVerifiedIdentity>[0]["auth"] & { getUser(): Promise<{ data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown }> } };
export type CommunicationClient = GuardedClient & { rpc(name: "boss_communications_mutate", args: { p_request_id: string; p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export async function verifiedCommunicationCaller(client: GuardedClient) { const identity = await getVerifiedIdentity(client); if (!identity) return false; const { data, error } = await client.auth.getUser(); return !error && data.user?.id === identity.subject && data.user.is_anonymous !== true; }
export function communicationFailure(code?: string) {
  const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, PT429: 429 } as Record<string, number>)[code ?? ""] ?? 503;
  const error = ({ 401: "Please sign in again to continue.", 403: "You do not have permission to make this change.", 409: "The conversation changed. Refresh and review it.", 422: "Review the message fields and audience, then try again.", 429: "Please wait before sending another message.", 503: "Communications are unavailable. Please try again." } as Record<number, string>)[status];
  return { status, body: { ok: false as const, error } };
}
export async function performCommunicationMutation(request: Request, client: CommunicationClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return communicationFailure("PT403");
  const input = await readBoundedJson(request);
  if (!isRecord(input) || Object.keys(input).some(key => !["request_id", "command"].includes(key)) || !uuid(input.request_id)) return communicationFailure("PT422");
  const command = parseCommunicationCommand(input.command);
  if (!command || command.operation.startsWith("attachment.")) return communicationFailure("PT422");
  try { if (!await verifiedCommunicationCaller(client)) return communicationFailure("PT401"); const { data, error } = await client.rpc("boss_communications_mutate", { p_request_id: input.request_id, p_command: command }); if (error) return communicationFailure(error.code); const result = projectCommunicationResult(data, input.request_id); return result && result.operation === command.operation ? { status: 200, body: { ok: true as const, result } } : communicationFailure(); } catch { return communicationFailure(); }
}
