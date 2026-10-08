import { uuid, hasControlCharacters } from "../communications/input";
export type Merchant = { id: string; name: string; status: string; claim_state?: string; description?: string; category?: string; version?: number; website?: string; public_phone?: string; locations?: Location[]; preferred_location_id?: string | null; network_available?: boolean; logo_ref?: string | null };
export type Market = { id: string; country: string; region: string; market: string };
export type Location = { id: string; name: string; address: string; city: string; postal_code: string; timezone: string; market_id?: string; status?: string; version?: number };
export type Terms = { title: string; description: string; offer_type: string; discount_bps?: number; currency?: string; amount_minor?: number; buy_quantity?: number; benefit_quantity?: number; purchase_description?: string; benefit_description?: string; qualification: string; minimum_minor?: number; qualifying_description?: string; exclusions: string; stacking: string; stacking_policy?: string };
export type Offer = { id?: string; revision_id?: string; merchant_id?: string; merchant_name?: string; location_id?: string; location_name?: string; presentation_note?: string; family_id: string; revision?: number; state?: string; terms: Terms; weekly_special: boolean; weekdays: number[]; timezone?: string; local_start?: string | null; local_end?: string | null; starts_at: string; ends_at: string; usage_limit: number | null; reset_period: string; remaining_uses?: number | null; availability?: string; can_redeem?: boolean; can_global_edit?: boolean };
export type Evidence = { id: string; location_id: string; title: string; created_at: string; corrected: boolean };
export type Lead = { id: string; name: string; market_id: string; state: string; source: string; rep_id: string; manager_id: string | null; merchant_id: string | null; version: number; can_reassign?: boolean; activities: { id: string; kind: string; note: string; due_at: string | null }[] };
export type MerchantData = { mode?: string; unavailable?: boolean; restricted?: boolean; items?: Merchant[]; merchants?: Merchant[]; merchant?: Merchant; markets?: Market[]; categories?: { key: string; name: string }[]; availability?: string; locations?: Location[]; offers?: Offer[]; families?: { id: string; usage_limit: number | null; reset_period: string; usage_timezone: string; status: string }[]; claims?: { id: string; state: string; statement: string; person_id: string; created_at: string }[]; assignments?: { id: string; person_id: string; role: string; location_id: string | null; status: string; ends_at: string | null }[]; redemptions?: Evidence[]; history?: Evidence[]; analytics?: { location_id: string; family_id: string; day: string; redemptions: number }[]; leads?: Lead[]; membership_required?: boolean; has_more?: boolean; offers_has_more?: boolean; can_market?: boolean; can_manage?: boolean; can_access?: boolean; can_locations?: boolean; can_offers?: boolean; can_review?: boolean; can_configure?: boolean; can_redeem?: boolean; can_create?: boolean; can_assign?: boolean };
export function record(value: unknown): value is Record<string, unknown> { return value !== null && typeof value === "object" && !Array.isArray(value); }
const text = (value: unknown, max = 1500): value is string => typeof value === "string" && value.length <= max && !hasControlCharacters(value) && !/[<>]/.test(value);
const number = (value: unknown, min = 0) => typeof value === "number" && Number.isSafeInteger(value) && value >= min;
const date = (value: unknown) => typeof value === "string" && value.length <= 40 && Number.isFinite(Date.parse(value));
const optional = (value: unknown, check: (v: unknown) => boolean) => value === undefined || value === null || check(value);
const collection = (value: unknown, check: (v: Record<string, unknown>) => boolean, max = 50) => Array.isArray(value) && value.length <= max && value.every(v => record(v) && check(v));
function privateMaterial(value: unknown, depth = 0): boolean {
 if (depth > 8) return true;
 if (Array.isArray(value)) return value.some(v => privateMaterial(v, depth + 1));
 if (!record(value)) return false;
 return Object.entries(value).some(([k,v]) => /(?:password|credential|session|auth_token|access_token|refresh_token|secret|capability|email|birth|dob|household|guardian|sports|wallet|payment|billing)/i.test(k) || privateMaterial(v, depth + 1));
}
export function validMerchantTerms(v: unknown): v is Terms {
 if (!record(v) || privateMaterial(v) || !text(v.title,120) || !text(v.description) || !text(v.exclusions,1000) || !["none","minimum_amount","item"].includes(String(v.qualification)) || !["none","merchant_promotions","reviewed_policy"].includes(String(v.stacking))) return false;
 if (v.qualification === "minimum_amount" && (!number(v.minimum_minor,1) || typeof v.currency !== "string" || !/^[A-Z]{3}$/.test(v.currency))) return false;
 if (v.qualification === "item" && !text(v.qualifying_description,500) || v.stacking === "reviewed_policy" && !text(v.stacking_policy,500)) return false;
 if (v.offer_type === "percentage_off") return number(v.discount_bps,1) && Number(v.discount_bps) <= 10000 && v.amount_minor === undefined;
 if (v.offer_type === "fixed_amount_off") return number(v.amount_minor,1) && typeof v.currency === "string" && /^[A-Z]{3}$/.test(v.currency) && v.discount_bps === undefined;
 if (v.offer_type === "bogo") return number(v.buy_quantity,1) && number(v.benefit_quantity,1) && text(v.purchase_description,500) && text(v.benefit_description,500) && number(v.discount_bps,1) && Number(v.discount_bps) <= 10000;
 return v.offer_type === "free_item" && number(v.benefit_quantity,1) && text(v.benefit_description,500);
}
const location = (v: Record<string,unknown>) => uuid(v.id) && text(v.name,120) && text(v.address,250) && text(v.city,100) && text(v.postal_code,24) && text(v.timezone,80) && optional(v.market_id,uuid) && optional(v.version,x=>number(x,1));
const merchant = (v: Record<string,unknown>) => uuid(v.id) && text(v.name,120) && optional(v.status,x=>text(x,40)) && optional(v.version,x=>number(x,1)) && optional(v.preferred_location_id,uuid) && optional(v.website,x=>typeof x === "string" && /^https:\/\/[^\s<>]+$/.test(x)) && (v.locations === undefined || collection(v.locations,location,30));
const evidence = (v: Record<string,unknown>) => uuid(v.id) && uuid(v.location_id) && text(v.title,120) && date(v.created_at) && typeof v.corrected === "boolean";
export function validMerchantData(value: unknown): value is MerchantData {
 if (!record(value) || privateMaterial(value)) return false;
 for (const [k,v] of Object.entries(value)) if ((k.startsWith("can_") || ["restricted","unavailable","membership_required","has_more","offers_has_more"].includes(k)) && typeof v !== "boolean") return false;
 const shapes: Record<string,(v: Record<string,unknown>)=>boolean> = {
 items: merchant,merchants:merchant,locations:location,
 markets:v=>uuid(v.id) && text(v.country,2) && text(v.region,80) && text(v.market,100),
 categories:v=>typeof v.key === "string" && /^[a-z][a-z0-9_]{1,39}$/.test(v.key) && text(v.name,80),
 offers:v=>uuid(v.family_id) && (uuid(v.id) || uuid(v.revision_id)) && optional(v.id,uuid) && optional(v.revision_id,uuid) && optional(v.merchant_id,uuid) && optional(v.location_id,uuid) && validMerchantTerms(v.terms) && date(v.starts_at) && date(v.ends_at) && typeof v.weekly_special === "boolean" && Array.isArray(v.weekdays) && v.weekdays.length <= 7 && v.weekdays.every(x=>number(x) && x<=6) && (v.usage_limit === null || number(v.usage_limit,1)) && ["lifetime","promotion","weekly","monthly"].includes(String(v.reset_period)) && optional(v.remaining_uses,x=>number(x)) && optional(v.can_redeem,x=>typeof x === "boolean") && optional(v.can_global_edit,x=>typeof x === "boolean"),
 families:v=>uuid(v.id) && (v.usage_limit === null || number(v.usage_limit,1)) && text(v.reset_period,20) && text(v.usage_timezone,80) && text(v.status,20),
 claims:v=>uuid(v.id) && uuid(v.person_id) && text(v.state,20) && text(v.statement,1200) && date(v.created_at),
 assignments:v=>uuid(v.id) && uuid(v.person_id) && text(v.role,40) && optional(v.location_id,uuid) && optional(v.ends_at,date) && text(v.status,20),
 redemptions:evidence,history:evidence,
 analytics:v=>uuid(v.location_id) && uuid(v.family_id) && date(v.day) && number(v.redemptions),
 leads:v=>uuid(v.id) && text(v.name,120) && uuid(v.market_id) && uuid(v.rep_id) && optional(v.manager_id,uuid) && optional(v.merchant_id,uuid) && text(v.state,20) && text(v.source,120) && number(v.version,1) && collection(v.activities,a=>uuid(a.id) && text(a.kind,30) && text(a.note,1200) && optional(a.due_at,date),10)
 };
 for (const [k,check] of Object.entries(shapes)) if (value[k] !== undefined && !collection(value[k],check)) return false;
 return value.merchant === undefined || record(value.merchant) && merchant(value.merchant) && text(value.merchant.status,40);
}
export function validMerchantReceipt(value: unknown, action: string): value is Record<string,unknown> {
 if (!record(value) || privateMaterial(value) || value.action !== action || typeof value.replayed !== "boolean") return false;
 const allowed = ["action","replayed","market_id","merchant_id","resource_id","version","lead_id","intent_id","expires_at","redemption_id","correction_id","valid","title","terms","remaining_uses"];
 if (Object.keys(value).some(k=>!allowed.includes(k))) return false;
 return Object.entries(value).every(([k,v])=>k.endsWith("_id") ? uuid(v) : k==="terms" ? validMerchantTerms(v) : k==="expires_at" ? date(v) : k==="version" ? number(v,1) : k==="remaining_uses" ? v===null || number(v) : k==="valid" ? v===true : true);
}
