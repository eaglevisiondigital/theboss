import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performFundraisingMutation, type FundraisingClient } from "@/lib/fundraising/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest, { params }: { params: Promise<{ path: string }> }) { let finish: (r: NextResponse) => NextResponse = preventAuthCaching; try { const { path } = await params, origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); finish = route.finish; const result = await performFundraisingMutation(request, route.client as unknown as FundraisingClient, origin, true, path); return finish(NextResponse.json(result.body, { status: result.status })); } catch { return finish(NextResponse.json({ ok: false, error: "Support could not be confirmed." }, { status: 503 })); } }
