import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { validMerchantReceipt } from "./contracts";
import { parseMerchantCommand } from "./input";
import { emitMerchantDiagnostic, validMerchantCorrelation, merchantDiagnosticOperation, type MerchantDiagnosticInput, type MerchantDiagnosticStage } from "./diagnostics";
export type MerchantClient = GuardedClient & { rpc(name: "boss_merchants_mutate", args: { command: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export function merchantFailure(code?: string) { const status = ({ PT401: 401, PT403: 403, PT404: 404, PT409: 409, PT422: 422, PT429: 429, "23514": 422, "23502": 422, "23503": 422, "23505": 409, "22P02": 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503; return { status, body: { ok: false, outcome: status < 500 ? "rejected" : "unknown", error: status === 401 ? "Please sign in again." : status === 403 ? "This merchant, location or membership scope is restricted." : status === 404 ? "This offer or merchant resource is unavailable." : status === 409 ? "This context changed or this redemption was consumed. Refresh and review it." : status === 422 ? "Review the merchant fields." : status === 429 ? "Please try again shortly." : "This merchant change could not be confirmed. Retry the same request safely." } }; }
export async function performMerchantMutation(request: Request, client: MerchantClient, origin: string, correlationId?: string) {
 const diagnostic=(stage:MerchantDiagnosticStage,classification:MerchantDiagnosticInput["classification"],action?:string,status?:number,error?:unknown)=>{if(validMerchantCorrelation(correlationId))emitMerchantDiagnostic({correlationId,stage,phase:"server-route",observedAt:"src/lib/merchants/mutation.ts",classification,operation:action?merchantDiagnosticOperation(action):undefined,status,error});};
 const failure=(code?:string,action?:string)=>{const result=merchantFailure(code);diagnostic(result.status<500?"operation_rejected":"rpc_failed",result.status<500?"confirmed-rejection":"unknown-result",action,result.status);return result;};
 if (!isSameOriginPost(request, origin)) return failure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return failure("PT422");
 const command = parseMerchantCommand(await readBoundedJson(request, 32_000)); if (!command) return failure("PT422");
 try {
  if (!await verifiedCommunicationCaller(client)) return failure("PT401",command.action);
  const { data, error } = await client.rpc("boss_merchants_mutate", { command });
  if (error) return failure(error.code,command.action);
  diagnostic("rpc_completed","event",command.action);
  if (!validMerchantReceipt(data, command.action)) { diagnostic("receipt_rejected","invalid-receipt",command.action,503);return merchantFailure(); }
  diagnostic("mutation_completed","confirmed-success",command.action,200);
  return { status: 200, body: { ok: true, ...data } };
 } catch(error) { diagnostic("server_exception","unknown-result",command.action,undefined,error);return merchantFailure(); }
}
