import assert from "node:assert/strict";
import test from "node:test";
import { NextResponse } from "next/server";
import { getHealthStatus } from "../src/lib/health";
import { copySessionResponse } from "../src/lib/supabase/response";
import { PUBLIC_ENVIRONMENT_FIXTURE } from "./fixtures";
import { GET as getHealthRoute } from "../src/app/health/route";

test("health reports configuration readiness without credentials or backend calls", () => {
  assert.deepEqual(getHealthStatus(PUBLIC_ENVIRONMENT_FIXTURE), { status: "ok", httpStatus: 200 });
  assert.deepEqual(getHealthStatus({}), { status: "unconfigured", httpStatus: 503 });
  assert.deepEqual(getHealthStatus({ ...PUBLIC_ENVIRONMENT_FIXTURE, NODE_ENV: "unknown" }), { status: "unconfigured", httpStatus: 503 });
});

test("actual health route validates the full hosted production configuration", async () => {
  const names = ["NODE_ENV", "NETLIFY", "BOSS_PLATFORM_ORIGIN", "NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"];
  const original = Object.fromEntries(names.map((name) => [name, process.env[name]]));
  try {
    Object.assign(process.env, PUBLIC_ENVIRONMENT_FIXTURE, {
      NODE_ENV: "production", NETLIFY: "true", BOSS_PLATFORM_ORIGIN: "https://platform.boss.invalid",
    });
    const ready = await getHealthRoute();
    assert.equal(ready.status, 200);
    assert.deepEqual(await ready.json(), { status: "ok" });
    assert.match(ready.headers.get("Cache-Control") ?? "", /private, no-store/);
    delete process.env.BOSS_PLATFORM_ORIGIN;
    assert.equal((await getHealthRoute()).status, 503);
    Object.assign(process.env, { BOSS_PLATFORM_ORIGIN: "http://localhost:3000" });
    assert.equal((await getHealthRoute()).status, 503);
  } finally {
    for (const name of names) {
      const value = original[name];
      if (value === undefined) delete process.env[name];
      else Object.assign(process.env, { [name]: value });
    }
  }
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
