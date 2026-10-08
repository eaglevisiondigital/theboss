import type { Instrumentation } from "next";
import { emitMerchantDiagnostic, MERCHANT_CORRELATION_HEADER, merchantDiagnosticPath, merchantDiagnosticRoute, validMerchantCorrelation } from "./lib/merchants/diagnostics";
export const onRequestError: Instrumentation.onRequestError = (error, request, context) => {
 if (!merchantDiagnosticPath(request.path)) return;
 const supplied = request.headers[MERCHANT_CORRELATION_HEADER];
 emitMerchantDiagnostic({ route: merchantDiagnosticRoute(request.path), correlationId: validMerchantCorrelation(supplied) ? supplied : crypto.randomUUID(), stage: "server_exception", phase: context.routeType === "route" ? "server-route" : context.routeType === "proxy" ? "server-proxy" : context.renderSource === "server-rendering" ? "server-render" : "server-component", observedAt: "src/instrumentation.ts", classification: "exception", error });
};
