import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performPaymentMutation, type PaymentClient } from "@/lib/payments/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) { let finish: (r: NextResponse) => NextResponse = preventAuthCaching; try { const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); finish = route.finish; const result = await performPaymentMutation(request, route.client as unknown as PaymentClient, origin); return finish(NextResponse.json(result.body, { status: result.status })); } catch { return finish(NextResponse.json({ ok: false, error: "The payment change could not be confirmed." }, { status: 503 })); } }
