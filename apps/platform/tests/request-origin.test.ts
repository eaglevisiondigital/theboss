import assert from "node:assert/strict";
import test from "node:test";
import { getAuthCookieOptions, getRequestOrigin } from "../src/lib/auth/request-origin";
import { isSameOriginPost } from "../src/lib/auth/request-security";
import { getLoginPath } from "../src/lib/auth/redirects";

const approvedOrigin = "https://platform.boss.invalid";
const request = (headers: HeadersInit = {}) => new Request("http://platform.boss.invalid:443/auth/login", {
  method: "POST",
  headers: { host: "platform.boss.invalid", origin: approvedOrigin, "sec-fetch-site": "same-origin", ...headers },
});

test("approved origin fixes adapter URL normalization while binding the actual Host", () => {
  assert.equal(isSameOriginPost(request()), false);
  assert.equal(isSameOriginPost(request(), approvedOrigin), true);
  assert.equal(isSameOriginPost(request({ host: "PLATFORM.BOSS.INVALID:443" }), approvedOrigin), true);
  const rejectedHeaders: HeadersInit[] = [
    { host: "foreign.boss.invalid" }, { host: "platform.boss.invalid:8443" }, { host: "" },
    { host: "platform.boss.invalid,foreign.boss.invalid" },
    { host: "platform.boss.invalid/" }, { origin: "https://foreign.boss.invalid" },
    { origin: "null" }, { origin: `${approvedOrigin}/path` },
    { "sec-fetch-site": "cross-site" },
  ];
  for (const headers of rejectedHeaders) assert.equal(isSameOriginPost(request(headers), approvedOrigin), false);
});

test("hostile forwarding headers cannot change POST policy, redirect origin or HTTPS cookie security", () => {
  const spoofed = request({ "x-forwarded-host": "foreign.boss.invalid", "x-forwarded-proto": "http", forwarded: "host=foreign.boss.invalid;proto=http" });
  assert.equal(isSameOriginPost(spoofed, approvedOrigin), true);
  assert.equal(getRequestOrigin(spoofed, approvedOrigin), approvedOrigin);
  const redirect = new URL(getLoginPath("https://foreign.boss.invalid", "invalid"), getRequestOrigin(spoofed, approvedOrigin));
  assert.equal(redirect.origin, approvedOrigin);
  assert.equal(redirect.searchParams.get("next"), "/app");
  assert.deepEqual(getAuthCookieOptions(spoofed, approvedOrigin), { path: "/", sameSite: "lax", secure: true });
  assert.equal(isSameOriginPost(request({ host: "foreign.boss.invalid", "x-forwarded-host": "platform.boss.invalid" }), approvedOrigin), false);
  assert.equal(getAuthCookieOptions(new Request("http://localhost:3000/login")).secure, false);
});
