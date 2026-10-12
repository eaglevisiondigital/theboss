import "server-only";
import { redirect } from "next/navigation";
import { createClient } from "../supabase/server";
import { getLoginPath } from "./redirects";
import { getVerifiedIdentity } from "./verified-identity";

export async function requireSession(next: unknown = "/app") {
  let identity = null;
  try {
    identity = await getVerifiedIdentity(await createClient());
  } catch {
    // Missing configuration is a deployment error, never an authenticated bypass.
  }
  if (!identity) redirect(getLoginPath(next, "expired"));
  return identity;
}
