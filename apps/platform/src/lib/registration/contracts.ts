import type { Json } from "../supabase/database.types";

export type RegistrationRow = Record<string, Json | undefined>;
export const registrationOperations = [
  "offering.upsert", "offering.publish", "form.publish", "waiver.publish", "document_requirement.upsert", "fee.upsert", "coupon.upsert", "registration.configure",
  "registration.start", "registration.save", "registration.submit", "registration.decision", "registration.withdraw", "registration.eligibility", "registration.assign_team", "registration.remove_team",
  "form.answer", "form.access", "waiver.sign", "document.intent", "document.complete", "document.review", "document.access", "emergency.save", "emergency.access", "charge.create", "charge.adjust", "charge.cancel", "payment.record_offline", "payment_plan.create", "payment_plan.cancel",
] as const;
export type RegistrationOperation = typeof registrationOperations[number];
export type RegistrationCommand = { operation: RegistrationOperation; input: RegistrationRow };
export type RegistrationQuery = { view: "family" | "admin"; organization_id?: string; registration_id?: string; offering_id?: string; status?: string; query?: string };
export type RegistrationData = {
  person: RegistrationRow | null; organizations: RegistrationRow[]; organizationId: string | null;
  features: Record<string, boolean>; operations: RegistrationOperation[]; offerings: RegistrationRow[]; registrations: RegistrationRow[];
  organizationScope: RegistrationRow | null; participants: RegistrationRow[]; households: RegistrationRow[]; units: RegistrationRow[]; teams: RegistrationRow[]; seasons: RegistrationRow[]; events: RegistrationRow[];
  definitions: { forms: RegistrationRow[]; waivers: RegistrationRow[]; documents: RegistrationRow[]; fees: RegistrationRow[]; coupons: RegistrationRow[] };
  detail: RegistrationRow | null; unavailable?: boolean;
};
export const emptyRegistrationData: RegistrationData = { person: null, organizations: [], organizationId: null, features: {}, organizationScope: null, operations: [], offerings: [], registrations: [], participants: [], households: [], units: [], teams: [], seasons: [], events: [], definitions: { forms: [], waivers: [], documents: [], fees: [], coupons: [] }, detail: null };
export type FormCondition = { source: "answer" | "participant_age" | "context"; field?: string; op: "equals" | "not_equals" | "includes" | "lt" | "gte"; value: string | number | boolean };
export type FormField = { key: string; type: string; label: string; required?: boolean; section?: string; help?: string; content?: string; options?: string[]; show_if?: FormCondition[]; required_if?: FormCondition[]; min?: number; max?: number; max_length?: number };
export type FormDefinition = { fields: FormField[] };
export const text = (row: RegistrationRow | null | undefined, key: string, fallback = "") => typeof row?.[key] === "string" ? row[key] as string : fallback;
export const number = (row: RegistrationRow | null | undefined, key: string, fallback = 0) => typeof row?.[key] === "number" ? row[key] as number : fallback;
export const object = (value: Json | undefined): RegistrationRow => typeof value === "object" && value !== null && !Array.isArray(value) ? value : {};
export const rows = (value: Json | undefined): RegistrationRow[] => Array.isArray(value) ? value.flatMap(item => typeof item === "object" && item !== null && !Array.isArray(item) ? [item] : []) : [];
export const money = (minor: number, currency = "USD") => { try { return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(minor / 100); } catch { return minor + " " + currency + " minor units"; } };

// Cash/check keep their authorized offline workflow. Boss Bucks execution uses
// its current-session wallet/payment contract with explicit guardian authority.
// External methods remain nonexecuting until Phase 7D approval.
export type OfflinePaymentMethod = "cash" | "check";
export type CanonicalPaymentMethod = OfflinePaymentMethod | "boss_bucks";
export type PlannedPaymentMethod = "card" | "ach";
export type PlannedPaymentSource = Readonly<{ method: PlannedPaymentMethod; execution: "future_approval_required"; organizationId: string; chargeId: string; currency: string; amountMinor: number; sourceReference: string }>;
