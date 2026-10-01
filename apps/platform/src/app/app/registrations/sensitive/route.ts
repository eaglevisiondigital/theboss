import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performSensitiveAccess } from "@/lib/registration/sensitive";

export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin);
    const route = createRouteClient(request); finish = route.finish;
    const result = await performSensitiveAccess(request, route.client, origin);
    return finish(NextResponse.json(result.body, { status: result.status }));
  } catch { return finish(NextResponse.json({ ok: false, error: "Registration changes are unavailable. Please try again." }, { status: 503 })); }
}
