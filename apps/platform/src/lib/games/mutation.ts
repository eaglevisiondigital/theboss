import type { Json } from "../supabase/database.types";
import { isSameOriginPost } from "../auth/request-security";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { readBoundedJson } from "../communications/input";
import { finiteKeys, isRecord, uuid } from "../coordination/input";
import { gameResultMatchesCommand, parseGameCommand, projectGameResult } from "./input";

export type GameClient = GuardedClient & { rpc(name: "boss_games_mutate", args: { p_request_id: string; p_command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function gameFailure(code?: string) {
  const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, PT429: 429 } as Record<string, number>)[code ?? ""] ?? 503;
  const error = ({ 401: "Please sign in again to continue.", 403: "You do not have permission to make this game change.", 409: "The game, schedule or authority changed. Refresh and review it.", 422: "Review the game fields, then try again.", 429: "Please wait before trying again.", 503: "The change could not be confirmed. Retry to safely check the same request." } as Record<number, string>)[status];
  return { status, body: { ok: false as const, error } };
}
export async function performGameMutation(request: Request, client: GameClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return gameFailure("PT403");
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return gameFailure("PT422");
  const input = await readBoundedJson(request, 16_000);
  if (!isRecord(input) || !finiteKeys(input, ["request_id", "command"]) || !uuid(input.request_id)) return gameFailure("PT422");
  const command = parseGameCommand(input.command); if (!command) return gameFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return gameFailure("PT401");
    const { data, error } = await client.rpc("boss_games_mutate", { p_request_id: input.request_id, p_command: command });
    if (error) return gameFailure(error.code);
    const result = projectGameResult(data);
    if (!result || !gameResultMatchesCommand(result, command)) return gameFailure();
    return { status: 200, body: { ok: true as const, result } };
  } catch { return gameFailure(); }
}
