import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { bucksRecord, isBucksReceipt } from "./contracts";
import { parseBucksCommand } from "./input";
export type BucksClient = GuardedClient & { rpc(name: "boss_bucks_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function bucksFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This wallet scope is restricted." : status === 409 ? "This wallet context changed. Refresh and review it." : status === 422 ? "Review the wallet fields." : "The wallet change could not be confirmed. Retry the same request safely." } }; }
export async function performBucksMutation(request: Request, client: BucksClient, origin: string) {
 if (!isSameOriginPost(request, origin)) return bucksFailure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return bucksFailure("PT422");
 const command = parseBucksCommand(await readBoundedJson(request, 8000)); if (!command) return bucksFailure("PT422");
 try { if (!await verifiedCommunicationCaller(client)) return bucksFailure("PT401"); const { data, error } = await client.rpc("boss_bucks_mutate", { command }); if (error) return bucksFailure(error.code); if (!bucksRecord(data) || data.action !== command.action || typeof data.replayed !== "boolean" || command.action.startsWith("payment.") && !isBucksReceipt(data.receipt)) return bucksFailure(); return { status: 200, body: { ok: true, ...data } }; } catch { return bucksFailure(); }
}
