import { emitMerchantDiagnostic, merchantDiagnosticPath, merchantDiagnosticRoute, validMerchantCorrelation, type MerchantDiagnosticOperation, type MerchantDiagnosticInput } from "./diagnostics";
// Ephemeral opaque trace links only: no cookies, storage, identities or requests.
let accepted = false;
let lastRead: string | null = null, lastMutation: string | null = null;
export function clearMerchantClientTrace() { lastRead = null; lastMutation = null; accepted = false; }
export function merchantClientDiagnostic(input: Omit<MerchantDiagnosticInput, "correlationId" | "parentCorrelationId" | "phase">, correlationId?: string) {
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname)) return;
  const id = validMerchantCorrelation(correlationId) ? correlationId : lastMutation ?? lastRead ?? crypto.randomUUID();
  if(input.stage === "response_accepted") accepted = true;
  emitMerchantDiagnostic({ ...input, route: merchantDiagnosticRoute(window.location.pathname), classification: input.stage === "error_boundary" && accepted ? "refresh-failed" : input.classification, correlationId: id, phase: input.stage === "error_boundary" ? "client-boundary" : "client" });
 } catch { /* No telemetry failure may affect rendering or mutation. */ }
}
export function merchantClientRendered(correlationId: string, sales = false) {
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname) || !validMerchantCorrelation(correlationId)) return;
  emitMerchantDiagnostic({ correlationId, route: sales ? "/app/merchant-sales" : "/app/merchants", parentCorrelationId: lastMutation, phase: "client", stage: "client_rendered", observedAt: sales ? "src/components/merchants/sales.tsx" : "src/components/merchants/portal.tsx" });
  lastRead = correlationId; lastMutation = null; accepted = false;
 } catch { /* Keep rendering independent. */ }
}
export function merchantClientReceipt(correlationId: unknown, status: number, operation: MerchantDiagnosticOperation) {
 if (!validMerchantCorrelation(correlationId)) return;
 try {
  if (typeof window === "undefined" || !merchantDiagnosticPath(window.location.pathname)) return;
  emitMerchantDiagnostic({ correlationId, route: merchantDiagnosticRoute(window.location.pathname), parentCorrelationId: lastRead, phase: "client", stage: "receipt_received", observedAt: "src/components/merchants/shared.tsx", operation, status });
  lastMutation = correlationId; accepted = false;
 } catch { /* Keep mutation independent. */ }
}
