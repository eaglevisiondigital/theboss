import type { Json } from "../supabase/database.types";
import { discountRecord } from "./contracts";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const secret = /^[a-f0-9]{64}$/;
const fields: Record<string, readonly string[]> = {
 "maintenance.expire": ["limit"],
 "product.create": ["code", "name", "kind"],
 "revision.create": ["product_id", "membership_product_id", "organization_id", "subject_type", "claim_policy", "currency", "price_minor", "term_days", "trial_days", "country", "region", "market", "tier", "organization_credit_minor", "platform_retained_minor", "product_cost_minor", "settlement_policy_id", "sale_channels", "upgrade_from_tiers", "trial_enabled", "gift_enabled", "fulfillment_type", "validity_anchor", "card_validity_days", "starts_at", "ends_at"],
 "revision.status": ["revision_id", "state"], "campaign.configure": ["campaign_id", "revision_id", "trial_enabled", "gift_enabled", "sale_enabled", "ends_at"], "campaign.end": ["binding_id"],
 "trial.start": ["revision_id", "path", "household_id"], "membership.claim": ["claim_secret", "household_id"], "membership.rebuild": ["membership_id"], "membership.status": ["membership_id", "state"], "source.revoke": ["source_id"],
 "batch.create": ["revision_id", "organization_id", "campaign_id", "owner_type", "name", "quantity", "controlled"],
 "cards.assign": ["organization_id", "campaign_id", "fundraiser_id", "card_ids"], "cards.return": ["organization_id", "campaign_id", "fundraiser_id", "card_ids"], "cards.print": ["organization_id", "campaign_id", "fundraiser_id", "card_ids"], "cards.void": ["organization_id", "campaign_id", "fundraiser_id", "card_ids"],
 "card.claim": ["serial", "activation_secret", "household_id"], "card.replace": ["card_id", "replacement_card_id", "reason"], "batch.archive": ["batch_id"],
 "order.create": ["revision_id", "organization_id", "quantity", "method", "path", "household_id", "base_source_id", "email", "address"], "order.cancel": ["order_id"], "order.refund": ["order_id", "item_ids", "reason"],
 "fulfillment.retry": ["order_id"], "fulfillment.status": ["fulfillment_id", "expected_version", "state"],
};
export type DiscountCommand = { action: string; request_id: string; input: Record<string, Json> };
function validField(key: string, value: Json): boolean {
 if (value === null) return false;
 if (key.endsWith("_id")) return typeof value === "string" && uuid.test(value);
 if (key.endsWith("_ids")) return Array.isArray(value) && value.length > 0 && value.length <= 1000 && value.every(v => typeof v === "string" && uuid.test(v)) && new Set(value.map(v => String(v).toLowerCase())).size === value.length;
 if (key === "claim_secret" || key === "activation_secret") return typeof value === "string" && secret.test(value);
 if (key === "path") return typeof value === "string" && /^[a-f0-9]{48}$/.test(value);
 if (key.endsWith("_enabled") || key === "controlled") return typeof value === "boolean";
 if (key.endsWith("_minor") || key.endsWith("_days") || key === "quantity" || key === "expected_version" || key === "limit") return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 && value <= 1_000_000_000;
 if (key === "upgrade_from_tiers") return Array.isArray(value) && value.length > 0 && value.length <= 2 && new Set(value).size === value.length && value.every(v => v === "local" || v === "state");
 if (key === "sale_channels") return Array.isArray(value) && value.length <= 2 && new Set(value).size === value.length && value.every(v => v === "direct" || v === "fundraising");
 if (key === "address") return discountRecord(value) && Object.keys(value).every(k => ["recipient", "line1", "line2", "city", "region", "postal_code", "country"].includes(k)) && Object.values(value).every(v => typeof v === "string" && v.length <= 200);
 if (key.endsWith("_at")) return typeof value === "string" && value.length <= 40 && Number.isFinite(Date.parse(value));
 return typeof value === "string" && value.length > 0 && value.length <= 254 && !Array.from(value).some(c => c.charCodeAt(0) < 32);
}
export function parseDiscountCommand(value: unknown): DiscountCommand | null {
 if (!discountRecord(value) || Object.keys(value).some(k => !["action", "request_id", "input"].includes(k)) || typeof value.action !== "string" || !Object.hasOwn(fields, value.action) || typeof value.request_id !== "string" || !uuid.test(value.request_id) || !discountRecord(value.input)) return null;
 const input = value.input; if (Object.keys(input).length === 0 || Object.entries(input).some(([k, v]) => !fields[value.action as string].includes(k) || !validField(k, v))) return null;
 return { action: value.action, request_id: value.request_id, input };
}
export function discountsQuery(value: Record<string, string | string[] | undefined>): Record<string, Json> | null {
 const query: Record<string, Json> = { mode: value.view === "organization" ? "organization" : value.view === "fundraiser" ? "fundraiser" : "consumer" };
 for (const [input, output] of [["org", "organization_id"], ["membership", "membership_id"], ["before", "before"], ["fundraiser", "fundraiser_id"], ["order", "order_id"]]) { const v = value[input]; if (v !== undefined) { if (typeof v !== "string" || !uuid.test(v)) return null; query[output] = v; } }
 if (value.path !== undefined) { if (typeof value.path !== "string" || !/^[a-f0-9]{48}$/.test(value.path)) return null; query.path = value.path; }
 return query;
}
export function parseDiscountPublicCommand(value: unknown, path: string): DiscountCommand | null {
 if (!discountRecord(value) || Object.keys(value).some(k => !["action", "request_id", "input"].includes(k)) || typeof value.action !== "string" || typeof value.request_id !== "string" || !uuid.test(value.request_id) || !discountRecord(value.input) || value.input.path !== path || !/^[a-f0-9]{48}$/.test(path)) return null;
 const allowed = ({ "trial.start": ["path", "revision_id", "display_name", "email"], "gift.claim": ["path", "capability"], "product.claim": ["path", "capability", "item_id"], "product.prepare": ["path", "capability", "revision_id", "organization_id", "quantity", "method", "email", "address"], "product.status": ["path", "capability"] } as Record<string, string[]>)[value.action];
 if (!allowed || Object.entries(value.input).some(([k, v]) => !allowed.includes(k) || (k === "capability" ? typeof v !== "string" || !secret.test(v) : !validField(k, v)))) return null;
 if (value.action === "trial.start" && (!value.input.revision_id || typeof value.input.display_name !== "string" || !value.input.display_name.trim() || value.input.display_name.length > 100)) return null;
 if (value.action !== "trial.start" && !value.input.capability || value.action === "product.claim" && !value.input.item_id || value.action === "product.prepare" && (!value.input.revision_id || !value.input.organization_id || !["card", "ach"].includes(String(value.input.method)) || !Number.isSafeInteger(value.input.quantity) || Number(value.input.quantity) < 1 || Number(value.input.quantity) > 100)) return null;
 return { action: value.action, request_id: value.request_id, input: value.input };
}
