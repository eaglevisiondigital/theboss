import { createServerClient } from "@supabase/ssr";
import type { Database } from "./database.types";
import { type NextRequest, NextResponse } from "next/server";
import { getPublicEnvironment } from "../env/public";
import { getServerEnvironment } from "../env/server";
import { getLoginPath, getSafeNextPath } from "../auth/redirects";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { copySessionResponse, preventAuthCaching } from "./response";
import { getAuthCookieOptions, getRequestOrigin } from "../auth/request-origin";

export async function updateSession(request: NextRequest) {
  let response = preventAuthCaching(NextResponse.next({ request }));
  const protectedPath = request.nextUrl.pathname === "/app" || request.nextUrl.pathname.startsWith("/app/");
  let identity = null;
  let configured = true;
  let origin = new URL(request.url).origin;
  try {
    const environment = getPublicEnvironment();
    const serverEnvironment = getServerEnvironment();
    origin = getRequestOrigin(request, serverEnvironment.platformOrigin);
    const client = createServerClient<Database>(environment.supabaseUrl, environment.supabasePublishableKey, {
      cookieOptions: getAuthCookieOptions(request, serverEnvironment.platformOrigin),
      global: { fetch: (input, init) => fetch(input, { ...init, cache: "no-store" }) },
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (updates, cacheHeaders) => {
          updates.forEach(({ name, value }) => request.cookies.set(name, value));
          const refreshedResponse = NextResponse.next({ request });
          // Preserve all updates if the SDK invokes the cookie adapter more than once.
          copySessionResponse(response, refreshedResponse);
          updates.forEach(({ name, value, options }) => refreshedResponse.cookies.set(name, value, options));
          Object.entries(cacheHeaders).forEach(([name, value]) => refreshedResponse.headers.set(name, value));
          response = preventAuthCaching(refreshedResponse);
        },
      },
    });
    identity = await getVerifiedIdentity(client);
  } catch {
    configured = false;
  }

  if (protectedPath && !identity) {
    const next = getSafeNextPath(`${request.nextUrl.pathname}${request.nextUrl.search}`);
    const login = new URL(getLoginPath(next, configured ? undefined : "unavailable"), origin);
    return copySessionResponse(response, NextResponse.redirect(login));
  }

  return preventAuthCaching(response);
}
