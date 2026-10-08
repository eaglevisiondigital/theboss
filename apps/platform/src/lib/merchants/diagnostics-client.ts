import { emitMerchantDiagnostic, merchantDiagnosticPath, validMerchantCorrelation, type MerchantDiagnosticInput } from "./diagnostics";
// Ephemeral opaque trace links only: no cookies, storage, identities or requests.
let lastRead: string | null = null, lastMutation: string | null = null;
export function clearMerchantClientTrace() { lastRead = null; lastMutation = null; }
export function merchantClientDiagnostic(input: Omit<MerchantDiagnosticInput, "correlationId" | "parentCorrelationId" | "phase">, correlationId?: string) {
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname)) return;
  const id = validMerchantCorrelation(correlationId) ? correlationId : lastMutation ?? lastRead ?? crypto.randomUUID();
  emitMerchantDiagnostic({ ...input, correlationId: id, phase: input.stage === "error_boundary" ? "client-boundary" : "client" });
 } catch { /* No telemetry failure may affect rendering or mutation. */ }
}
export function merchantClientRendered(correlationId: string) {
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname) || !validMerchantCorrelation(correlationId)) return;
  emitMerchantDiagnostic({ correlationId, parentCorrelationId: lastMutation, phase: "client", stage: "client_rendered", observedAt: "src/components/merchants/portal.tsx" });
  lastRead = correlationId; lastMutation = null;
 } catch { /* Keep rendering independent. */ }
}
export function merchantClientReceipt(correlationId: unknown, status: number, operation: "offer.status" | "merchant.mutation") {
 if (!validMerchantCorrelation(correlationId)) return;
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname)) return;
  emitMerchantDiagnostic({ correlationId, parentCorrelationId: lastRead, phase: "client", stage: "receipt_received", observedAt: "src/components/merchants/shared.tsx", operation, status });
  lastMutation = correlationId;
 } catch { /* Keep mutation independent. */ }
}
