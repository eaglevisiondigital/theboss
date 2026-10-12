import { emitFundraisingDiagnostic, fundraisingResult, fundraisingCommandOperation, type FundraisingTrace } from "../fundraising/diagnostics";
import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { FundraisingAllocationProposalFunctions } from "./database.types";
import { isRecord, parseAllocationCommand } from "./contracts";
export type AllocationClient = GuardedClient & { rpc(name: "boss_fundraising_allocation_mutate", args: FundraisingAllocationProposalFunctions["boss_fundraising_allocation_mutate"]["Args"]): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
const failure = (code?: string) => ({ status: ({ PT401: 401, PT403: 403, PT409: 409, PT422: 422, "40001": 409, "40P01": 409 } as Record<string, number>)[code ?? ""] ?? 503, body: { ok: false, error: "This allocation change could not be confirmed. Review the scope and reuse the same request when retrying." } });
async function executeMutation(request: Request, client: AllocationClient, origin: string, trace?: FundraisingTrace) {
 if (!isSameOriginPost(request, origin)) return failure("PT403");
 const command = parseAllocationCommand(await readBoundedJson(request, 8192));if (!command) return failure("PT422");
 try {
  if (!await verifiedCommunicationCaller(client)) return failure("PT401");
  if(trace) emitFundraisingDiagnostic({...trace,phase:"server-route",stage:"mutation_started",observedAt:"src/lib/fundraising-allocation/mutation.ts",operation:fundraisingCommandOperation(command.action)}); const { data, error } = await client.rpc("boss_fundraising_allocation_mutate", { command });
  if (error) return failure(error.code);if (!isRecord(data)) return failure();
  return { status: 200, body: { ok: true, ...Object.fromEntries(Object.entries(data).filter(([key]) => ["id", "revision", "action", "replayed", "path", "version"].includes(key))) } };
 } catch (error) { if(trace)emitFundraisingDiagnostic({...trace,phase:"server-route",stage:"server_exception",observedAt:"src/lib/fundraising-allocation/mutation.ts",classification:"exception",error}); return failure(); }
}

export async function performAllocationMutation(request: Request, client: AllocationClient, origin: string, trace?: FundraisingTrace) {
 const result = await executeMutation(request, client, origin, trace);
 fundraisingResult(trace,"policy.authorize",result.status,"src/lib/fundraising-allocation/mutation.ts");
 return result;
}
