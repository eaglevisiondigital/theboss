import { headers } from "next/headers";
import { emitFundraisingDiagnostic, FUNDRAISING_CORRELATION_HEADER, FUNDRAISING_PARENT_HEADER, fundraisingResult, validFundraisingCorrelation, type FundraisingRoute, type FundraisingTrace } from "./diagnostics";
export function fundraisingRequestTrace(request: Request, route: FundraisingRoute): FundraisingTrace {
 // Fresh diagnostic identity, unrelated to the signed business request or capability.
 const parent = request.headers.get(FUNDRAISING_PARENT_HEADER);
 const supplied = request.headers.get(FUNDRAISING_CORRELATION_HEADER);
 return { route, correlationId: route.startsWith("/app/") && validFundraisingCorrelation(supplied) ? supplied : crypto.randomUUID(), parentCorrelationId: validFundraisingCorrelation(parent) ? parent : null };
}
export async function fundraisingPageTrace(route: FundraisingRoute, observedAt: "src/app/fundraise/[path]/page.tsx" | "src/app/app/fundraising/page.tsx" | "src/app/app/fundraising/allocation/page.tsx"): Promise<FundraisingTrace> {
 const h = await headers(), supplied = h.get(FUNDRAISING_CORRELATION_HEADER), parent = h.get(FUNDRAISING_PARENT_HEADER);
 const trace = { route, correlationId: route.startsWith("/app/") && validFundraisingCorrelation(supplied) ? supplied : crypto.randomUUID(), parentCorrelationId: validFundraisingCorrelation(parent) ? parent : null };
 emitFundraisingDiagnostic({ ...trace, phase: "server-component", stage: "page_enter", observedAt });
 return trace;
}
export function fundraisingResponse<T extends Response>(trace: FundraisingTrace, response: T): T {
 response.headers.set(FUNDRAISING_CORRELATION_HEADER, trace.correlationId);
 fundraisingResult(trace, trace.route.endsWith("/candidate") ? "board.candidate" : "fundraising.command", response.status, "src/lib/fundraising/diagnostics-server.ts");
 return response;
}
export function fundraisingRouteException(trace: FundraisingTrace, error: unknown) {
 emitFundraisingDiagnostic({ ...trace, phase: "server-route", stage: "server_exception", observedAt: "src/lib/fundraising/diagnostics-server.ts", classification: "exception", status: 503, error });
}
