import { clearMerchantClientTrace, merchantClientDiagnostic } from "./lib/merchants/diagnostics-client";
import { merchantDiagnosticPath } from "./lib/merchants/diagnostics";
// Supported Next hook file; listeners emit nothing outside the merchant page.
window.addEventListener("error", event => merchantClientDiagnostic({ stage: "client_exception", observedAt: "src/instrumentation-client.ts", classification: "exception", error: event.error }));
window.addEventListener("unhandledrejection", event => merchantClientDiagnostic({ stage: "client_exception", observedAt: "src/instrumentation-client.ts", classification: "exception", error: event.reason }));
export function onRouterTransitionStart(url: string) { if (!merchantDiagnosticPath(url)) clearMerchantClientTrace(); }
