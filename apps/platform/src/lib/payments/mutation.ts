import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { parsePaymentCommand, paymentRecord } from "./input";
export type PaymentClient = GuardedClient & { rpc(name: "boss_payments_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function paymentFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This payment scope is restricted." : status === 409 ? "The payment context changed. Refresh and review it." : status === 422 ? "Review the payment fields." : "The change could not be confirmed. Keep the same request when retrying." } }; }
export async function performPaymentMutation(request: Request, client: PaymentClient, origin: string) {
 if (!isSameOriginPost(request, origin)) return paymentFailure("PT403");
 const command = parsePaymentCommand(await readBoundedJson(request, 8000)); if (!command) return paymentFailure("PT422");
 try { if (!await verifiedCommunicationCaller(client)) return paymentFailure("PT401"); const { data, error } = await client.rpc("boss_payments_mutate", { command });
  if (error) return paymentFailure(error.code); if (!paymentRecord(data)) return paymentFailure();
  const result = Object.fromEntries(Object.entries(data).filter(([k]) => ["action", "id", "checkout_id", "refund_id", "operation_id", "state", "replayed", "principal_minor", "bucks_minor", "external_minor", "expires_at"].includes(k)));
  return { status: 200, body: { ok: true, ...result } };
 } catch { return paymentFailure(); }
}
