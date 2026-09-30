import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { getPublicEnvironment } from "../env/public";
import { getServerEnvironment } from "../env/server";
import { getLoginPath, getSafeNextPath } from "../auth/redirects";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { copySessionResponse, preventAuthCaching } from "./response";

export async function updateSession(request: NextRequest) {
  let response = preventAuthCaching(NextResponse.next({ request }));
  const protectedPath = request.nextUrl.pathname === "/app" || request.nextUrl.pathname.startsWith("/app/");
  let identity = null;
  let configured = true;
  try {
    const environment = getPublicEnvironment();
    getServerEnvironment();
    const client = createServerClient(environment.supabaseUrl, environment.supabasePublishableKey, {
      cookieOptions: { path: "/", sameSite: "lax", secure: request.nextUrl.protocol === "https:" },
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
    const login = new URL(getLoginPath(next, configured ? undefined : "unavailable"), request.url);
    return copySessionResponse(response, NextResponse.redirect(login));
  }

  return preventAuthCaching(response);
}
