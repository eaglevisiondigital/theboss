import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performPaymentMutation, type PaymentClient } from "@/lib/payments/mutation";
import { fundraisingRequestTrace, fundraisingResponse, fundraisingRouteException } from "@/lib/fundraising/diagnostics-server";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
 const trace = fundraisingRequestTrace(request, "/app/payments/mutate");let baseFinish: (r: NextResponse) => NextResponse = preventAuthCaching;
 const finish = (r: NextResponse) => fundraisingResponse(trace, baseFinish(r));
 try { const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request);baseFinish = route.finish;
  const result = await performPaymentMutation(request, route.client as unknown as PaymentClient, origin, trace);return finish(NextResponse.json(result.body, { status: result.status }));
 } catch (error) { fundraisingRouteException(trace, error);return finish(NextResponse.json({ ok: false, error: "The payment change could not be confirmed." }, { status: 503 })); }
}
