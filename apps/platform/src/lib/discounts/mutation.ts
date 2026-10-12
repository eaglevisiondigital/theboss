import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { discountRecord } from "./contracts";
import { parseDiscountCommand, parseDiscountPublicCommand } from "./input";
export type DiscountsClient = GuardedClient & { rpc(name: "boss_discounts_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function discountFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT404: 404, PT409: 409, PT422: 422, PT429: 429, "23514": 422, "22P02": 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This membership or product scope is restricted." : status === 404 ? "This claim or resource is unavailable." : status === 409 ? "This product context changed. Refresh and review it." : status === 422 ? "Review the membership fields." : status === 429 ? "Please try again shortly." : "The membership change could not be confirmed. Retry the same request safely." } }; }
export async function performDiscountMutation(request: Request, client: DiscountsClient, origin: string) {
 if (!isSameOriginPost(request, origin)) return discountFailure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return discountFailure("PT422");
 const command = parseDiscountCommand(await readBoundedJson(request, 256_000)); if (!command) return discountFailure("PT422");
 try { if (!await verifiedCommunicationCaller(client)) return discountFailure("PT401"); const { data, error } = await client.rpc("boss_discounts_mutate", { command }); if (error) return discountFailure(error.code); if (!discountRecord(data) || data.action !== command.action || typeof data.replayed !== "boolean") return discountFailure(); return { status: 200, body: { ok: true, ...data } }; } catch { return discountFailure(); }
}
export type PublicDiscountsClient = { rpc(name: "boss_discounts_support" | "boss_payments_support", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export async function performPublicDiscountMutation(request: Request, client: PublicDiscountsClient, origin: string, path: string) {
 if (!isSameOriginPost(request, origin)) return discountFailure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return discountFailure("PT422");
 const command = parseDiscountPublicCommand(await readBoundedJson(request, 16_000), path); if (!command) return discountFailure("PT422");
 try {
  const rail = ["product.prepare", "product.status"].includes(command.action), input = command.input;
  const { data, error } = await client.rpc(rail ? "boss_payments_support" : "boss_discounts_support", { command: { ...command, input } });
  if (error) return discountFailure(error.code); if (!discountRecord(data)) return discountFailure();
  if (data.claim_secret !== undefined && (typeof data.claim_secret !== "string" || !/^[a-f0-9]{64}$/.test(data.claim_secret))) return discountFailure();
  if (data.items !== undefined && (!Array.isArray(data.items) || data.items.length > 100 || data.items.some(item => !discountRecord(item) || Object.keys(item).some(k => !["item_id","kind","state"].includes(k)) || typeof item.item_id !== "string" || !/^[0-9a-f-]{36}$/i.test(item.item_id) || !["digital","physical","state_upgrade","nationwide_upgrade"].includes(String(item.kind)) || !["pending_claim","claimed","physical_fulfillment"].includes(String(item.state))))) return discountFailure();
  const safe = Object.fromEntries(Object.entries(data).filter(([k]) => ["action", "state", "replayed", "claim_secret", "expires_at", "trial_days", "one_time_claim_unavailable", "checkout_state", "method", "currency", "principal_minor", "items"].includes(k)));
  return { status: 200, body: { ok: true, ...safe } };
 } catch { return discountFailure(); }
}
