import { type NextRequest, NextResponse } from "next/server";
import { getLoginPath, getSafeNextPath } from "@/lib/auth/redirects";
import { getLoginCredentials, isSameOriginPost, readLoginForm } from "@/lib/auth/request-security";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { getServerEnvironment } from "@/lib/env/server";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin);
  if (!isSameOriginPost(request, origin)) {
    return preventAuthCaching(NextResponse.json({ error: "Request not permitted." }, { status: 403 }));
  }
  const form = await readLoginForm(request);
  const next = getSafeNextPath(form?.get("next"));
  const credentials = form && getLoginCredentials(form);
  if (!credentials) {
    return preventAuthCaching(NextResponse.redirect(new URL(getLoginPath(next, "invalid"), origin), 303));
  }

  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const route = createRouteClient(request);
    const client = route.client;
    finish = route.finish;
    const { error } = await client.auth.signInWithPassword(credentials);
    const destination = error ? getLoginPath(next, "invalid") : next;
    return finish(NextResponse.redirect(new URL(destination, origin), 303));
  } catch {
    return finish(NextResponse.redirect(new URL(getLoginPath(next, "unavailable"), origin), 303));
  }
}
