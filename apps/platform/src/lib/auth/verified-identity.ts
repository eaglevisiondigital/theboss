import { BOSS_SUPABASE_URL } from "../env/validation";

export type AuthenticatedIdentity = Readonly<{ subject: string }>;

type ClaimsClient = {
  auth: {
    getClaims(): Promise<{
      data: { claims: Record<string, unknown> } | null;
      error: unknown;
    }>;
  };
};

// Call only through a client whose getClaims() cryptographically verifies the token.
// This projection is authentication only. It grants no Boss business permission.
export async function getVerifiedIdentity(client: ClaimsClient): Promise<AuthenticatedIdentity | null> {
  try {
    const { data, error } = await client.auth.getClaims();
    const claims = data?.claims;
    if (
      error || !claims || typeof claims.sub !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(claims.sub) ||
      claims.iss !== `${BOSS_SUPABASE_URL}/auth/v1` ||
      claims.role !== "authenticated" || claims.is_anonymous === true ||
      typeof claims.exp !== "number" || !Number.isFinite(claims.exp) ||
      claims.exp <= Math.floor(Date.now() / 1000)
    ) return null;

    return Object.freeze({ subject: claims.sub });
  } catch {
    // Upstream failures, expired sessions, and forged cookies all fail closed.
    return null;
  }
}
