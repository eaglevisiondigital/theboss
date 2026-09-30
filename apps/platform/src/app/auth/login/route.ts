import { type NextRequest, NextResponse } from "next/server";
import { getLoginPath, getSafeNextPath } from "@/lib/auth/redirects";
import { getLoginCredentials, isSameOriginPost, readLoginForm } from "@/lib/auth/request-security";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  if (!isSameOriginPost(request)) {
    return preventAuthCaching(NextResponse.json({ error: "Request not permitted." }, { status: 403 }));
  }
  const form = await readLoginForm(request);
  const next = getSafeNextPath(form?.get("next"));
  const credentials = form && getLoginCredentials(form);
  if (!credentials) {
    return preventAuthCaching(NextResponse.redirect(new URL(getLoginPath(next, "invalid"), request.url), 303));
  }

  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const route = createRouteClient(request);
    const client = route.client;
    finish = route.finish;
    const { error } = await client.auth.signInWithPassword(credentials);
    const destination = error ? getLoginPath(next, "invalid") : next;
    return finish(NextResponse.redirect(new URL(destination, request.url), 303));
  } catch {
    return finish(NextResponse.redirect(new URL(getLoginPath(next, "unavailable"), request.url), 303));
  }
}
