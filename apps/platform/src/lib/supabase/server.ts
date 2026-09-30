import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { getPublicEnvironment } from "../env/public";
import { getServerEnvironment } from "../env/server";

// Server Components cannot write cookies. The proxy owns refresh propagation.
// Mutating route handlers use the response-aware adapter in route-client.ts.
export async function createClient() {
  const environment = getPublicEnvironment();
  const serverEnvironment = getServerEnvironment();
  const cookieStore = await cookies();

  return createServerClient(environment.supabaseUrl, environment.supabasePublishableKey, {
    cookieOptions: {
      path: "/",
      sameSite: "lax",
      secure: serverEnvironment.nodeEnvironment === "production",
    },
    global: {
      fetch: (input, init) => fetch(input, { ...init, cache: "no-store" }),
    },
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: () => {
        // Read-only Server Component adapter. src/proxy.ts refreshes first.
      },
    },
  });
}
