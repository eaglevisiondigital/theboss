import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { parsePaymentCommand, paymentRecord } from "./input";
import { emitFundraisingDiagnostic, fundraisingResult, type FundraisingOperation, type FundraisingTrace } from "../fundraising/diagnostics";
export type PaymentClient = GuardedClient & { rpc(name: "boss_payments_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function paymentFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, error: status === 401 ? "Please sign in again." : status === 403 ? "This payment scope is restricted." : status === 409 ? "The payment context changed. Refresh and review it." : status === 422 ? "Review the payment fields." : "The change could not be confirmed. Keep the same request when retrying." } }; }
export async function performPaymentMutation(request: Request, client: PaymentClient, origin: string, trace?: FundraisingTrace) {
 let operation: FundraisingOperation = "payments.command";
 const finish = <T extends { status: number; body: object }>(result: T) => { fundraisingResult(trace, operation, result.status, "src/lib/payments/mutation.ts");return result; };
 if (!isSameOriginPost(request, origin)) return finish(paymentFailure("PT403"));
 const command = parsePaymentCommand(await readBoundedJson(request, 8000)); if (!command) return finish(paymentFailure("PT422"));
 operation = command.action === "policy.create" ? "payments.policy.authorize" : "payments.command";
 try { if (!await verifiedCommunicationCaller(client)) return finish(paymentFailure("PT401"));
  if (trace) emitFundraisingDiagnostic({ ...trace, phase: "server-route", stage: "mutation_started", observedAt: "src/lib/payments/mutation.ts", operation });
  const { data, error } = await client.rpc("boss_payments_mutate", { command });
  const result = error ? paymentFailure(error.code) : !paymentRecord(data) ? paymentFailure() : { status: 200, body: { ok: true, ...Object.fromEntries(Object.entries(data).filter(([k]) => ["action", "id", "checkout_id", "refund_id", "operation_id", "state", "replayed", "principal_minor", "bucks_minor", "external_minor", "expires_at"].includes(k))) } };
  if (trace) emitFundraisingDiagnostic({ ...trace, phase: "server-route", stage: error ? "rpc_failed" : "rpc_completed", observedAt: "src/lib/payments/mutation.ts", operation, status: result.status, classification: result.status === 401 || result.status === 403 || result.status === 404 ? "scope-denied" : result.status >= 500 ? "unknown-result" : result.status >= 400 ? "confirmed-rejection" : "confirmed-success" });
  return finish(result);
 } catch (error) { fundraisingResult(trace, operation, 503, "src/lib/payments/mutation.ts", error);return finish(paymentFailure()); }
}
