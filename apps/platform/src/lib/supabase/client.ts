"use client";

import { createBrowserClient } from "@supabase/ssr";
import { getPublicEnvironment } from "../env/public";

export function createClient() {
  const environment = getPublicEnvironment();
  return createBrowserClient(environment.supabaseUrl, environment.supabasePublishableKey, {
    cookieOptions: { path: "/", sameSite: "lax", secure: process.env.NODE_ENV === "production" },
  });
}
