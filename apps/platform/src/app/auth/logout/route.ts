import { type NextRequest, NextResponse } from "next/server";
import { getLoginPath } from "@/lib/auth/redirects";
import { isSameOriginPost } from "@/lib/auth/request-security";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  if (!isSameOriginPost(request)) {
    return preventAuthCaching(NextResponse.json({ error: "Request not permitted." }, { status: 403 }));
  }
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const route = createRouteClient(request);
    const client = route.client;
    finish = route.finish;
    // This browser's session only. Cross-device policies await identity approval.
    const { error } = await client.auth.signOut({ scope: "local" });
    const destination = error ? getLoginPath("/app", "unavailable") : "/login";
    return finish(NextResponse.redirect(new URL(destination, request.url), 303));
  } catch {
    return finish(NextResponse.redirect(new URL(getLoginPath("/app", "unavailable"), request.url), 303));
  }
}
