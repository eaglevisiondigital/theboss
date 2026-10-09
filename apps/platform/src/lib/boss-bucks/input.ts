import type { Json } from "../supabase/database.types";
import { statUuid } from "../stat-intelligence/input";
import { bucksRecord, type BucksCommand } from "./contracts";
export const walletFeatures = ["wallet", "fundraising_issuance", "family_wallet", "organization_wallet_reporting", "charge_eligibility_preview", "wallet_spending", "charge_payments", "split_tender", "discount_membership", "membership_trials", "physical_cards", "membership_sales", "membership_upgrades"] as const;
const fields: Record<string, string[]> = { "features.configure": ["organization_id", "features"], "wallet.provision": ["organization_id", "household_id", "dependent_person_id", "currency"], "policy.create": ["campaign_id", "mode", "basis_points", "currency", "channels", "availability_seconds", "expiry_seconds"], "fundraiser.bind_household": ["fundraiser_id", "household_id"], "access.end": ["wallet_id"], "payment.spend": ["wallet_id", "organization_id", "currency", "amount_minor", "allocations", "checkout_id"], "payment.reverse": ["payment_id", "allocations", "reason"] };
export function paymentMinor(value: unknown): number | null {
 if (typeof value !== "number" && typeof value !== "string" || !/^[1-9][0-9]{0,9}$/.test(String(value))) return null;
 const amount = Number(value); return Number.isSafeInteger(amount) && amount <= 1_000_000_000 ? amount : null;
}
function paymentAllocations(value: unknown, key: "charge_id" | "allocation_id"): number | null {
 if (!Array.isArray(value) || value.length < 1 || value.length > 50) return null;
 const ids = new Set<string>(); let total = 0;
 for (const row of value) { if (!bucksRecord(row) || Object.keys(row).some(k => ![key, "amount_minor"].includes(k)) || !statUuid(row[key]) || ids.has(row[key].toLowerCase()) || paymentMinor(row.amount_minor) === null) return null; ids.add(row[key].toLowerCase()); total += paymentMinor(row.amount_minor)!; }
 return total <= 1_000_000_000 ? total : null;
}
export function parseBucksCommand(v: unknown): BucksCommand | null {
 if (!bucksRecord(v) || Object.keys(v).some(k => !["action", "input", "request_id"].includes(k)) || typeof v.action !== "string" || !statUuid(v.request_id) || !bucksRecord(v.input)) return null;
 const allowed = fields[v.action]; if (!allowed || Object.keys(v.input).some(k => !allowed.includes(k)) || Object.entries(v.input).some(([k, x]) => x === null || k.endsWith("_id") && !statUuid(x))) return null;
 if (v.action === "features.configure" && (!statUuid(v.input.organization_id) || !bucksRecord(v.input.features) || Object.entries(v.input.features).some(([k, x]) => !walletFeatures.includes(k as typeof walletFeatures[number]) || typeof x !== "boolean"))) return null;
 if (v.action === "payment.spend" && (!statUuid(v.input.wallet_id) || !statUuid(v.input.organization_id) || typeof v.input.currency !== "string" || !/^[A-Z]{3}$/.test(v.input.currency) || paymentMinor(v.input.amount_minor) === null || paymentAllocations(v.input.allocations, "charge_id") !== paymentMinor(v.input.amount_minor))) return null;
 if (v.action === "payment.reverse" && (!statUuid(v.input.payment_id) || paymentAllocations(v.input.allocations, "allocation_id") === null || typeof v.input.reason !== "string" || !v.input.reason.trim() || v.input.reason.length > 200)) return null;
 if (v.action === "wallet.provision" && (!statUuid(v.input.organization_id) || !statUuid(v.input.household_id) || !statUuid(v.input.dependent_person_id) || typeof v.input.currency !== "string" || !/^[A-Z]{3}$/.test(v.input.currency))) return null;
 if (v.action === "policy.create" && (!statUuid(v.input.campaign_id) || !["none", "percentage"].includes(String(v.input.mode)) || !Number.isSafeInteger(v.input.basis_points) || Number(v.input.basis_points) < 0 || Number(v.input.basis_points) > 10000 || v.input.mode === "none" && v.input.basis_points !== 0 || typeof v.input.currency !== "string" || !/^[A-Z]{3}$/.test(v.input.currency) || !Array.isArray(v.input.channels) || !v.input.channels.length || v.input.channels.some(x => !["direct_support", "money_board"].includes(String(x))))) return null;
 for (const k of ["availability_seconds", "expiry_seconds"]) if (k in v.input && (!Number.isSafeInteger(v.input[k]) || Number(v.input[k]) < (k === "expiry_seconds" ? 1 : 0) || Number(v.input[k]) > (k === "expiry_seconds" ? 315360000 : 31536000))) return null;
 if (v.action === "access.end" && !statUuid(v.input.wallet_id) || v.action === "fundraiser.bind_household" && (!statUuid(v.input.fundraiser_id) || !statUuid(v.input.household_id))) return null;
 return v as BucksCommand;
}
export function bucksQuery(v: Record<string, unknown>, organization = false): Record<string, Json> | null {
 const q: Record<string, Json> = { mode: organization ? "organization" : "family" };
 for (const [key, field] of [["org", "organization_id"], ["wallet", "wallet_id"], ["child", "child_id"], ["campaign", "campaign_id"], ["before", "before_id"], ["charge", "charge_id"], ["report_after", "report_after_id"], ["payments_before", "payments_before_id"]]) { const x = v[key]; if (x === undefined || x === "") continue; if (!statUuid(x)) return null; q[field] = x; }
 if (v.kind !== undefined && v.kind !== "") { if (!["issuance", "reversal", "expiration", "spend", "payment_restore", "recovery_open", "recovery_apply", "recovery_cancel", "recovery_cancel_source", "recovery_release"].includes(String(v.kind))) return null; q.kind = String(v.kind); }
 return q;
}
