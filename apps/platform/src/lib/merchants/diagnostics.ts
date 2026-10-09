import { finiteErrorDetails } from "../diagnostics/error";
// One finite diagnostic channel. Never serialize an Error, request or projection.
export const MERCHANT_DIAGNOSTIC_PREFIX = "BOSS_MERCHANT_DIAGNOSTIC ";
export const MERCHANT_CORRELATION_HEADER = "x-boss-merchant-diagnostic";
export const merchantDiagnosticStages = ["page_enter", "read_started", "read_completed", "contract_rejected", "read_failed", "mutation_started", "mutation_completed", "receipt_received", "refresh_requested", "client_rendered", "server_exception", "error_boundary", "retry_requested", "client_exception", "rpc_completed", "rpc_failed", "operation_rejected", "response_not_received", "http_rejected", "json_rejected", "receipt_rejected", "response_accepted", "reconciliation_unavailable"] as const;
export type MerchantDiagnosticStage = typeof merchantDiagnosticStages[number];
export type MerchantDiagnosticPhase = "server-component" | "server-render" | "server-route" | "server-proxy" | "client" | "client-boundary";
const phases: MerchantDiagnosticPhase[] = ["server-component", "server-render", "server-route", "server-proxy", "client", "client-boundary"];
const classifications = ["event", "exception", "contract-rejected", "scope-denied", "upstream-unavailable", "response-lost", "http-error", "invalid-json", "invalid-receipt", "confirmed-success", "confirmed-rejection", "unknown-result", "refresh-failed"] as const;
type Classification = typeof classifications[number];
const files = ["src/app/app/merchant-sales/page.tsx", "src/components/merchants/sales.tsx", "src/lib/merchants/action.ts","src/app/app/merchants/page.tsx", "src/app/app/merchants/mutate/route.ts", "src/components/merchants/portal.tsx", "src/components/merchants/shared.tsx", "src/lib/merchants/data.ts", "src/lib/merchants/contracts.ts", "src/lib/merchants/mutation.ts", "src/app/app/layout.tsx", "src/app/error.tsx", "src/instrumentation.ts", "src/instrumentation-client.ts", "src/proxy.ts"] as const;
type DiagnosticFile = typeof files[number];
export function validMerchantCorrelation(value: unknown): value is string {
 return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
}
export const merchantDiagnosticOperations = ["offer.status", "merchant.mutation", "merchant.read", "sales.read", "lead.create", "lead.activity", "lead.state", "lead.reassign", "lead.convert", "sales.grant", "sales.end"] as const;
export type MerchantDiagnosticOperation = typeof merchantDiagnosticOperations[number];
export type MerchantDiagnosticRoute = "/app/merchants" | "/app/merchant-sales";
export function merchantDiagnosticOperation(action:string): MerchantDiagnosticOperation {
 return merchantDiagnosticOperations.includes(action as MerchantDiagnosticOperation) ? action as MerchantDiagnosticOperation : "merchant.mutation";
}
export function merchantDiagnosticRoute(path:string):MerchantDiagnosticRoute { return path.split(/[?#]/,1)[0] === "/app/merchant-sales" ? "/app/merchant-sales" : "/app/merchants"; }
export function merchantDiagnosticPath(value: unknown) {
 if (typeof value !== "string") return false;
 const path = value.split(/[?#]/, 1)[0];
 return path === "/app/merchants" || path === "/app/merchants/mutate" || path === "/app/merchant-sales";
}
export function merchantErrorDetails(error: unknown) { return finiteErrorDetails(error,files); }
export type MerchantDiagnosticInput = { correlationId: string; parentCorrelationId?: string | null; stage: MerchantDiagnosticStage; phase: MerchantDiagnosticPhase; observedAt: DiagnosticFile; classification?: Classification; operation?: MerchantDiagnosticOperation; route?: MerchantDiagnosticRoute; status?: number; error?: unknown };
export function merchantDiagnosticRecord(input: MerchantDiagnosticInput) {
 if (!validMerchantCorrelation(input.correlationId) || !merchantDiagnosticStages.includes(input.stage) || !phases.includes(input.phase) || !files.includes(input.observedAt)) return null;
 const details = input.error === undefined ? { exception_category: null, digest: null, source: null } : merchantErrorDetails(input.error);
 const commit = process.env.BOSS_DIAGNOSTIC_COMMIT, deploy = process.env.BOSS_DIAGNOSTIC_DEPLOY;
 return {
  schema: "boss.merchant.diagnostic.v1", timestamp: new Date().toISOString(),
  commit: typeof commit === "string" && /^[a-f0-9]{40}$/.test(commit) ? commit : "local",
  deployment: typeof deploy === "string" && /^[a-f0-9]{24}$/.test(deploy) ? deploy : "local",
  route: input.route === "/app/merchant-sales" || input.operation?.startsWith("lead.") || input.operation?.startsWith("sales.") ? "/app/merchant-sales" : "/app/merchants", phase: input.phase, stage: input.stage,
  correlation_id: input.correlationId,
  parent_correlation_id: validMerchantCorrelation(input.parentCorrelationId) ? input.parentCorrelationId : null,
  observed_at: input.observedAt,
  classification: classifications.includes(input.classification ?? "event") ? input.classification ?? "event" : "event",
  operation: input.operation && merchantDiagnosticOperations.includes(input.operation) ? input.operation : null,
  http_status: Number.isInteger(input.status) && Number(input.status) >= 100 && Number(input.status) <= 599 ? input.status : null,
  ...details,
 };
}
export function emitMerchantDiagnostic(input: MerchantDiagnosticInput, sink: (line: string) => void = line => console.info(line)) {
 try { const record = merchantDiagnosticRecord(input); if (record) sink(MERCHANT_DIAGNOSTIC_PREFIX + JSON.stringify(record)); } catch { /* Diagnostics must never break the application. */ }
}
