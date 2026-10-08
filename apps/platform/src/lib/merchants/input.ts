import type { Json } from "../supabase/database.types";
import { hasControlCharacters, isRecord, uuid } from "../communications/input";
import { merchantFields, merchantRequired, type MerchantAction } from "./fields";
export type MerchantCommand = { action: MerchantAction; request_id: string; input: Record<string, Json> };
const integers = new Set(["expected_version", "usage_limit", "discount_bps", "amount_minor", "buy_quantity", "benefit_quantity", "minimum_minor"]);
const booleans = new Set(["controlled", "portal", "offers", "redemption", "include_future", "allow_local_pause", "weekly_special", "paused", "favorite", "restore_allowance"]);
export function parseMerchantCommand(value: unknown): MerchantCommand | null {
 if (!isRecord(value) || Object.keys(value).some(k => !["action", "request_id", "input"].includes(k)) || !uuid(value.request_id) || typeof value.action !== "string" || !Object.hasOwn(merchantFields, value.action) || !isRecord(value.input)) return null;
 const action = value.action as MerchantAction, input = value.input, allowed: readonly string[] = merchantFields[action];
 if (merchantRequired[action].some((key: string)=>input[key] === undefined || input[key] === null)) return null;
 if (Object.keys(input).some(k => !allowed.includes(k))) return null;
 for (const [key, item] of Object.entries(input)) {
  if (item === null) { if (!["usage_limit", "discount_bps", "amount_minor", "currency", "buy_quantity", "benefit_quantity", "minimum_minor", "qualifying_description", "purchase_description", "benefit_description", "stacking_policy"].includes(key)) return null; continue; }
  if (key.endsWith("_id") && !uuid(item)) return null;
  if (key === "location_ids" && (!Array.isArray(item) || item.length < 1 || item.length > 100 || item.some(v => !uuid(v)) || new Set(item).size !== item.length)) return null;
  if (key === "weekdays" && (!Array.isArray(item) || item.length < 1 || item.length > 7 || item.some(v => typeof v !== "number" || !Number.isInteger(v) || v < 0 || v > 6) || new Set(item).size !== item.length)) return null;
  if (integers.has(key) && (typeof item !== "number" || !Number.isSafeInteger(item) || item < 1 || item > 1_000_000_000)) return null;
  if (booleans.has(key) && typeof item !== "boolean") return null;
  if (key.endsWith("_at") || key === "period_start" || key === "period_end") { if (typeof item !== "string" || item.length > 40 || !/^\d{4}-\d{2}-\d{2}T/.test(item) || !Number.isFinite(Date.parse(item))) return null; }
  if (typeof item === "string" && (item.length > 1500 || hasControlCharacters(item) || /[<>]/.test(item))) return null;
  if (!["weekdays", "location_ids"].includes(key) && item !== null && !["string", "number", "boolean"].includes(typeof item)) return null;
 }
 if (input.capability !== undefined && (typeof input.capability !== "string" || !/^[a-f0-9]{64}$/.test(input.capability))) return null;
 return { action, request_id: value.request_id, input: input as Record<string, Json> };
}
export function merchantQuery(value: Record<string, string | string[] | undefined>, mode: "consumer" | "portal" | "sales"): Record<string, Json> | null {
 const result: Record<string, Json> = { mode };
 for (const key of ["merchant_id", "location_id", "market_id", "after", "after_location_id", "market_after", "directory_after"]) { const v = value[key]; if (v !== undefined && v !== "") { if (!uuid(v)) return null; result[key] = v; } }
 for (const key of ["category", "search", "market_search", "offer_type"]) { const v = value[key]; if (v !== undefined && v !== "") { if (typeof v !== "string" || v.length > 80 || hasControlCharacters(v) || /[%_<>]/.test(v) && ["search", "market_search"].includes(key)) return null; result[key] = v; } }
 if (value.favorites !== undefined) result.favorites = value.favorites === "true";
 return result;
}

// Paging retains finite discovery filters and never carries a redemption proof.
export function merchantPageLink(query: Record<string, Json>, cursor: Record<string, string | undefined>) {
 const values = new URLSearchParams();
 for (const key of ["merchant_id", "location_id", "market_id", "category", "search", "market_search", "offer_type", "favorites", "after", "after_location_id", "market_after", "directory_after"]) { const value = query[key]; if (typeof value === "string" || typeof value === "boolean") values.set(key, String(value)); }
 for (const [key,value] of Object.entries(cursor)) if (value) values.set(key,value); else values.delete(key);
 return `?${values.toString()}`;
}
