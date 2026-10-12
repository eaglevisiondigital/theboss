import type { Json } from "../supabase/database.types";
import { isSameOriginPost } from "../auth/request-security";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { readBoundedJson } from "../communications/input";
import { finiteKeys, isRecord, uuid, projectCoordinationResult } from "./input";

export type CoordinationCommand = { operation: string; input: Record<string, Json | undefined> };
export type CoordinationClient = GuardedClient & { rpc(name: "boss_attendance_mutate" | "boss_volunteers_mutate", args: { p_request_id: string; p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function coordinationFailure(code?: string) {
  const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, PT429: 429 } as Record<string, number>)[code ?? ""] ?? 503;
  const error = ({ 401: "Please sign in again to continue.", 403: "You do not have permission to make this change.", 409: "This record changed, its deadline passed or the shift is full. Refresh and review it.", 422: "Review the fields and times, then try again.", 429: "Please wait before trying again.", 503: "The change could not be confirmed. Retry to safely check the same request." } as Record<number, string>)[status];
  return { status, body: { ok: false as const, error } };
}
export async function performCoordinationMutation(request: Request, client: CoordinationClient, origin: string, resource: "attendance" | "volunteers", parse: (value: unknown) => CoordinationCommand | null) {
  if (!isSameOriginPost(request, origin)) return coordinationFailure("PT403");
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return coordinationFailure("PT422");
  const input = await readBoundedJson(request, 24_000);
  if (!isRecord(input) || !finiteKeys(input, ["request_id", "command"]) || !uuid(input.request_id)) return coordinationFailure("PT422");
  const command = parse(input.command); if (!command) return coordinationFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return coordinationFailure("PT401");
    const { data, error } = await client.rpc(resource === "attendance" ? "boss_attendance_mutate" : "boss_volunteers_mutate", { p_request_id: input.request_id, p_command: command });
    if (error) return coordinationFailure(error.code);
    const result = projectCoordinationResult(data, input.request_id, command.operation);
    return result ? { status: 200, body: { ok: true as const, result } } : coordinationFailure();
  } catch { return coordinationFailure(); }
}
