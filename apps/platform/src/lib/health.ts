import { parsePublicEnvironment, parseServerEnvironment } from "./env/validation";

export function getHealthStatus(environment: Readonly<Record<string, string | undefined>>) {
  try {
    parsePublicEnvironment(environment);
    parseServerEnvironment(environment);
    return { status: "ok" as const, httpStatus: 200 };
  } catch {
    return { status: "unconfigured" as const, httpStatus: 503 };
  }
}
