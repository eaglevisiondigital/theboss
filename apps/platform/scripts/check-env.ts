import { loadEnvConfig } from "@next/env";
import { EnvironmentConfigurationError, parsePublicEnvironment, parseServerEnvironment } from "../src/lib/env/validation";

// Match Next.js's lifecycle mode before its own CLI has set NODE_ENV. Build/start
// must validate production files, never an unrelated development configuration.
const developmentCommand = process.env.npm_lifecycle_event === "dev";
if (!process.env.NODE_ENV) {
  Object.assign(process.env, { NODE_ENV: developmentCommand ? "development" : "production" });
}
// Next's loader uses command phase for development/production files and gives
// an explicit NODE_ENV=test precedence. Match its behavior even if NODE_ENV was
// supplied independently of the command. Validate that runtime mode separately.
loadEnvConfig(process.cwd(), developmentCommand);
try {
  parsePublicEnvironment(process.env);
  parseServerEnvironment(process.env);
  console.info("Platform public and server environment validation passed.");
} catch (error) {
  console.error(error instanceof EnvironmentConfigurationError ? error.message : "Platform environment validation failed.");
  process.exitCode = 1;
}
