import type { Json } from "../supabase/database.types";
export const paymentActions = ["account.create", "account.disable", "route.create", "route.disable", "policy.create", "checkout.prepare", "checkout.cancel", "refund.prepare", "settlement.request", "settlement.cancel", "method.revoke", "consent.create", "consent.revoke"] as const;
export type PaymentAction = typeof paymentActions[number];
export const paymentRecord = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const uuid = (v: unknown): v is string => typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const integer = (v: unknown, zero = false) => typeof v === "number" && Number.isSafeInteger(v) && v >= (zero ? 0 : 1) && v <= 1_000_000_000;
const fields: Record<PaymentAction, readonly string[]> = {
 "account.create": ["organization_id", "provider", "environment", "name", "country", "currencies", "merchant_owner", "merchant_reference", "settlement_mode", "statement_descriptor"],
 "account.disable": ["organization_id", "account_id"], "route.create": ["organization_id", "account_id", "purpose", "currency", "scope_type", "scope_id"], "route.disable": ["organization_id", "routing_id"],
 "method.revoke": ["method_id"], "consent.revoke": ["consent_id"], "consent.create": ["method_id", "plan_id", "starts_at", "ends_at", "accepted"],
 "policy.create": ["organization_id", "purpose", "currency", "organization_basis_points", "platform_basis_points", "product_cost_basis_points", "processor_fee_owner", "availability_seconds", "request_target_seconds", "estimated_processor_basis_points", "estimated_processor_flat_minor"],
 "checkout.prepare": ["organization_id", "routing_id", "method", "currency", "allocations", "wallet_id", "bucks_minor"], "checkout.cancel": ["checkout_id"],
 "refund.prepare": ["payment_id", "amount_minor", "principal_minor", "allocations", "reason"], "settlement.request": ["organization_id", "currency", "amount_minor"], "settlement.cancel": ["organization_id", "settlement_request_id"]
};
export function parsePaymentCommand(v: unknown): { action: PaymentAction; request_id: string; input: Record<string, Json> } | null {
 if (!paymentRecord(v) || Object.keys(v).some(k => !["action", "request_id", "input"].includes(k)) || !uuid(v.request_id) || !paymentActions.includes(v.action as PaymentAction) || !paymentRecord(v.input)) return null;
 const action = v.action as PaymentAction, i = v.input;
 const optional = new Set(["statement_descriptor", "wallet_id", "request_target_seconds", "estimated_processor_basis_points", "estimated_processor_flat_minor", "ends_at"]);
 if (fields[action].some(k => !optional.has(k) && !(k in i))) return null;
 if (action === "consent.create" && (i.accepted !== true || typeof i.starts_at !== "string" || !Number.isFinite(Date.parse(i.starts_at)) || i.ends_at !== undefined && (typeof i.ends_at !== "string" || !Number.isFinite(Date.parse(i.ends_at)) || Date.parse(i.ends_at) <= Date.parse(i.starts_at)))) return null;
 if (Object.keys(i).some(k => !fields[action].includes(k)) || fields[action].includes("organization_id") && !uuid(i.organization_id)) return null;
 for (const [k, value] of Object.entries(i)) {
  if (k.endsWith("_id") && !uuid(value) || k.endsWith("_minor") && !integer(value, ["bucks_minor", "principal_minor", "estimated_processor_flat_minor"].includes(k))
   || k === "currency" && (typeof value !== "string" || !/^[A-Z]{3}$/.test(value))
   || k.endsWith("basis_points") && (!integer(value, true) || (value as number) > 10000)
   || k.endsWith("seconds") && (!integer(value, true) || (value as number) > 31536000)) return null;
 }
 if (action === "account.create" && (!["authorize_net", "nmi"].includes(String(i.provider)) || !["sandbox", "production"].includes(String(i.environment)) || !["US", "CA"].includes(String(i.country)) || !["organization", "platform"].includes(String(i.merchant_owner)) || !["direct_provider", "platform_managed"].includes(String(i.settlement_mode)) || typeof i.name !== "string" || !i.name.trim() || i.name.length > 100 || typeof i.merchant_reference !== "string" || !/^[a-z0-9_.:-]{1,100}$/i.test(i.merchant_reference) || !Array.isArray(i.currencies) || i.currencies.length < 1 || i.currencies.length > 20 || i.currencies.some(c => typeof c !== "string" || !/^[A-Z]{3}$/.test(c)))) return null;
 if (action === "route.create" && (!["fees", "fundraising"].includes(String(i.purpose)) || !["organization", "campaign", "team", "unit"].includes(String(i.scope_type)) || !uuid(i.scope_id) || !uuid(i.account_id))) return null;
 if (action === "policy.create" && (!["fees", "fundraising", "boss_bucks"].includes(String(i.purpose)) || !["organization", "platform"].includes(String(i.processor_fee_owner)) || !["organization_basis_points", "platform_basis_points", "product_cost_basis_points", "availability_seconds"].every(k => integer(i[k], true)) || Number(i.organization_basis_points) + Number(i.platform_basis_points) + Number(i.product_cost_basis_points) !== 10000)) return null;
 if (["checkout.prepare", "refund.prepare"].includes(action)) {
  if (!Array.isArray(i.allocations) || i.allocations.length > 50 || action === "checkout.prepare" && i.allocations.length === 0) return null;
  const idKey = action === "checkout.prepare" ? "charge_id" : "allocation_id"; const seen = new Set<string>();
  for (const leg of i.allocations) { if (!paymentRecord(leg) || Object.keys(leg).some(k => ![idKey, "amount_minor", ...(action === "checkout.prepare" ? ["bucks_minor"] : [])].includes(k)) || !uuid(leg[idKey]) || !integer(leg.amount_minor) || seen.has(leg[idKey].toLowerCase()) || action === "checkout.prepare" && (!integer(leg.bucks_minor, true) || Number(leg.bucks_minor) > Number(leg.amount_minor))) return null; seen.add(leg[idKey].toLowerCase()); }
  if (action === "checkout.prepare" && (!["card", "ach"].includes(String(i.method)) || !uuid(i.routing_id) || !integer(i.bucks_minor, true))) return null;
  if (action === "refund.prepare" && (!uuid(i.payment_id) || !integer(i.amount_minor) || !integer(i.principal_minor, true) || Number(i.principal_minor) > Number(i.amount_minor) || typeof i.reason !== "string" || !i.reason.trim() || i.reason.length > 200)) return null;
 }
 return { action, request_id: v.request_id, input: i as Record<string, Json> };
}
export function paymentQuery(input: Record<string, string | string[] | undefined>) {
 if (![undefined, "family", "organization"].includes(input.view as string | undefined)) return null;
 const query: Record<string, Json> = { mode: input.view === "organization" ? "organization" : "family" };
 for (const [k, field] of [["org", "organization_id"], ["charge", "charge_id"], ["before", "before"]]) { if (input[k] !== undefined) { if (!uuid(input[k])) return null; query[field] = input[k]; } }
 if (query.mode === "organization" && !query.organization_id) return null;
 return query;
}
/** Integer-only presentation. No wallet debit or provider execution. */
export function splitPaymentPreview(due: number, available: number, selected: number) {
 if (![due, available, selected].every(n => integer(n, true)) || selected > Math.min(due, available)) return null;
 return { principalMinor: due, bucksMinor: selected, externalMinor: due - selected };
}
