import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import type { Json } from "../supabase/database.types";
import { parseAchievementCommand } from "./input";
type AchievementRpc = { rpc(name: "boss_achievement_mutate", args: { p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export type AchievementClient = GuardedClient & AchievementRpc;
export function achievementFailure(code?: string) {
  const status = ({ PT401: 401, PT403: 403, PT404: 404, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503;
  return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This recognition scope is restricted." : status === 409 ? "The recognition changed. Refresh and review it." : status === 422 ? "Review the recognition fields." : "The change could not be confirmed. Retry the same request safely." } };
}
export async function performAchievementMutation(request: Request, client: AchievementClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return achievementFailure("PT403");
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return achievementFailure("PT422");
  const command = parseAchievementCommand(await readBoundedJson(request, 34000));
  if (!command) return achievementFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return achievementFailure("PT401");
    const { data, error } = await client.rpc("boss_achievement_mutate", { p_command: command });
    if (error) return achievementFailure(error.code);
    if (!isRecord(data) || data.contract !== "achievements-v1" || data.action !== command.action || !statUuid(data.id) || typeof data.replayed !== "boolean") return achievementFailure();
    return { status: 200, body: { ok: true, action: command.action, id: data.id, replayed: data.replayed, has_more: data.has_more === true, ...(typeof data.state === "string" ? { state: data.state } : {}) } };
  } catch { return achievementFailure(); }
}
