import type { Json } from "../supabase/database.types";
import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import { parseRankingCommand } from "./action";
export type RankingRpcClient = { rpc(name: "boss_ranking_read" | "boss_ranking_mutate", args: { p_query: Json } | { p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export type RankingClient = GuardedClient & RankingRpcClient;
export function rankingFailure(code?: string) {
  const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503;
  return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This competition or statistical scope is restricted." : status === 409 ? "The scope changed. Refresh and review the request." : status === 422 ? "Review the competition fields." : "The change could not be confirmed. Retry the same request safely." } };
}
export async function performRankingMutation(request: Request, client: RankingClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return rankingFailure("PT403");
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return rankingFailure("PT422");
  const command = parseRankingCommand(await readBoundedJson(request, 18000)); if (!command) return rankingFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return rankingFailure("PT401");
    const { data, error } = await client.rpc("boss_ranking_mutate", { p_command: command });
    if (error) return rankingFailure(error.code);
    if (!isRecord(data) || data.contract !== "rankings-v1" || !statUuid(data.id) || data.action !== command.action || typeof data.replayed !== "boolean" || command.action === "ranking.rebuild" && typeof data.complete !== "boolean") return rankingFailure();
    return { status: 200, body: { ok: true, id: data.id, action: data.action, replayed: data.replayed, ...(typeof data.complete === "boolean" ? { complete: data.complete } : {}) } };
  } catch { return rankingFailure(); }
}
