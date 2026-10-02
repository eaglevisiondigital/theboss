import type { EmailProvider, EmailRequest } from "./email";
import { stableDeliveryKey } from "./templates";

export type DeliveryStatus = "queued" | "processing" | "sent" | "delivered" | "failed" | "bounced" | "suppressed" | "canceled";
export type FailureCategory = "transient" | "permanent" | "ambiguous" | "attempts_exhausted" | "authority_removed" | "preference" | "not_configured";
export type DeliveryCompletion = Readonly<{ status: DeliveryStatus; failureCategory?: FailureCategory; nextAttemptAt?: number; sentAt?: number; providerReference?: string }>;
export type EmailDeliveryClaim = Readonly<{
  id: string; generation: number; attempt: number; recoveredExpiredLease: boolean;
  sourceAuthorized: boolean; preferenceEnabled: boolean; mandatory: boolean;
  request: Omit<EmailRequest, "idempotencyKey">;
}>;
export interface DeliveryRepository {
  /** Durable atomic claim with a lease/fencing generation; null excludes terminal,
   * not-yet-due or already-claimed work. Authority/preferences are resolved here.
   */
  claim(id: string, now: number): Promise<EmailDeliveryClaim | null>;
  /** Update only the claimed generation, so an expired worker cannot overwrite a
   * successor. Store provider references privately, not in broad audit payloads.
   */
  finish(id: string, generation: number, completion: DeliveryCompletion): Promise<boolean>;
}
export const maximumDeliveryAttempts = 5;
const backoffMilliseconds = [60_000, 300_000, 1_800_000, 7_200_000] as const;
export async function dispatchEmailDelivery(id: string, repository: DeliveryRepository, provider: EmailProvider | null, now = Date.now()): Promise<"skipped" | "updated" | "stale"> {
  const key = stableDeliveryKey(id);
  const claim = await repository.claim(id, now);
  if (!claim) return "skipped";
  const finish = async (completion: DeliveryCompletion) => await repository.finish(claim.id, claim.generation, completion) ? "updated" as const : "stale" as const;
  if (!claim.sourceAuthorized) return finish({ status: "suppressed", failureCategory: "authority_removed" });
  if (!claim.preferenceEnabled && !claim.mandatory) return finish({ status: "suppressed", failureCategory: "preference" });
  if (!provider) return finish({ status: "suppressed", failureCategory: "not_configured" });
  if (claim.attempt > maximumDeliveryAttempts) return finish({ status: "failed", failureCategory: "attempts_exhausted" });
  if (claim.recoveredExpiredLease && !provider.supportsIdempotency) return finish({ status: "failed", failureCategory: "ambiguous" });
  let result;
  try { result = await provider.send({ ...claim.request, idempotencyKey: key }); }
  catch { result = { accepted: false as const, category: "ambiguous" as const }; }
  if (result.accepted) {
    if (!result.providerReference || result.providerReference.length > 200) return finish({ status: "failed", failureCategory: "ambiguous" });
    // Provider acceptance is sent, never a claim of final recipient delivery.
    return finish({ status: "sent", sentAt: now, providerReference: result.providerReference });
  }
  if (result.category === "permanent") return finish({ status: "failed", failureCategory: "permanent" });
  if (result.category === "ambiguous" && !provider.supportsIdempotency) return finish({ status: "failed", failureCategory: "ambiguous" });
  if (claim.attempt >= maximumDeliveryAttempts) return finish({ status: "failed", failureCategory: "attempts_exhausted" });
  return finish({ status: "queued", failureCategory: result.category, nextAttemptAt: now + backoffMilliseconds[Math.min(claim.attempt - 1, backoffMilliseconds.length - 1)] });
}
