import { emitFundraisingDiagnostic, FUNDRAISING_CORRELATION_HEADER, FUNDRAISING_PARENT_HEADER, fundraisingDiagnosticRoute, validFundraisingCorrelation, type FundraisingDiagnosticInput, type FundraisingOperation } from "./diagnostics";
let lastRead: string | null = null, lastResponse: string | null = null, lastBoundary: string | null = null, accepted = false;
export function clearFundraisingClientTrace() { lastRead = null; lastResponse = null; lastBoundary = null; accepted = false; }
export function fundraisingClientDiagnostic(input: Omit<FundraisingDiagnosticInput, "correlationId" | "route" | "phase">, id?: string) {
 try { if (typeof window === "undefined") return; const route = fundraisingDiagnosticRoute(window.location.pathname); if (!route) return;
  const correlationId = validFundraisingCorrelation(id) ? id : lastResponse ?? lastRead ?? lastBoundary ?? crypto.randomUUID();
  if (input.stage === "response_accepted") accepted = true;
  if (input.stage === "error_boundary") lastBoundary = correlationId;
  emitFundraisingDiagnostic({ ...input, route, phase: input.stage === "error_boundary" ? "client-boundary" : "client", correlationId, classification: input.stage === "error_boundary" && accepted ? "refresh-failed" : input.classification });
 } catch { /* In-memory context only; never browser storage or business state. */ }
}
export function fundraisingClientRendered(id: string | undefined, observedAt: FundraisingDiagnosticInput["observedAt"]) {
 if (!validFundraisingCorrelation(id)) return;
 fundraisingClientDiagnostic({ stage: "client_rendered", observedAt, parentCorrelationId: lastResponse }, id);
 lastRead = id; lastResponse = null; lastBoundary = null; accepted = false;
}
export async function fundraisingFetch(url: string, init: RequestInit, operation: FundraisingOperation): Promise<Response> {
 let id: string | undefined, tracedInit = init;
 try {
  id = crypto.randomUUID(); const h = new Headers(init.headers);
  h.set(FUNDRAISING_PARENT_HEADER, id); tracedInit = { ...init, headers: h };
  fundraisingClientDiagnostic({ stage: operation.endsWith(".read") ? "read_started" : "mutation_started", observedAt: "src/lib/fundraising/diagnostics-client.ts", operation, parentCorrelationId: lastRead }, id);
 } catch { /* A diagnostic setup failure cannot prevent the original fetch. */ }
 try {
  const response = await fetch(url, tracedInit), supplied = response.headers.get(FUNDRAISING_CORRELATION_HEADER);
  if (validFundraisingCorrelation(supplied)) { lastResponse = supplied; accepted = false; }
  fundraisingClientDiagnostic({ stage: "http_response", observedAt: "src/lib/fundraising/diagnostics-client.ts", parentCorrelationId: id, operation, status: response.status, classification: response.status >= 500 ? "unknown-result" : response.ok ? "event" : "confirmed-rejection" }, validFundraisingCorrelation(supplied) ? supplied : id);
  return response; // Parsing, confirmation, and retry decisions remain in existing callers.
 } catch (error) {
  fundraisingClientDiagnostic({ stage: "unknown_confirmation", observedAt: "src/lib/fundraising/diagnostics-client.ts", operation, classification: "unknown-result", error }, id);
  throw error;
 }
}
