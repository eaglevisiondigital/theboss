import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { parseFundraisingCommand } from "./input";
import { record } from "./contracts";
export type FundraisingClient = GuardedClient & { rpc(name: string, args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function fundraisingFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT404: 404, PT409: 409, PT422: 422, PT429: 429, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This fundraising scope is restricted." : status === 404 ? "This fundraiser is unavailable." : status === 409 ? "This amount or fundraiser changed. Refresh and review it." : status === 422 ? "Review the fundraising fields." : status === 429 ? "Please try again shortly." : "The change could not be confirmed. Retry the same request safely." } }; }
export async function performFundraisingMutation(request: Request, client: FundraisingClient, origin: string, guest = false, path?: string) {
 if (!isSameOriginPost(request, origin)) return fundraisingFailure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return fundraisingFailure("PT422");
 const command = parseFundraisingCommand(await readBoundedJson(request, 34_000), guest); if (!command || guest && command.input.path !== path) return fundraisingFailure("PT422");
 try { if (!guest && !await verifiedCommunicationCaller(client)) return fundraisingFailure("PT401"); const { data, error } = await client.rpc(guest ? "boss_fundraising_support" : "boss_fundraising_mutate", { command }); if (error) return fundraisingFailure(error.code); if (!record(data) || data.action !== command.action || typeof data.replayed !== "boolean") return fundraisingFailure();
 // Guest response is explicitly projected; no donor, private IDs or capabilities.
 const safe = guest ? Object.fromEntries(Object.entries(data).filter(([k]) => ["action", "state", "ordinal", "amount_minor", "currency", "expires_at", "months", "trial_days", "payment_available", "replayed"].includes(k))) : data;
 return { status: 200, body: { ok: true, ...safe } };
 } catch { return fundraisingFailure(); }
}
