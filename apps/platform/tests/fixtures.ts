import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";

// Format-only synthetic fixture. It is not a working Supabase API credential.
export const PUBLIC_ENVIRONMENT_FIXTURE = {
  NEXT_PUBLIC_SUPABASE_URL: BOSS_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_aA9bB8cC7dD6eE5fF4gG3hH2iI1jJ0kK",
  NODE_ENV: "test",
};

export const VERIFIED_CLAIMS_FIXTURE = {
  sub: "12345678-1234-4123-8123-123456789abc",
  iss: `${BOSS_SUPABASE_URL}/auth/v1`,
  role: "authenticated",
  exp: Math.floor(Date.now() / 1000) + 3600,
  is_anonymous: false,
};
