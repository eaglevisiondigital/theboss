export const PARTNER_CAPABILITIES = ["catalog_read","benefit_search","benefit_detail","eligibility_check","external_redirect","coupon_retrieval","reservation_quote","price_recheck","booking_request","booking_status","cancellation","refund_status","commission_report","commission_reconciliation"] as const;
export type PartnerCapability = typeof PARTNER_CAPABILITIES[number];
export const PARTNER_METHODS = ["rest","scheduled_feed","secure_file","hosted_redirect","sso","reservation_flow","mock"] as const;
export type PartnerMethod = typeof PARTNER_METHODS[number];
export const PARTNER_STATES = ["prospect","evaluation","contract_pending","approved","configured","suspended","terminated","archived"] as const;
export type PartnerState = typeof PARTNER_STATES[number];
export type FailureCategory = "activation_disabled" | "provider_unavailable" | "contract_inactive" | "capability_unsupported" | "territory_unsupported" | "stale_catalog" | "invalid_source_record" | "quote_expired" | "malformed_response" | "unknown_outcome" | "rate_limited";
export type Outcome<T> = {ok:true;value:T} | {ok:false;category:FailureCategory};
export type PartnerAccess = {membershipEligible:boolean;territoryEligible:boolean;catalogAvailable:boolean;licensingValid:boolean;providerOperational:boolean;fulfillmentPossible:boolean};
export type PartnerConfiguration = {id:string;revision:number;method:PartnerMethod;capabilities:PartnerCapability[];operational:false;credentials_ready:false};
export type PartnerProvider = {id:string;key:string;name:string;state:PartnerState;version:number;synthetic:boolean;configuration:PartnerConfiguration | Record<string,never>;source_count:number};
export type PartnerAdminDetails={contracts:{id:string;revision:number;document_reference:string;countries:string[];categories:string[];product_id:string;starts_at:string;ends_at:string;display_rights:boolean;caching_rights:boolean;state:string;can_approve:boolean}[];territories:{id:string;country:string;region:string;market_id:string|null;status:string;ends_at:string}[];imports:{id:string;feed_sequence:number;kind:string;accepted:number;quarantined:number;withdrawn:number;created_at:string}[];catalog:{id:string;title:string;source_revision:number;member_terms:string;exclusions:string;ends_at:string;state:string}[]};
export type PartnerAdminData = {operational:false;providers:PartnerProvider[];details?:PartnerAdminDetails|null} | {restricted?:boolean;unavailable:true};
export type BenefitProvenance = {kind:"native";merchantId:string;revisionId:string} | {kind:"partner";providerId:string;sourceId:string;externalId:string;sourceRevision:number;revisionId:string};
export type DiscoveryItem = {id:string;title:string;category:string;marketId:string;provenance:BenefitProvenance;organicRelevance:number;access:PartnerAccess};
export function organicDiscovery(items:readonly DiscoveryItem[]):DiscoveryItem[] {
 return [...items].sort((a,b)=>b.organicRelevance-a.organicRelevance || a.id.localeCompare(b.id));
}
export type FutureSharingPolicy = {protocol:"oidc"|"saml";issuer:string;audience:string;assertionSeconds:number;allowedAttributes:readonly ("subject_pseudonym"|"country"|"membership_tier")[];consentRequired:true;nonceRequired:true;replayProtection:true;independentLogout:true;revocationRequired:true};
export type SecretReadiness = {reference:`partner-vault/${string}` | null;verified:false;operational:false};
export type MinorUnits = string;
export const isRecord=(value:unknown):value is Record<string,unknown>=>typeof value==="object"&&value!==null&&!Array.isArray(value);
export const isUuid=(value:unknown):value is string=>typeof value==="string"&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
export function validAdminData(value:unknown):value is PartnerAdminData {
 if(!isRecord(value)||value.operational!==false||!Array.isArray(value.providers)||value.providers.length>50||Object.keys(value).some(k=>!["operational","providers","details"].includes(k)))return false;
 if(value.details!==undefined&&value.details!==null&&!validDetails(value.details))return false;
 return value.providers.every(p=>isRecord(p)&&isUuid(p.id)&&typeof p.key==="string"&&typeof p.name==="string"&&!/[<>]/.test(p.name)&&PARTNER_STATES.includes(p.state as PartnerState)&&Number.isSafeInteger(p.version)&&Number(p.version)>0&&typeof p.synthetic==="boolean"&&Number.isSafeInteger(p.source_count)&&Number(p.source_count)>=0&&isRecord(p.configuration)&&Object.keys(p).every(k=>["id","key","name","state","version","synthetic","configuration","source_count"].includes(k))&&(Object.keys(p.configuration).length===0||(isUuid(p.configuration.id)&&Number.isSafeInteger(p.configuration.revision)&&Number(p.configuration.revision)>0&&PARTNER_METHODS.includes(p.configuration.method as PartnerMethod)&&p.configuration.operational===false&&p.configuration.credentials_ready===false&&Array.isArray(p.configuration.capabilities)&&p.configuration.capabilities.every((c:unknown)=>PARTNER_CAPABILITIES.includes(c as PartnerCapability))&&Object.keys(p.configuration).every(k=>["id","revision","method","capabilities","operational","credentials_ready"].includes(k)))));
}
export function validMinor(value:unknown):value is MinorUnits {return typeof value==="string"&&/^(0|[1-9][0-9]{0,12})$/.test(value)&&BigInt(value)<=9000000000000n;}
export function currentPartnerAccess(access:PartnerAccess):boolean {return access.membershipEligible&&access.territoryEligible&&access.catalogAvailable&&access.licensingValid&&access.providerOperational&&access.fulfillmentPossible;}

function validDetails(value:unknown):value is PartnerAdminDetails {
 if(!isRecord(value)||Object.keys(value).some(k=>!["contracts","territories","imports","catalog"].includes(k)))return false;
 const keys={contracts:["id","revision","document_reference","countries","categories","product_id","starts_at","ends_at","display_rights","caching_rights","state","can_approve"],territories:["id","country","region","market_id","status","ends_at"],imports:["id","feed_sequence","kind","accepted","quarantined","withdrawn","created_at"],catalog:["id","title","source_revision","member_terms","exclusions","ends_at","state"]};
 const text=(v:unknown,max=2000):v is string=>typeof v==="string"&&v.length<=max&&!/[<>]/.test(v);
 const date=(v:unknown)=>text(v)&&Number.isFinite(Date.parse(v));
 const count=(v:unknown)=>Number.isSafeInteger(v)&&Number(v)>=0;
 const strings=(v:unknown)=>Array.isArray(v)&&v.length<=100&&v.every(x=>text(x,120));
 return Object.entries(keys).every(([group,fields])=>Array.isArray(value[group])&&value[group].length<=50&&value[group].every((r:unknown)=>{
  if(!isRecord(r)||!isUuid(r.id)||!fields.every(k=>Object.hasOwn(r,k))||Object.keys(r).some(k=>!fields.includes(k)))return false;
  if(group==="contracts")return count(r.revision)&&Number(r.revision)>0&&text(r.document_reference,200)&&strings(r.countries)&&strings(r.categories)&&isUuid(r.product_id)&&date(r.starts_at)&&date(r.ends_at)&&Date.parse(r.ends_at as string)>Date.parse(r.starts_at as string)&&typeof r.display_rights==="boolean"&&typeof r.caching_rights==="boolean"&&typeof r.can_approve==="boolean"&&["pending","approved","suspended","terminated"].includes(String(r.state));
  if(group==="territories")return text(r.country,2)&&/^[A-Z]{2}$/.test(r.country)&&text(r.region,80)&&(r.market_id===null||isUuid(r.market_id))&&["active","ended"].includes(String(r.status))&&date(r.ends_at);
  if(group==="imports")return count(r.feed_sequence)&&["full","delta"].includes(String(r.kind))&&count(r.accepted)&&count(r.quarantined)&&count(r.withdrawn)&&date(r.created_at);
  return text(r.title,120)&&count(r.source_revision)&&Number(r.source_revision)>0&&text(r.member_terms)&&text(r.exclusions,1500)&&date(r.ends_at)&&["pending","reviewed","paused","rejected"].includes(String(r.state));
 }));
}
