import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { validMerchantData, type MerchantData } from "./contracts";
import { emitMerchantDiagnostic, validMerchantCorrelation, type MerchantDiagnosticStage } from "./diagnostics";
export async function loadMerchants(query: Record<string, Json>, directory = false, correlationId?: string): Promise<MerchantData> {
 const diagnostic = (stage: MerchantDiagnosticStage, extra: {error?:unknown;status?:number;classification?:"scope-denied"|"upstream-unavailable"|"contract-rejected"}={}) => {
  if(validMerchantCorrelation(correlationId)) emitMerchantDiagnostic({correlationId,stage,phase:"server-component",observedAt:"src/lib/merchants/data.ts",operation:"merchant.read",...extra});
 };
 diagnostic("read_started");
 try {
  const client = await createClient(), { data, error, status } = await client.rpc(directory ? "boss_merchants_directory" : "boss_merchants_read", { query: directory ? Object.fromEntries(Object.entries(query).filter(([k]) => k !== "mode")) : query });
  if (error) { diagnostic("read_failed",{error,status,classification:error.code==="PT403"?"scope-denied":"upstream-unavailable"});return {restricted:error.code==="PT403",unavailable:error.code!=="PT403"}; }
  if (!validMerchantData(data)) { diagnostic("contract_rejected",{status,classification:"contract-rejected"});return {restricted:false,unavailable:true}; }
  diagnostic("read_completed",{status});return data;
 } catch(error) { diagnostic("read_failed",{error,classification:"upstream-unavailable"});return { unavailable: true }; }
}
