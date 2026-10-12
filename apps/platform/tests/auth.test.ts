import assert from "node:assert/strict";
import test from "node:test";
import { getLoginPath, getSafeNextPath } from "../src/lib/auth/redirects";
import { getLoginCredentials, isSameOriginPost, readLoginForm } from "../src/lib/auth/request-security";
import { getVerifiedIdentity } from "../src/lib/auth/verified-identity";
import { VERIFIED_CLAIMS_FIXTURE } from "./fixtures";

test("redirects permit normalized local application routes only", () => {
  assert.equal(getSafeNextPath("/app"), "/app");
  assert.equal(getSafeNextPath("/app/account?tab=details"), "/app/account?tab=details");
  assert.equal(getSafeNextPath("/app/../app/account"), "/app/account");
  for (const value of [
    undefined, null, 123, "https://evil.invalid/app", "//evil.invalid/app",
    "/\\evil.invalid/app", "/app/../../login", "/application", "/app#fragment",
    "/app/%2e%2e/login", "/app%2f..%2flogin", "/app\nLocation: https://evil.invalid",
  ]) assert.equal(getSafeNextPath(value), "/app");
  const login = new URL(getLoginPath("https://evil.invalid", "invalid"), "https://boss.invalid");
  assert.equal(login.pathname, "/login");
  assert.equal(login.searchParams.get("next"), "/app");
  assert.equal(login.searchParams.get("error"), "invalid");
});

test("credential mutation requires a matching explicit Origin", () => {
  const make = (headers: HeadersInit, method = "POST") => new Request("https://boss.invalid/auth/login", { method, headers });
  assert.equal(isSameOriginPost(make({ origin: "https://boss.invalid", "sec-fetch-site": "same-origin" })), true);
  assert.equal(isSameOriginPost(make({ origin: "https://boss.invalid" })), true);
  const rejectedHeaders: HeadersInit[] = [
    {}, { origin: "null" }, { origin: "https://evil.invalid" },
    { origin: "https://boss.invalid.evil.invalid" },
    { origin: "https://boss.invalid/path" },
    { origin: "https://boss.invalid", "sec-fetch-site": "same-site" },
    { origin: "https://boss.invalid", "sec-fetch-site": "cross-site" },
  ];
  for (const headers of rejectedHeaders) assert.equal(isSameOriginPost(make(headers)), false);
  assert.equal(isSameOriginPost(make({ origin: "https://boss.invalid" }, "GET")), false);
});

test("login parser bounds the actual request body and rejects duplicate credentials", async () => {
  const make = (body: string, headers: HeadersInit = {}) => new Request("https://boss.invalid/auth/login", {
    method: "POST", body, headers: { "content-type": "application/x-www-form-urlencoded", ...headers },
  });
  const form = await readLoginForm(make("email=person%40boss.invalid&password=existing-password&next=%2Fapp"));
  assert.ok(form);
  assert.deepEqual(getLoginCredentials(form), { email: "person@boss.invalid", password: "existing-password" });
  assert.equal(await readLoginForm(make("password=" + "A".repeat(16_385))), null);
  assert.equal(await readLoginForm(make("email=a&email=b&password=p")), null);
  assert.equal(await readLoginForm(make("email=a", { "content-type": "application/json" })), null);
  assert.equal(getLoginCredentials(new URLSearchParams({ email: "not-an-email", password: "p" })), null);
  assert.equal(getLoginCredentials(new URLSearchParams({ email: "p@boss.invalid", password: "A".repeat(1025) })), null);
});

test("verified claims return subject only and ignore user-editable permission metadata", async () => {
  const identity = await getVerifiedIdentity({ auth: { getClaims: async () => ({
    data: { claims: { ...VERIFIED_CLAIMS_FIXTURE, email: "private@boss.invalid", user_metadata: { is_admin: true } } },
    error: null,
  }) } });
  assert.deepEqual(identity, { subject: VERIFIED_CLAIMS_FIXTURE.sub });
  assert.ok(Object.isFrozen(identity));
});

test("authentication fails closed on missing, expired, foreign, anonymous, privileged or failed claims", async () => {
  for (const claims of [
    {}, { ...VERIFIED_CLAIMS_FIXTURE, exp: 0 },
    { ...VERIFIED_CLAIMS_FIXTURE, sub: "not-a-user-id" },
    { ...VERIFIED_CLAIMS_FIXTURE, iss: "https://other.supabase.co/auth/v1" },
    { ...VERIFIED_CLAIMS_FIXTURE, role: "service_role" },
    { ...VERIFIED_CLAIMS_FIXTURE, is_anonymous: true },
  ]) {
    assert.equal(await getVerifiedIdentity({ auth: { getClaims: async () => ({ data: { claims }, error: null }) } }), null);
  }
  assert.equal(await getVerifiedIdentity({ auth: { getClaims: async () => ({ data: null, error: null }) } }), null);
  assert.equal(await getVerifiedIdentity({ auth: { getClaims: async () => ({ data: { claims: VERIFIED_CLAIMS_FIXTURE }, error: new Error("private failure") }) } }), null);
  assert.equal(await getVerifiedIdentity({ auth: { getClaims: async () => { throw new Error("upstream unavailable"); } } }), null);
});
