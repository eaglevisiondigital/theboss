export const BOSS_SUPABASE_PROJECT_REF = "ilykgwgmxtrrikreacrz";
export const BOSS_SUPABASE_URL = `https://${BOSS_SUPABASE_PROJECT_REF}.supabase.co`;

type EnvironmentSource = Readonly<Record<string, string | undefined>>;

export type PublicEnvironment = Readonly<{
  supabaseUrl: string;
  supabasePublishableKey: string;
}>;

export type ServerEnvironment = Readonly<{
  nodeEnvironment: "development" | "test" | "production";
  platformOrigin?: string;
}>;

export class EnvironmentConfigurationError extends Error {
  constructor(issues: readonly string[]) {
    // Never include supplied values. An incorrectly supplied key might be privileged.
    super(`Platform configuration is invalid: ${issues.join("; ")}.`);
    this.name = "EnvironmentConfigurationError";
  }
}

export function parsePublicEnvironment(source: EnvironmentSource): PublicEnvironment {
  const issues: string[] = [];
  const urlValue = source.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const keyValue = source.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim();

  if (
    Object.entries(source).some(([name, value]) =>
      name.startsWith("NEXT_PUBLIC_") && value &&
      (/SECRET|SERVICE_ROLE|PASSWORD|PRIVATE_KEY|DATABASE_URL/i.test(name) ||
        value.startsWith("sb_secret_"))
    )
  ) {
    issues.push("privileged NEXT_PUBLIC_ configuration is forbidden");
  }

  if (!urlValue) {
    issues.push("NEXT_PUBLIC_SUPABASE_URL is required");
  } else {
    try {
      const url = new URL(urlValue);
      if (
        url.origin !== BOSS_SUPABASE_URL || url.pathname !== "/" ||
        url.search || url.hash || url.username || url.password
      ) {
        issues.push("NEXT_PUBLIC_SUPABASE_URL must identify the canonical Boss project");
      }
    } catch {
      issues.push("NEXT_PUBLIC_SUPABASE_URL must be a valid canonical HTTPS URL");
    }
  }

  if (!keyValue) {
    issues.push("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");
  } else if (
    !/^sb_publishable_[A-Za-z0-9_-]{20,200}$/.test(keyValue) ||
    /placeholder|replace|example|your[_-]?|changeme/i.test(keyValue)
  ) {
    issues.push("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be a nonplaceholder publishable key");
  }

  if (issues.length > 0) throw new EnvironmentConfigurationError(issues);

  return Object.freeze({
    supabaseUrl: BOSS_SUPABASE_URL,
    supabasePublishableKey: keyValue!,
  });
}

export function parseServerEnvironment(source: EnvironmentSource): ServerEnvironment {
  const nodeEnvironment = source.NODE_ENV ?? "development";
  const issues: string[] = [];
  if (
    nodeEnvironment !== "development" && nodeEnvironment !== "test" &&
    nodeEnvironment !== "production"
  ) {
    issues.push("NODE_ENV must be development, test, or production");
  }
  const originValue = source.BOSS_PLATFORM_ORIGIN?.trim();
  let platformOrigin: string | undefined;
  if (!originValue && nodeEnvironment === "production") {
    issues.push("BOSS_PLATFORM_ORIGIN is required in production");
  } else if (originValue) {
    try {
      const url = new URL(originValue);
      const localHttp = url.protocol === "http:" && source.NETLIFY !== "true" &&
        ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
      if (
        (url.protocol !== "https:" && !localHttp) || url.pathname !== "/" ||
        url.search || url.hash || url.username || url.password || url.hostname.includes("*")
      ) {
        issues.push("BOSS_PLATFORM_ORIGIN must be one approved HTTPS origin (HTTP loopback is local only)");
      } else {
        platformOrigin = url.origin;
      }
    } catch {
      issues.push("BOSS_PLATFORM_ORIGIN must be a valid approved origin");
    }
  }
  if (issues.length > 0) throw new EnvironmentConfigurationError(issues);
  return Object.freeze({
    nodeEnvironment: nodeEnvironment as ServerEnvironment["nodeEnvironment"],
    ...(platformOrigin ? { platformOrigin } : {}),
  });
}
