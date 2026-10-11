import { finiteErrorDetails } from "../diagnostics/error";
import { validMerchantCorrelation } from "../merchants/diagnostics";

export const FUNDRAISING_DIAGNOSTIC_PREFIX = "BOSS_FUNDRAISING_DIAGNOSTIC ";
export const FUNDRAISING_CORRELATION_HEADER = "x-boss-fundraising-diagnostic";
export const FUNDRAISING_PARENT_HEADER = "x-boss-fundraising-diagnostic-parent";
export const validFundraisingCorrelation = validMerchantCorrelation;
const routes = ["/app/fundraising", "/app/fundraising/mutate", "/app/fundraising/allocation", "/app/fundraising/allocation/mutate", "/fundraise/[path]", "/fundraise/[path]/board", "/fundraise/[path]/cart", "/fundraise/[path]/candidate", "/fundraise/[path]/support"] as const;
const stages = ["page_enter", "read_started", "read_completed", "read_failed", "contract_rejected", "mutation_started", "rpc_completed", "rpc_failed", "http_response", "response_accepted", "response_rejected", "unknown_confirmation", "refresh_requested", "client_rendered", "error_boundary", "retry_requested", "server_exception", "client_exception"] as const;
const phases = ["server-component", "server-render", "server-route", "server-proxy", "client", "client-boundary"] as const;
const classifications = ["event", "exception", "window_error", "unhandled_rejection", "scope-denied", "upstream-unavailable", "confirmed-success", "confirmed-rejection", "unknown-result", "contract-rejected", "refresh-failed"] as const;
const operations = ["campaign.read", "board.read", "board.candidate", "cart.open", "cart.read", "cart.add", "cart.remove", "cart.clear", "cart.reserve", "cart.prepare", "cart.cancel", "cart.expire", "cart.recover", "cart.revalidate", "fundraising.command", "allocation.read", "allocation.command", "policy.authorize", "cleanup"] as const;
const files = ["src/app/fundraise/[path]/page.tsx", "src/app/app/fundraising/page.tsx", "src/app/app/fundraising/allocation/page.tsx", "src/lib/fundraising/data.ts", "src/lib/fundraising/mutation.ts", "src/lib/fundraising/diagnostics-client.ts", "src/lib/money-board/data.ts", "src/lib/money-board/mutation.ts", "src/lib/fundraising-allocation/data.ts", "src/lib/fundraising-allocation/mutation.ts", "src/lib/fundraising/diagnostics-server.ts", "src/components/money-board/portal.tsx", "src/components/fundraising/console.tsx", "src/components/fundraising/supporter.tsx", "src/components/fundraising/allocation-console.tsx", "src/app/error.tsx", "src/instrumentation.ts", "src/instrumentation-client.ts"] as const;
export type FundraisingRoute = typeof routes[number];
export type FundraisingOperation = typeof operations[number];
export type FundraisingTrace = { correlationId: string; parentCorrelationId?: string | null; route: FundraisingRoute };
export type FundraisingDiagnosticInput = FundraisingTrace & { phase: typeof phases[number]; stage: typeof stages[number]; observedAt: typeof files[number]; operation?: FundraisingOperation; classification?: typeof classifications[number]; status?: number; error?: unknown };
// Actual campaign paths and query strings never enter the diagnostic record.
export function fundraisingDiagnosticRoute(path: unknown): FundraisingRoute | null {
 if (typeof path !== "string") return null;
 const clean = path.split(/[?#]/, 1)[0];
 if ((routes as readonly string[]).includes(clean)) return clean as FundraisingRoute;
 const match = /^\/fundraise\/[a-z0-9-]{6,100}(\/(board|cart|candidate|support))?$/.exec(clean);
 return match ? `/fundraise/[path]${match[1] ?? ""}` as FundraisingRoute : null;
}
export function fundraisingOperation(value: unknown, cart = false): FundraisingOperation {
 const candidate = cart && typeof value === "string" ? `cart.${value}` : value;
 return (operations as readonly unknown[]).includes(candidate) ? candidate as FundraisingOperation : cart ? "fundraising.command" : "allocation.command";
}
export function fundraisingCommandOperation(action: unknown, status?: unknown): FundraisingOperation {
 if (["release", "board.archive", "fundraiser.end", "delegation.revoke", "destination.archive"].includes(typeof action === "string" ? action : "") || action === "campaign.status" && status === "archived") return "cleanup";
 return action === "platform_policy.create" || action === "allocation_policy.create" || action === "delegation.create" ? "policy.authorize" : "fundraising.command";
}
export function fundraisingDiagnosticRecord(input: FundraisingDiagnosticInput) {
 if (!validFundraisingCorrelation(input.correlationId) || !routes.includes(input.route) || !stages.includes(input.stage) || !phases.includes(input.phase) || !files.includes(input.observedAt)) return null;
 const commit = process.env.BOSS_DIAGNOSTIC_COMMIT, deploy = process.env.BOSS_DIAGNOSTIC_DEPLOY;
 return { schema: "boss.fundraising.diagnostic.v1", timestamp: new Date().toISOString(), commit: /^[a-f0-9]{40}$/.test(commit ?? "") ? commit! : "local", deployment: /^[a-f0-9]{24}$/.test(deploy ?? "") ? deploy! : "local", route: input.route, phase: input.phase, stage: input.stage, correlation_id: input.correlationId, parent_correlation_id: validFundraisingCorrelation(input.parentCorrelationId) ? input.parentCorrelationId : null, observed_at: input.observedAt, operation: operations.includes(input.operation!) ? input.operation! : null, classification: classifications.includes(input.classification ?? "event") ? input.classification ?? "event" : "event", http_status: Number.isInteger(input.status) && Number(input.status) >= 100 && Number(input.status) <= 599 ? input.status! : null, ...(input.error === undefined ? { exception_category: null, digest: null, source: null } : finiteErrorDetails(input.error, files)) };
}
export function emitFundraisingDiagnostic(input: FundraisingDiagnosticInput, sink: (line: string) => void = line => console.info(line)) {
 try { const record = fundraisingDiagnosticRecord(input); if (record) sink(FUNDRAISING_DIAGNOSTIC_PREFIX + JSON.stringify(record)); } catch { /* Diagnostics never authorize or change a financial operation. */ }
}
// Operator exports reject unknown fields; a forged log line cannot smuggle payload data.
export function parseFundraisingDiagnostic(line: string) {
 try {
  if (line.length > 8192 || !line.startsWith(FUNDRAISING_DIAGNOSTIC_PREFIX)) return null;
  const v = JSON.parse(line.slice(FUNDRAISING_DIAGNOSTIC_PREFIX.length));
  if (!v || typeof v !== "object" || Array.isArray(v)) return null;
  const clean = fundraisingDiagnosticRecord({ correlationId: v.correlation_id, parentCorrelationId: v.parent_correlation_id, route: v.route, phase: v.phase, stage: v.stage, observedAt: v.observed_at, operation: v.operation, classification: v.classification, status: v.http_status });
  if (!clean || Object.keys(v).sort().join() !== Object.keys(clean).sort().join() || v.schema !== clean.schema || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(v.timestamp) || !Number.isFinite(Date.parse(v.timestamp))) return null;
  for (const key of ["route", "phase", "stage", "correlation_id", "parent_correlation_id", "observed_at", "operation", "classification", "http_status"] as const) if (v[key] !== clean[key]) return null;
  if (v.commit !== "local" && !/^[a-f0-9]{40}$/.test(v.commit) || v.deployment !== "local" && !/^[a-f0-9]{24}$/.test(v.deployment)) return null;
  if (v.exception_category !== null && !["Error", "TypeError", "RangeError", "ReferenceError", "SyntaxError", "AggregateError", "URIError", "EvalError", "UnknownError"].includes(v.exception_category)) return null;
  if (v.digest !== null && (typeof v.digest !== "string" || !/^[0-9]{1,20}$/.test(v.digest))) return null;
  if (v.source !== null && (!v.source || typeof v.source !== "object" || Object.keys(v.source).sort().join() !== "column,file,line" || !files.includes(v.source.file) || !Number.isInteger(v.source.line) || !Number.isInteger(v.source.column) || v.source.line < 1 || v.source.column < 1 || v.source.line > 999999 || v.source.column > 999999)) return null;
  return { ...clean, timestamp: v.timestamp as string, commit: v.commit as string, deployment: v.deployment as string, exception_category: v.exception_category as string | null, digest: v.digest as string | null, source: v.source as { file: typeof files[number]; line: number; column: number } | null };
 } catch { return null; }
}
export function fundraisingResult(trace: FundraisingTrace | undefined, operation: FundraisingOperation, status: number, observedAt: FundraisingDiagnosticInput["observedAt"], error?: unknown) {
 if (!trace) return;
 emitFundraisingDiagnostic({ ...trace, phase: "server-route", stage: error === undefined ? "http_response" : "server_exception", observedAt, operation, status, classification: status === 401 || status === 403 || status === 404 ? "scope-denied" : status >= 500 ? "unknown-result" : status >= 400 ? "confirmed-rejection" : "confirmed-success", error });
}
