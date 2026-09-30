import "server-only";
import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { getPublicEnvironment } from "../env/public";
import { getServerEnvironment } from "../env/server";
import { copySessionResponse, preventAuthCaching } from "./response";
import { getAuthCookieOptions } from "../auth/request-origin";

export function createRouteClient(request: NextRequest) {
  const environment = getPublicEnvironment();
  const serverEnvironment = getServerEnvironment();
  const sessionResponse = preventAuthCaching(new NextResponse(null));
  const client = createServerClient(environment.supabaseUrl, environment.supabasePublishableKey, {
    cookieOptions: getAuthCookieOptions(request, serverEnvironment.platformOrigin),
    global: { fetch: (input, init) => fetch(input, { ...init, cache: "no-store" }) },
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (updates, cacheHeaders) => {
        updates.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          sessionResponse.cookies.set(name, value, options);
        });
        Object.entries(cacheHeaders).forEach(([name, value]) => sessionResponse.headers.set(name, value));
      },
    },
  });

  return { client, finish: (response: NextResponse) => copySessionResponse(sessionResponse, response) };
}
