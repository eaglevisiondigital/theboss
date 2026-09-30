import assert from "node:assert/strict";
import test from "node:test";
import { NextResponse } from "next/server";
import { getHealthStatus } from "../src/lib/health";
import { copySessionResponse } from "../src/lib/supabase/response";
import { PUBLIC_ENVIRONMENT_FIXTURE } from "./fixtures";

test("health reports configuration readiness without credentials or backend calls", () => {
  assert.deepEqual(getHealthStatus(PUBLIC_ENVIRONMENT_FIXTURE), { status: "ok", httpStatus: 200 });
  assert.deepEqual(getHealthStatus({}), { status: "unconfigured", httpStatus: 503 });
  assert.deepEqual(getHealthStatus({ ...PUBLIC_ENVIRONMENT_FIXTURE, NODE_ENV: "unknown" }), { status: "unconfigured", httpStatus: 503 });
});

test("redirects retain refreshed session cookies and prohibit shared caching", () => {
  const source = new NextResponse(null);
  source.cookies.set("sb-session", "synthetic-cookie", { path: "/", secure: true, sameSite: "lax", maxAge: 3600 });
  source.headers.set("Cache-Control", "private, no-store");
  const destination = NextResponse.redirect("https://boss.invalid/login", 303);
  const result = copySessionResponse(source, destination);
  assert.equal(result.status, 303);
  assert.equal(result.cookies.get("sb-session")?.value, "synthetic-cookie");
  assert.match(result.headers.get("set-cookie") ?? "", /Secure/);
  assert.match(result.headers.get("set-cookie") ?? "", /SameSite=lax/);
  assert.match(result.headers.get("Cache-Control") ?? "", /private, no-store/);
  assert.equal(result.headers.get("Netlify-CDN-Cache-Control"), "no-store");
});
