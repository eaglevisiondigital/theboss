import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performCalendarMutation } from "@/lib/calendar/mutation";

export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const origin = getRequestOrigin(request,getServerEnvironment().platformOrigin);
    const route = createRouteClient(request); finish = route.finish;
    const result = await performCalendarMutation(request,route.client,origin,true);
    return finish(NextResponse.json(result.body,{ status: result.status }));
  } catch { return finish(NextResponse.json({ ok: false, error: "The conflict check is unavailable. Please try again." },{ status: 503 })); }
}
