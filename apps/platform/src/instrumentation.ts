import { emitFundraisingDiagnostic, FUNDRAISING_CORRELATION_HEADER, FUNDRAISING_PARENT_HEADER, fundraisingDiagnosticRoute, validFundraisingCorrelation } from "./lib/fundraising/diagnostics";
import type { Instrumentation } from "next";
import { emitMerchantDiagnostic, MERCHANT_CORRELATION_HEADER, merchantDiagnosticPath, merchantDiagnosticRoute, validMerchantCorrelation } from "./lib/merchants/diagnostics";
import {emitPartnerDiagnostic,partnerDiagnosticRoute,PARTNER_CORRELATION_HEADER,PARTNER_PARENT_HEADER,validPartnerCorrelation}from"./lib/partners/diagnostics";
export const onRequestError: Instrumentation.onRequestError = (error, request, context) => {
 const fundraisingRoute=fundraisingDiagnosticRoute(request.path);
 if(fundraisingRoute){const supplied=request.headers[FUNDRAISING_CORRELATION_HEADER],parent=request.headers[FUNDRAISING_PARENT_HEADER];emitFundraisingDiagnostic({route:fundraisingRoute,correlationId:validFundraisingCorrelation(supplied)?supplied:crypto.randomUUID(),parentCorrelationId:validFundraisingCorrelation(parent)?parent:null,phase:context.routeType==="route"?"server-route":context.routeType==="proxy"?"server-proxy":context.renderSource==="server-rendering"?"server-render":"server-component",stage:"server_exception",observedAt:"src/instrumentation.ts",classification:"exception",error});return;}
 const partnerRoute=partnerDiagnosticRoute(request.path);
 if(partnerRoute){const supplied=request.headers[PARTNER_CORRELATION_HEADER],parent=request.headers[PARTNER_PARENT_HEADER];emitPartnerDiagnostic({route:partnerRoute,correlationId:validPartnerCorrelation(supplied)?supplied:crypto.randomUUID(),parentCorrelationId:validPartnerCorrelation(parent)?parent:null,stage:"server_exception",phase:context.routeType==="route"?"server-route":context.routeType==="proxy"?"server-proxy":context.renderSource==="server-rendering"?"server-render":"server-component",observedAt:"src/instrumentation.ts",classification:"exception",error});return;}
 if (!merchantDiagnosticPath(request.path)) return;
 const supplied = request.headers[MERCHANT_CORRELATION_HEADER];
 emitMerchantDiagnostic({ route: merchantDiagnosticRoute(request.path), correlationId: validMerchantCorrelation(supplied) ? supplied : crypto.randomUUID(), stage: "server_exception", phase: context.routeType === "route" ? "server-route" : context.routeType === "proxy" ? "server-proxy" : context.renderSource === "server-rendering" ? "server-render" : "server-component", observedAt: "src/instrumentation.ts", classification: "exception", error });
};
