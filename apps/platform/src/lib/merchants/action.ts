import { record, validMerchantReceipt } from "./contracts";
import type { MerchantCommand } from "./input";
import { MERCHANT_CORRELATION_HEADER, merchantDiagnosticOperation, type MerchantDiagnosticStage, type MerchantDiagnosticInput } from "./diagnostics";
import { merchantClientDiagnostic, merchantClientReceipt } from "./diagnostics-client";
export type MerchantConfirmation = { outcome:"confirmed-success"; receipt:Record<string,unknown> } | { outcome:"confirmed-rejection" | "unknown"; message:string };
const unknown = ():MerchantConfirmation => ({outcome:"unknown",message:"This request could not be confirmed. Retry the same request safely."});
export async function requestMerchantMutation(command:MerchantCommand, transport:typeof fetch=fetch, previouslyUnconfirmed=false):Promise<MerchantConfirmation> {
 const operation=merchantDiagnosticOperation(command.action);
 const diagnostic=(stage:MerchantDiagnosticStage,classification:MerchantDiagnosticInput["classification"],status?:number)=>merchantClientDiagnostic({stage,classification,status,operation,observedAt:"src/lib/merchants/action.ts"});
 let response:Response;
 try { response=await transport("/app/merchants/mutate",{method:"POST",credentials:"same-origin",headers:{"content-type":"application/json"},body:JSON.stringify(command)}); }
 catch { diagnostic("response_not_received","response-lost");return unknown(); }
 merchantClientReceipt(response.headers.get(MERCHANT_CORRELATION_HEADER),response.status,operation);
 let data:unknown;
 try { data=await response.json(); }
 catch { diagnostic(response.ok?"json_rejected":"http_rejected",response.ok?"invalid-json":"http-error",response.status);return unknown(); }
 if(!response.ok) {
  diagnostic("http_rejected","http-error",response.status);
  // A proxy/provider failure is not evidence that the canonical transaction rejected.
  if(record(data) && data.ok===false && data.outcome==="rejected" && response.status>=400 && response.status<500 && typeof data.error==="string" && data.error.length<=250) {
   diagnostic("operation_rejected","confirmed-rejection",response.status);
   if(previouslyUnconfirmed){diagnostic("reconciliation_unavailable","unknown-result",response.status);return {outcome:"unknown",message:"The retry was rejected. The original request is still unconfirmed. Restore access or review its canonical state before another change."};}
   return {outcome:"confirmed-rejection",message:data.error};
  }
  return unknown();
 }
 if(!record(data) || data.ok!==true) { diagnostic("receipt_rejected","invalid-receipt",response.status);return unknown(); }
 const receipt={...data};delete receipt.ok;
 if(!validMerchantReceipt(receipt,command.action)) { diagnostic("receipt_rejected","invalid-receipt",response.status);return unknown(); }
 diagnostic("response_accepted","confirmed-success",response.status);return {outcome:"confirmed-success",receipt};
}
