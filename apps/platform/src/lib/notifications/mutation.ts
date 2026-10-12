import { isSameOriginPost } from "../auth/request-security";
import type { Json } from "../supabase/database.types";
import { communicationFailure, verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { isRecord, readBoundedJson, uuid } from "../communications/input";
import { parseNotificationCommand, projectNotificationResult } from "./input";
export type NotificationClient = GuardedClient & { rpc(name: "boss_notifications_mutate", args: { p_request_id: string; p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export async function performNotificationMutation(request: Request, client: NotificationClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return communicationFailure("PT403"); const input = await readBoundedJson(request, 4096);
  if (!isRecord(input) || Object.keys(input).some(key => !["request_id", "command"].includes(key)) || !uuid(input.request_id)) return communicationFailure("PT422"); const command = parseNotificationCommand(input.command); if (!command) return communicationFailure("PT422");
  try { if (!await verifiedCommunicationCaller(client)) return communicationFailure("PT401"); const { data, error } = await client.rpc("boss_notifications_mutate", { p_request_id: input.request_id, p_command: command }); if (error) return communicationFailure(error.code); const result = projectNotificationResult(data, input.request_id); return result && result.operation === command.operation ? { status: 200, body: { ok: true as const, result } } : communicationFailure(); } catch { return communicationFailure(); }
}
