import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { PUBLIC_ENVIRONMENT_FIXTURE } from "./fixtures";

const platformDirectory = process.cwd();
const platformRequire = createRequire(join(platformDirectory, "package.json"));
const tsxLoader = platformRequire.resolve("tsx");
const checkEnvironmentScript = resolve(platformDirectory, "scripts/check-env.ts");
const validConfiguration = `NEXT_PUBLIC_SUPABASE_URL=${PUBLIC_ENVIRONMENT_FIXTURE.NEXT_PUBLIC_SUPABASE_URL}\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${PUBLIC_ENVIRONMENT_FIXTURE.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY}\n`;
const invalidConfiguration = "NEXT_PUBLIC_SUPABASE_URL=https://other-project.supabase.co\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=replace_with_canonical_publishable_key\n";

function runCheck(files: Record<string, string>, extraEnvironment: Record<string, string> = {}) {
  const directory = mkdtempSync(join(tmpdir(), "boss-env-cli-"));
  try {
    for (const [name, contents] of Object.entries(files)) writeFileSync(join(directory, name), contents);
    const environment = { ...process.env };
    for (const name of Object.keys(environment)) {
      if (name.startsWith("NEXT_PUBLIC_") || name.startsWith("__NEXT_") || name === "NODE_ENV" || name === "npm_lifecycle_event") {
        delete environment[name];
      }
    }
    return spawnSync(process.execPath, ["--import", tsxLoader, checkEnvironmentScript], {
      cwd: directory,
      env: { ...environment, ...extraEnvironment },
      encoding: "utf8",
      timeout: 10_000,
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("exact environment CLI selects development files for dev when NODE_ENV is unset", () => {
  const result = runCheck({ ".env.development": validConfiguration, ".env.production": invalidConfiguration }, { npm_lifecycle_event: "dev" });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /environment validation passed/);
});

test("exact environment CLI selects production files for build, start and standalone checks", () => {
  for (const lifecycle of ["build", "start", undefined]) {
    const result = runCheck(
      { ".env.development": invalidConfiguration, ".env.production": validConfiguration },
      lifecycle ? { npm_lifecycle_event: lifecycle } : {},
    );
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stderr);
  }
});

test("invalid production configuration cannot pass because development files are valid", () => {
  const result = runCheck({ ".env.development": validConfiguration, ".env.production": invalidConfiguration }, { npm_lifecycle_event: "build" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /NEXT_PUBLIC_SUPABASE_URL/);
  assert.doesNotMatch(result.stderr, /other-project|replace_with_canonical_publishable_key|TypeError/);
});

test("explicit NODE_ENV follows Next command-phase and test-mode loading rules", () => {
  const build = runCheck(
    { ".env.development": invalidConfiguration, ".env.production": validConfiguration },
    { NODE_ENV: "development", npm_lifecycle_event: "build" },
  );
  assert.equal(build.status, 0, build.stderr);
  const development = runCheck(
    { ".env.development": validConfiguration, ".env.production": invalidConfiguration },
    { NODE_ENV: "production", npm_lifecycle_event: "dev" },
  );
  assert.equal(development.status, 0, development.stderr);
  const testing = runCheck(
    { ".env.test": validConfiguration, ".env.local": invalidConfiguration, ".env.production": invalidConfiguration },
    { NODE_ENV: "test", npm_lifecycle_event: "build" },
  );
  assert.equal(testing.status, 0, testing.stderr);
  const invalidMode = runCheck({ ".env.production": validConfiguration }, { NODE_ENV: "invalid-runtime" });
  assert.equal(invalidMode.status, 1);
  assert.match(invalidMode.stderr, /NODE_ENV/);
});
