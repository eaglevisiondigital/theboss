const LOCAL_ORIGIN = "https://boss.invalid";

export function getSafeNextPath(value: unknown): string {
  if (
    typeof value !== "string" || value.length > 2048 ||
    !value.startsWith("/") || value.startsWith("//") ||
    // eslint-disable-next-line no-control-regex -- Reject control bytes in redirect targets.
    /[\\\u0000-\u0020\u007f]/.test(value) || /%[0-9a-f]{2}/i.test(value)
  ) return "/app";

  try {
    const url = new URL(value, LOCAL_ORIGIN);
    if (
      url.origin !== LOCAL_ORIGIN || url.hash ||
      (url.pathname !== "/app" && !url.pathname.startsWith("/app/"))
    ) return "/app";
    return `${url.pathname}${url.search}`;
  } catch {
    return "/app";
  }
}

export type LoginErrorCode = "invalid" | "unavailable" | "expired";

export function getLoginPath(next: unknown = "/app", error?: LoginErrorCode): string {
  const params = new URLSearchParams({ next: getSafeNextPath(next) });
  if (error) params.set("error", error);
  return `/login?${params.toString()}`;
}
