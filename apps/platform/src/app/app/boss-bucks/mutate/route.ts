import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performBucksMutation, type BucksClient } from "@/lib/boss-bucks/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) { let finish: (r: NextResponse) => NextResponse = preventAuthCaching; try { const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); finish = route.finish; const result = await performBucksMutation(request, route.client as unknown as BucksClient, origin); return finish(NextResponse.json(result.body, { status: result.status })); } catch { return finish(NextResponse.json({ ok: false, error: "The wallet change could not be confirmed." }, { status: 503 })); } }
