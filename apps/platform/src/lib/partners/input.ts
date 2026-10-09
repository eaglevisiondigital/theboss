import type { Json } from "../supabase/database.types";
import { PARTNER_FIELDS } from "./fields";
import { isRecord,isUuid } from "./contracts";
export type PartnerCommand={request_id:string;action:keyof typeof PARTNER_FIELDS;input:Record<string,Json>};
const noPrivateFields=/password|secret|token|session|credential|medical|child|email|phone|address/i;
export function parsePartnerCommand(value:unknown):PartnerCommand|null {
 if(!isRecord(value)||Object.keys(value).some(k=>!["request_id","action","input"].includes(k))||!isUuid(value.request_id)||typeof value.action!=="string"||!Object.hasOwn(PARTNER_FIELDS,value.action)||!isRecord(value.input))return null;
 const action=value.action as PartnerCommand["action"],allowed:readonly string[]=PARTNER_FIELDS[action];
 if(JSON.stringify(value).length>1_048_576||Object.keys(value.input).some(k=>!allowed.includes(k)))return null;
 if(action!=="provider.create"&&!isUuid(value.input.provider_id))return null;
 for(const [key,item] of Object.entries(value.input)) {
  if(noPrivateFields.test(key)&&key!=="credential_reference")return null;
  if(key==="credential_reference"&&item!==null&&(typeof item!=="string"||!/^partner-vault\/[a-z0-9_-]{3,80}$/.test(item)))return null;
  if(key.endsWith("_id")&&!["external_id","external_event_id"].includes(key)&&item!==null&&!isUuid(item))return null;
  if(typeof item==="string"&&(item.length>2000||(/[<>]/.test(item)||[...item].some(c=>c.charCodeAt(0)<32))))return null;
  if(typeof item==="number"&&(!Number.isSafeInteger(item)||item<0))return null;
  if(Array.isArray(item)) {
   if(item.length>(key==="items"?250:100))return null;
   if(key!=="items"&&item.some(v=>typeof v!=="string"||v.length>120))return null;
  } else if(isRecord(item))return null;
 }
 return value as PartnerCommand;
}
export function validPartnerReceipt(value:unknown):value is Record<string,Json> {
 return isRecord(value)&&isUuid(value.resource_id)&&isUuid(value.provider_id)&&Object.keys(value).every(k=>["resource_id","provider_id","version","accepted","quarantined","withdrawn"].includes(k))&&Object.entries(value).every(([k,v])=>k.endsWith("_id")||typeof v==="number"&&Number.isSafeInteger(v)&&v>=0);
}
