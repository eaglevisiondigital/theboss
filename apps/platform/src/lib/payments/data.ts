import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { paymentRecord } from "./input";
export type PaymentData = { mode: "family" | "organization"; unavailable?: boolean; restricted?: boolean; can_configure?: boolean; can_request?: boolean; can_refund?: boolean; accounts?: Record<string, unknown>[]; routes?: Record<string, unknown>[]; routing_scopes?: Record<string, unknown>[]; charges?: Record<string, unknown>[]; checkouts?: Record<string, unknown>[]; settlement?: Record<string, unknown>[]; requests?: Record<string, unknown>[]; available?: Record<string, unknown>[]; deficits?: Record<string, unknown>[]; reconciliation?: Record<string, unknown>[]; consents?: Record<string, unknown>[]; saved_methods?: Record<string, unknown>[] };
export async function loadPayments(query: Record<string, Json>): Promise<PaymentData> {
 const mode = query.mode === "organization" ? "organization" : "family";
 try { const client = await createClient(), { data, error } = await client.rpc("boss_payments_read", { query });
  if (error || !paymentRecord(data) || data.mode !== mode) return { mode, restricted: error?.code === "PT403", unavailable: error?.code !== "PT403" };
  const result: PaymentData = { mode, can_configure: data.can_configure === true, can_request: data.can_request === true, can_refund: data.can_refund === true };
  for (const k of ["accounts", "routes", "routing_scopes", "charges", "checkouts", "settlement", "requests", "available", "deficits", "reconciliation", "consents", "saved_methods"] as const) result[k] = Array.isArray(data[k]) ? (data[k] as unknown[]).filter(paymentRecord).slice(0,100) : [];
  return result;
 } catch { return { mode, unavailable: true }; }
}
