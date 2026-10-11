import { emitFundraisingDiagnostic, type FundraisingTrace } from "../fundraising/diagnostics";
import "server-only";
import { createClient } from "../supabase/server";
import type { AllocationQuery } from "./contracts";
import { safeAllocationData } from "./contracts";
import type { FundraisingAllocationProposalFunctions } from "./database.types";
type AllocationReader = { rpc(name: "boss_fundraising_allocation_read", args: FundraisingAllocationProposalFunctions["boss_fundraising_allocation_read"]["Args"]): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
async function loadAllocationImpl(query: AllocationQuery) {
 try { const client = await createClient() as unknown as AllocationReader, { data, error } = await client.rpc("boss_fundraising_allocation_read", { query });
  return { data: error ? null : safeAllocationData(data), restricted: error?.code === "PT403" };
 } catch { return { data: null, restricted: false }; }
}

export async function loadAllocation(query: AllocationQuery, trace?: FundraisingTrace) {
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:"read_started",observedAt:"src/lib/fundraising-allocation/data.ts",operation:"allocation.read"});
 const result=await loadAllocationImpl(query);
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:result.data?"read_completed":"read_failed",observedAt:"src/lib/fundraising-allocation/data.ts",operation:"allocation.read",classification:result.data?"event":result.restricted?"scope-denied":"upstream-unavailable"});
 return result;
}
