import { createHash, randomBytes } from "node:crypto";
import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import { isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import type { Json } from "../supabase/database.types";
import { parseAthleteProfileCommand } from "./action";
type RpcClient = { rpc(name: "boss_athlete_profile_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export type AthleteProfileClient = GuardedClient & RpcClient;
export function athleteFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT404: 404, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This athlete profile is restricted." : status === 409 ? "The profile changed. Refresh and review it." : status === 422 ? "Review the profile fields." : "The change could not be confirmed. Retry the same request safely." } }; }
export async function performAthleteProfileMutation(request: Request, client: AthleteProfileClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return athleteFailure("PT403"); if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return athleteFailure("PT422");
  const parsed = parseAthleteProfileCommand(await readBoundedJson(request, 34000)); if (!parsed) return athleteFailure("PT422"); let shareToken: string | undefined; let command = parsed;
  if (parsed.action === "share.create") { shareToken = randomBytes(32).toString("base64url"); command = { ...parsed, input: { ...parsed.input, token_digest: createHash("sha256").update(shareToken).digest("hex"), token_prefix: shareToken.slice(0, 8) } }; }
  try { if (!await verifiedCommunicationCaller(client)) return athleteFailure("PT401"); const { data, error } = await client.rpc("boss_athlete_profile_mutate", { command }); if (error) return athleteFailure(error.code); if (!isRecord(data) || data.contract !== "athlete-profiles-v1" || data.action !== parsed.action || typeof data.replayed !== "boolean" || !statUuid(data.profile_id)) return athleteFailure(); return { status: 200, body: { ok: true, action: parsed.action, profile_id: data.profile_id, replayed: data.replayed, ...(shareToken ? { share_url: `/recruiting/${shareToken}` } : {}) } }; } catch { return athleteFailure(); }
}
