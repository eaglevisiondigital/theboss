import { createHash } from "node:crypto";
import type { OperationClaim, PaymentExecutionRepository } from "./execution";
import { capabilityKeys, providerKeys, record, safeReference, type ProviderCapability, type SafeProviderResult } from "./providers/contracts";
/** Only an approved private worker connection may implement this contract. No
 * browser/Supabase Auth cookie, service-role client or credential is accepted. */
export interface PrivatePaymentDatabase { query(sql: string, values: readonly unknown[]): Promise<{ rows: readonly Record<string, unknown>[] }> }
export class PostgresPaymentRepository implements PaymentExecutionRepository {
 private readonly checkoutByOperation = new Map<string, string>();
 constructor(private readonly db: PrivatePaymentDatabase) {}
 async claim(checkoutId: string): Promise<OperationClaim | null> {
  if (!/^[0-9a-f-]{36}$/i.test(checkoutId)) return null;
  const { rows } = await this.db.query("select boss_private.rails_worker_claim($1::uuid) as claim", [checkoutId]);
  const r = rows[0]?.claim; if (!record(r) || !record(r.account) || !record(r.command)) return null;
  const a = r.account, c = r.command;
  if (typeof r.operation_id !== "string" || typeof r.generation !== "string" || !providerKeys.includes(a.provider as typeof providerKeys[number]) || !["sandbox", "production"].includes(String(a.environment)) || !["US", "CA"].includes(String(a.country)) || !Array.isArray(a.capabilities) || a.capabilities.some(v => !capabilityKeys.includes(v)) || !["card", "ach"].includes(String(c.method)) || !["sale", "authorize", "refund"].includes(String(c.kind)) || typeof c.amount_minor !== "string" || !safeReference(c.request_reference,20) || typeof c.currency !== "string") return null;
  this.checkoutByOperation.set(r.operation_id, checkoutId);
  return { operationId: r.operation_id, generation: r.generation, firstDispatch: r.first_dispatch === true,
   transactionReference: safeReference(r.transaction_reference), account: { id: String(a.id), organizationId: String(a.organization_id), provider: a.provider as "authorize_net" | "nmi", environment: a.environment as "sandbox" | "production", country: a.country as "US" | "CA", currency: c.currency, merchantReference: String(a.merchant_reference), capabilities: a.capabilities as ProviderCapability[], verified: a.verified === true },
   command: { kind: c.kind as "sale" | "authorize" | "refund", transactionReference: safeReference(c.transaction_reference), requestReference: c.request_reference as string, amountMinor: c.amount_minor, method: c.method as "card" | "ach", currency: c.currency } };
 }
 async finish(claim: OperationClaim, result: SafeProviderResult): Promise<boolean> {
  const checkout = this.checkoutByOperation.get(claim.operationId); if (!checkout) return false;
  // Normalize again at persistence; never pass collection tokens, profiles,
  // provider bodies, free-form errors or secret material into evidence/audit.
  const evidence = { state: result.state, ...(safeReference(result.transactionReference) ? { transaction_reference: result.transactionReference } : {}),
   ...(result.amountMinor && /^(0|[1-9][0-9]{0,9})$/.test(result.amountMinor) ? { amount_minor: result.amountMinor } : {}),
   ...(result.currency && /^[A-Z]{3}$/.test(result.currency) ? { currency: result.currency } : {}),
   ...(result.occurredAt && Number.isFinite(Date.parse(result.occurredAt)) ? { occurred_at: result.occurredAt } : {}) };
  const digest = createHash("sha256").update(JSON.stringify(evidence)).digest("hex"), reference = `normalized:${claim.operationId}:${digest}`;
  const { rows } = await this.db.query("select boss_private.rails_worker_finish($1::uuid,$2::uuid,$3::timestamptz,$4::jsonb,$5::text,$6::text) as accepted", [checkout, claim.operationId, claim.generation, JSON.stringify(evidence), reference, digest]);
  return rows[0]?.accepted === true;
 }
}
