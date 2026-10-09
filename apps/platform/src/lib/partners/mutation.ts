import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller,type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { parsePartnerCommand,validPartnerReceipt } from "./input";
export type PartnerClient=GuardedClient&{rpc(name:"boss_partners_mutate",args:{command:Json}):PromiseLike<{data:unknown;error:{code?:string}|null}>};
function failure(code?:string) {const status=({PT401:401,PT403:403,PT404:404,PT409:409,PT422:422,PT429:429} as Record<string,number>)[code??""]??503;return {status,body:{ok:false,outcome:status<500?"rejected":"unknown",error:status===503?"This change could not be confirmed. Retry the same request safely.":"This provider operation is unavailable. Review your access and the current record."}};}
export async function performPartnerMutation(request:Request,client:PartnerClient,origin:string) {
 if(!isSameOriginPost(request,origin))return failure("PT403");
 if(request.headers.get("content-type")?.split(";")[0].trim().toLowerCase()!=="application/json")return failure("PT422");
 const command=parsePartnerCommand(await readBoundedJson(request,1_048_576));if(!command)return failure("PT422");
 try {if(!await verifiedCommunicationCaller(client))return failure("PT401");
 const {data,error}=await client.rpc("boss_partners_mutate",{command});if(error)return failure(error.code);
 return validPartnerReceipt(data)?{status:200,body:{ok:true,...data}}:failure();
 }catch{return failure();}
}
