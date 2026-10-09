import "server-only";
import { createClient } from "../supabase/server";
import { validAdminData,type PartnerAdminData } from "./contracts";
import {emitPartnerDiagnostic,validPartnerCorrelation,type PartnerDiagnosticInput}from"./diagnostics";
export async function loadPartners(providerId?:string,correlationId?:string):Promise<PartnerAdminData> {
 const diagnostic=(stage:PartnerDiagnosticInput["stage"],extra:Partial<Pick<PartnerDiagnosticInput,"classification"|"error"|"status">>={})=>{if(validPartnerCorrelation(correlationId))emitPartnerDiagnostic({correlationId,stage,phase:"server-component",observedAt:"src/lib/partners/data.ts",operation:"partners.read",...extra});};
 diagnostic("read_started");
 try {const client=await createClient(),{data,error,status}=await client.rpc("boss_partners_read",{query:{mode:"admin",...(providerId?{provider_id:providerId}:{})}});
 if(error){diagnostic("read_failed",{status,classification:error.code==="PT403"?"scope-denied":"upstream-unavailable",error});return {unavailable:true,restricted:error.code==="PT403"};}
 if(!validAdminData(data)){diagnostic("contract_rejected",{status,classification:"contract-rejected"});return {unavailable:true};}
 diagnostic("read_completed",{status});return data;
 }catch(error){diagnostic("read_failed",{classification:"upstream-unavailable",error});return {unavailable:true};}
}
