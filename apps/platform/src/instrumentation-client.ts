import { clearMerchantClientTrace, merchantClientDiagnostic } from "./lib/merchants/diagnostics-client";
import { merchantDiagnosticPath } from "./lib/merchants/diagnostics";
import {clearPartnerClientTrace,partnerClientGlobalError}from"./lib/partners/diagnostics-client";
import {partnerDiagnosticRoute}from"./lib/partners/diagnostics";
// Supported Next hook file; finite channels emit only on their exact routes.
window.addEventListener("error", event => {merchantClientDiagnostic({ stage: "client_exception", observedAt: "src/instrumentation-client.ts", classification: "exception", error: event.error });partnerClientGlobalError("window_error",event.error);});
window.addEventListener("unhandledrejection", event => {merchantClientDiagnostic({ stage: "client_exception", observedAt: "src/instrumentation-client.ts", classification: "exception", error: event.reason });partnerClientGlobalError("unhandled_rejection",event.reason);});
export function onRouterTransitionStart(url: string) { if (!merchantDiagnosticPath(url)) clearMerchantClientTrace();if(!partnerDiagnosticRoute(url))clearPartnerClientTrace(); }
