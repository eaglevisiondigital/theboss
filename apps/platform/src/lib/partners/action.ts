import { validPartnerReceipt,type PartnerCommand } from "./input";
import { PARTNER_CORRELATION_HEADER,PARTNER_PARENT_HEADER } from "./diagnostics";
import { partnerClientDiagnostic,partnerClientMutationStarted,partnerClientResponse } from "./diagnostics-client";
export type PartnerActionResult={outcome:"confirmed-success";receipt:Record<string,unknown>}|{outcome:"confirmed-rejection"|"unknown"};
// The original command, including request identity, survives unknown confirmation.
export async function requestPartnerMutation(command:PartnerCommand,fetcher:typeof fetch=fetch,reconciling=false):Promise<PartnerActionResult>{
 const trace=partnerClientMutationStarted(command.action,reconciling);
 const diagnostic=(stage:"response_accepted"|"response_rejected"|"unknown_confirmation"|"client_exception",classification:"confirmed-success"|"confirmed-rejection"|"unknown-result"|"invalid-json"|"invalid-receipt",status?:number,error?:unknown)=>partnerClientDiagnostic({stage,classification,operation:command.action,observedAt:"src/lib/partners/action.ts",status,error});
 try{
  const response=await fetcher("/app/partners/mutate",{method:"POST",credentials:"same-origin",headers:{"content-type":"application/json",...(trace?{[PARTNER_PARENT_HEADER]:trace}:{})},body:JSON.stringify(command)});
  partnerClientResponse(response.headers.get(PARTNER_CORRELATION_HEADER),trace,response.status,command.action);
  let body:unknown;
  try{body=await response.json();}catch(error){diagnostic("response_rejected","invalid-json",response.status,error);diagnostic("unknown_confirmation","unknown-result",response.status);return {outcome:"unknown"};}
  if(typeof body==="object"&&body!==null&&"ok"in body&&body.ok===true){const receipt={...body};delete(receipt as {ok?:unknown}).ok;
   if(response.ok&&validPartnerReceipt(receipt)){diagnostic("response_accepted","confirmed-success",response.status);return {outcome:"confirmed-success",receipt};}
   diagnostic("response_rejected","invalid-receipt",response.status);
  }
  if(!reconciling&&!response.ok&&typeof body==="object"&&body!==null&&"outcome"in body&&body.outcome==="rejected"){
   diagnostic("response_rejected","confirmed-rejection",response.status);return {outcome:"confirmed-rejection"};
  }
  diagnostic("unknown_confirmation","unknown-result",response.status);return {outcome:"unknown"};
 }catch(error){diagnostic("client_exception","unknown-result",undefined,error);diagnostic("unknown_confirmation","unknown-result");return {outcome:"unknown"};}
}
