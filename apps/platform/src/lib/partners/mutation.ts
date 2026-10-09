import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller,type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { parsePartnerCommand,validPartnerReceipt } from "./input";
import {emitPartnerDiagnostic,validPartnerCorrelation,type PartnerDiagnosticInput,type PartnerDiagnosticOperation}from"./diagnostics";
export type PartnerClient=GuardedClient&{rpc(name:"boss_partners_mutate",args:{command:Json}):PromiseLike<{data:unknown;error:{code?:string}|null}>};
function failure(code?:string) {const status=({PT401:401,PT403:403,PT404:404,PT409:409,PT422:422,PT429:429} as Record<string,number>)[code??""]??503;return {status,body:{ok:false,outcome:status<500?"rejected":"unknown",error:status===503?"This change could not be confirmed. Retry the same request safely.":"This provider operation is unavailable. Review your access and the current record."}};}
export async function performPartnerMutation(request:Request,client:PartnerClient,origin:string,correlationId?:string,parentCorrelationId?:string|null) {
 const diagnostic=(stage:PartnerDiagnosticInput["stage"],classification:PartnerDiagnosticInput["classification"],operation?:PartnerDiagnosticOperation,status?:number,error?:unknown)=>{if(validPartnerCorrelation(correlationId))emitPartnerDiagnostic({correlationId,parentCorrelationId,route:"/app/partners/mutate",stage,phase:"server-route",observedAt:"src/lib/partners/mutation.ts",classification,operation,status,error});};
 const rejected=(code?:string,operation?:PartnerDiagnosticOperation)=>{const result=failure(code);diagnostic(result.status<500?"response_rejected":"unknown_confirmation",result.status<500?"confirmed-rejection":"unknown-result",operation,result.status);return result;};
 if(!isSameOriginPost(request,origin))return rejected("PT403");
 if(request.headers.get("content-type")?.split(";")[0].trim().toLowerCase()!=="application/json")return rejected("PT422");
 const command=parsePartnerCommand(await readBoundedJson(request,1_048_576));if(!command)return rejected("PT422");
 try {if(!await verifiedCommunicationCaller(client))return rejected("PT401",command.action);
 const {data,error}=await client.rpc("boss_partners_mutate",{command});
 if(error){diagnostic("rpc_failed",failure(error.code).status<500?"confirmed-rejection":"unknown-result",command.action);return rejected(error.code,command.action);}
 diagnostic("rpc_completed","event",command.action);
 if(!validPartnerReceipt(data)){diagnostic("contract_rejected","invalid-receipt",command.action,503);return rejected(undefined,command.action);}
 return {status:200,body:{ok:true,...data}};
 }catch(error){diagnostic("server_exception","unknown-result",command.action,undefined,error);return rejected(undefined,command.action);}
}
