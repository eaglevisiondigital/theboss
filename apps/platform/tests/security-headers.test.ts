import assert from "node:assert/strict";
import test from "node:test";
import { NextResponse } from "next/server";
import { copySessionResponse, preventAuthCaching } from "../src/lib/supabase/response";

function assertProtectedResponse(response: NextResponse) {
  assert.equal(response.headers.get("X-Frame-Options"), "DENY");
  assert.equal(response.headers.get("X-Content-Type-Options"), "nosniff");
  assert.equal(response.headers.get("Referrer-Policy"), "strict-origin-when-cross-origin");
  assert.equal(response.headers.get("Permissions-Policy"), "camera=(), microphone=(), geolocation=()");
  assert.equal(response.headers.get("Strict-Transport-Security"), "max-age=31536000");
  assert.equal(response.headers.get("X-Robots-Tag"), "noindex, nofollow, noarchive");
  assert.equal(
    response.headers.get("Content-Security-Policy"),
    "frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'",
  );
  assert.equal(
    response.headers.get("Content-Security-Policy-Report-Only"),
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://ilykgwgmxtrrikreacrz.supabase.co; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
  );
  assert.equal(response.headers.get("Cache-Control"), "private, no-store, max-age=0");
  assert.equal(response.headers.get("Netlify-CDN-Cache-Control"), "no-store");
  assert.equal(response.headers.get("CDN-Cache-Control"), "no-store");
  assert.equal(response.headers.get("Pragma"), "no-cache");
  assert.equal(response.headers.get("Expires"), "0");
}

test("early proxy redirects retain the full security policy and every session cookie update", () => {
  const session = new NextResponse(null);
  const options = { path: "/", secure: true, sameSite: "lax" as const, maxAge: 3600 };
  session.cookies.set("sb-test-auth-token.0", "synthetic-first-chunk", options);
  session.cookies.set("sb-test-auth-token.1", "synthetic-second-chunk", options);
  session.cookies.set("sb-test-auth-token.2", "", { ...options, maxAge: 0 });
  // A session or adapter's less restrictive cache value must not win on redirect.
  session.headers.set("Cache-Control", "public, max-age=3600");
  const destination = NextResponse.redirect("https://boss.invalid/login?next=%2Fapp", 307);
  const result = copySessionResponse(session, destination);

  assert.equal(result, destination);
  assert.equal(result.status, 307);
  assert.equal(result.headers.get("Location"), "https://boss.invalid/login?next=%2Fapp");
  assertProtectedResponse(result);
  assert.equal(result.cookies.getAll().length, 3);
  assert.equal(result.cookies.get("sb-test-auth-token.0")?.value, "synthetic-first-chunk");
  assert.equal(result.cookies.get("sb-test-auth-token.1")?.value, "synthetic-second-chunk");
  assert.equal(result.cookies.get("sb-test-auth-token.2")?.maxAge, 0);
  for (const cookie of result.cookies.getAll()) {
    assert.equal(cookie.path, "/");
    assert.equal(cookie.secure, true);
    assert.equal(cookie.sameSite, "lax");
    assert.equal(cookie.domain, undefined);
  }
});

test("rejected auth responses receive the same security policy without changing their contract", async () => {
  const response = NextResponse.json({ error: "Request not permitted." }, { status: 403 });
  const result = preventAuthCaching(response);
  assert.equal(result, response);
  assert.equal(result.status, 403);
  assert.equal(result.cookies.getAll().length, 0);
  assertProtectedResponse(result);
  assert.deepEqual(await result.json(), { error: "Request not permitted." });
});
