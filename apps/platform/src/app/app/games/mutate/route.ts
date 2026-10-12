import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performGameMutation, gameFailure } from "@/lib/games/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try { const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); finish = route.finish; const result = await performGameMutation(request, route.client, origin); return finish(NextResponse.json(result.body, { status: result.status })); }
  catch { const result = gameFailure(); return finish(NextResponse.json(result.body, { status: result.status })); }
}
