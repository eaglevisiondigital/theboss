import { fundraisingRequestTrace, fundraisingResponse, fundraisingRouteException } from "@/lib/fundraising/diagnostics-server";
import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performFundraisingMutation, type FundraisingClient } from "@/lib/fundraising/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest, { params }: { params: Promise<{ path: string }> }) { const trace=fundraisingRequestTrace(request,"/fundraise/[path]/support"); let baseFinish: (r: NextResponse) => NextResponse = preventAuthCaching; const finish=(r:NextResponse)=>fundraisingResponse(trace,baseFinish(r)); try { const { path } = await params, origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); baseFinish = route.finish; const result = await performFundraisingMutation(request, route.client as unknown as FundraisingClient, origin, true, path, trace); return finish(NextResponse.json(result.body, { status: result.status })); } catch (error) { fundraisingRouteException(trace,error); return finish(NextResponse.json({ ok: false, error: "Support could not be confirmed." }, { status: 503 })); } }
