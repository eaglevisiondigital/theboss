import type { Json } from "../supabase/database.types";
import { isSameOriginPost } from "../auth/request-security";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { finiteKeys, isRecord } from "../coordination/input";
import { readBoundedJson } from "../communications/input";
import { statUuid, projectStats } from "./input";
import { parseStatAction } from "./action";
export type StatClient = GuardedClient & { rpc(name: "boss_stat_competition_classify" | "boss_stat_rebuild", args: { p_game: string; p_class: string; p_reason: string; p_request: string } | { p_query: Json; p_kind: string; p_after_game?: string }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
function failure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 403 ? "Statistics authority is restricted." : status === 409 ? "Reopen the game before changing sealed eligibility." : status === 422 ? "Review the statistical fields." : "The statistical change could not be confirmed." } }; }
export async function performStatMutation(request: Request, client: StatClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return failure("PT403");
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return failure("PT422");
  const raw = await readBoundedJson(request, 6000);
  if (!isRecord(raw) || !finiteKeys(raw, ["request_id", "action"]) || !statUuid(raw.request_id)) return failure("PT422");
  const action = parseStatAction(raw.action); if (!action) return failure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return failure("PT401");
    const result = action.operation === "classify" ? await client.rpc("boss_stat_competition_classify", { p_game: action.game_id, p_class: action.classification, p_reason: action.reason, p_request: raw.request_id }) : await client.rpc("boss_stat_rebuild", { p_query: action.query, p_kind: "team_season", ...(action.after_game ? { p_after_game: action.after_game } : {}) });
    if (result.error) return failure(result.error.code);
    if (!isRecord(result.data)) return failure();
    if (action.operation === "classify") {
      if (result.data.id !== raw.request_id || result.data.classification !== action.classification || !Number.isSafeInteger(result.data.version) || typeof result.data.replayed !== "boolean") return failure();
      return { status: 200, body: { ok: true, operation: action.operation, replayed: result.data.replayed } };
    }
    if (!projectStats(result.data) || typeof result.data.rebuild_complete !== "boolean" || (result.data.rebuild_cursor !== null && !statUuid(result.data.rebuild_cursor))) return failure();
    return { status: 200, body: { ok: true, operation: action.operation, complete: result.data.rebuild_complete, cursor: result.data.rebuild_cursor } };
  } catch { return failure(); }
}
