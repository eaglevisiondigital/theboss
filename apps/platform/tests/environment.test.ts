import assert from "node:assert/strict";
import test from "node:test";
import { BOSS_SUPABASE_URL, EnvironmentConfigurationError, parsePublicEnvironment, parseServerEnvironment } from "../src/lib/env/validation";
import { PUBLIC_ENVIRONMENT_FIXTURE } from "./fixtures";

test("requires canonical public configuration and freezes validated output", () => {
  const parsed = parsePublicEnvironment(PUBLIC_ENVIRONMENT_FIXTURE);
  assert.equal(parsed.supabaseUrl, BOSS_SUPABASE_URL);
  assert.ok(Object.isFrozen(parsed));
  assert.throws(() => parsePublicEnvironment({}), EnvironmentConfigurationError);
});

test("rejects other projects and URL ambiguity", () => {
  for (const url of [
    "https://anotherproject.supabase.co",
    "http://ilykgwgmxtrrikreacrz.supabase.co",
    `${BOSS_SUPABASE_URL}/auth/v1`,
    `${BOSS_SUPABASE_URL}?project=other`,
    "https://user:password@ilykgwgmxtrrikreacrz.supabase.co",
    "not a URL",
  ]) {
    assert.throws(() => parsePublicEnvironment({ ...PUBLIC_ENVIRONMENT_FIXTURE, NEXT_PUBLIC_SUPABASE_URL: url }));
  }
});

test("rejects privileged, legacy and placeholder key values without echoing them", () => {
  for (const key of [
    "sb_secret_SUPER_PRIVATE_NEVER_PRINT",
    "eyJhbGciOiJIUzI1NiJ9.privileged.jwt",
    "sb_publishable_replace_with_your_key",
    "sb_publishable_placeholder123456789",
    "",
  ]) {
    assert.throws(
      () => parsePublicEnvironment({ ...PUBLIC_ENVIRONMENT_FIXTURE, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key }),
      (error: unknown) => error instanceof EnvironmentConfigurationError &&
        (key.length === 0 || !error.message.includes(key)),
    );
  }
});

test("rejects other public privileged variable names and secret key values", () => {
  for (const accidental of [
    { NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY: "private-value" },
    { NEXT_PUBLIC_DATABASE_PASSWORD: "private-value" },
    { NEXT_PUBLIC_API_KEY: "sb_secret_private-value" },
  ]) {
    assert.throws(() => parsePublicEnvironment({ ...PUBLIC_ENVIRONMENT_FIXTURE, ...accidental }));
  }
});

test("server parser exposes only the validated runtime mode", () => {
  assert.deepEqual(parseServerEnvironment({ NODE_ENV: "production", DATABASE_PASSWORD: "private-value" }), {
    nodeEnvironment: "production",
  });
  assert.throws(() => parseServerEnvironment({ NODE_ENV: "unrecognized" }), EnvironmentConfigurationError);
});
