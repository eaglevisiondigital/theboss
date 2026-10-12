// The same policy applies to ordinary Next responses and early proxy responses.
// Netlify can return a proxy redirect before next.config headers are evaluated.
export const SECURITY_HEADERS = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  { key: "Strict-Transport-Security", value: "max-age=31536000" },
  { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive" },
  { key: "Content-Security-Policy", value: "frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'" },
  {
    key: "Content-Security-Policy-Report-Only",
    value: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://ilykgwgmxtrrikreacrz.supabase.co; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
  },
] as const;

export function applySecurityHeaders<T extends { headers: Headers }>(response: T): T {
  SECURITY_HEADERS.forEach(({ key, value }) => response.headers.set(key, value));
  return response;
}
