import type { Json } from "../supabase/database.types";
export type CoverageTier = "local" | "state" | "nationwide";
export type ProductKind = "digital" | "physical" | "state_upgrade" | "nationwide_upgrade";
export type DiscountEffective = { available: boolean; state: string; tier: CoverageTier | null; source: string | null; starts_at: string | null; ends_at: string | null; source_id: string | null; country: string; region: string; market: string };
export type DiscountCard = { id: string; serial: string; state: string; valid?: boolean; batch_id?: string; campaign_id?: string | null; fundraiser_id?: string | null; claimed?: boolean };
export type DiscountMember = { id: string; product_id?: string; household_id?: string | null; display_id: string; name: string; display_name: string | null; subject_type: "person" | "household"; effective: DiscountEffective; base_source_id: string | null; cards: DiscountCard[]; sources: { kind: string; tier: CoverageTier; starts_at: string; ends_at: string; revoked: boolean }[] };
export type DiscountCatalogItem = { revision_id: string; organization_id: string; product_id: string; membership_product_id: string; fulfillment_type: string; name: string; kind: ProductKind; price_minor: number; currency: string; tier: CoverageTier; country: string; region: string; market: string; subject_type: "person" | "household"; term_days: number | null; trial_days: number | null; trial_enabled: boolean; gift_enabled: boolean; sale_enabled: boolean; upgrade_from_tiers: CoverageTier[]; payment_available: boolean };
export type DiscountRevision = { id: string; product_id: string; price_minor: number; currency: string; trial_days: number | null; tier: CoverageTier; term_days: number | null; country: string; region: string; market: string; active: boolean };
export type DiscountData = {
 mode: "consumer" | "organization" | "fundraiser"; households: { id: string; name: string }[]; catalog: DiscountCatalogItem[]; memberships: DiscountMember[];
 products: { id: string; code: string; name: string; kind: ProductKind; status: string }[]; revisions: DiscountRevision[];
 campaigns: { id: string; name: string; status: string }[]; campaign_products: { id: string; campaign_id: string; revision_id: string; trial_enabled: boolean; gift_enabled: boolean; sale_enabled: boolean; status: string }[];
 fundraisers: { id: string; campaign_id: string; name: string }[]; settlement_policies: { id: string; revision: number; currency: string; organization_basis_points: number; platform_basis_points: number; processor_fee_owner: string }[];
 batches: { id: string; name: string; status: string; quantity: number; controlled: boolean; counts: Record<string, number> }[]; cards: DiscountCard[];
 orders: { id: string; state: string; total_minor: number; currency: string; quantity: number; created_at?: string; items?: { id: string; kind: string; price_minor: number; corrected: boolean }[] }[];
 fulfillments: { id: string; state: string; version: number; order_id: string; card_id: string | null; fulfillment_type: string }[];
 can_refund?: boolean; financial_statistics?: { currency: string; digital_sales_minor: number; physical_sales_minor: number; refunded_products_minor: number }[]; can_manage_campaigns: boolean; statistics?: { trials_started: number; gift_sources: number; gift_claimed: number; fundraising_credits: { currency: string; amount_minor: number }[] }; fundraiser_report?: { name: string; currency: string; fundraising_credit_minor: number; product_sales: Record<string, number>; inventory: Record<string, number> }; can_manage_products: boolean; can_inventory: boolean; can_fulfillment: boolean; can_financial_view: boolean; unavailable?: boolean; restricted?: boolean;
};
export const emptyDiscounts: DiscountData = { mode: "consumer", households: [], catalog: [], memberships: [], products: [], revisions: [], campaigns: [], campaign_products: [], fundraisers: [], settlement_policies: [], batches: [], cards: [], orders: [], fulfillments: [], can_manage_campaigns: false, can_manage_products: false, can_inventory: false, can_fulfillment: false, can_financial_view: false };
export function discountRecord(v: unknown): v is Record<string, Json> { return !!v && typeof v === "object" && !Array.isArray(v); }
function privatePayload(v: unknown): boolean { return Array.isArray(v) ? v.some(privatePayload) : !!v && typeof v === "object" && Object.entries(v).some(([key, value]) => /secret|token|credential|password|address|email/i.test(key) || privatePayload(value)); }
export function validDiscountData(v: unknown): v is Partial<DiscountData> & { mode: DiscountData["mode"] } {
 return discountRecord(v) && ["consumer", "organization", "fundraiser"].includes(String(v.mode)) && Array.isArray(v.catalog)
 && ["memberships", "products", "revisions", "campaigns", "campaign_products", "batches", "cards", "orders", "fulfillments"].every(k => v[k] === undefined || Array.isArray(v[k]))
 && !privatePayload(v);
}
export function discountDate(value: string | null | undefined) { if (!value) return "Not active"; const date = new Date(value); return Number.isFinite(date.getTime()) ? date.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" }) : "Unavailable"; }
export function coverageLabel(tier: string | null, country: string, region: string, market: string) { return tier === "nationwide" ? `Nationwide in ${country}, where Boss Bucks markets are active` : tier === "state" ? `${region}, ${country}` : `${market}, ${region}, ${country}`; }

export function eligibleUpgradeMembers(members: DiscountMember[], product: DiscountCatalogItem) {
 return members.filter(m => m.effective.available && !!m.base_source_id && m.product_id === product.membership_product_id && m.subject_type === product.subject_type && product.upgrade_from_tiers.includes(m.effective.tier!) && m.effective.country === product.country && m.effective.region === product.region && m.effective.market === product.market);
}
