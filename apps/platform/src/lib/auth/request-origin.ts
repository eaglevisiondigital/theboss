// Production callers supply the validated server configuration. Neither Host nor
// forwarding headers determine credential POST protection, redirects or cookies.
export function getRequestOrigin(request: Request, configuredOrigin?: string): string {
  return configuredOrigin ?? new URL(request.url).origin;
}

export function getAuthCookieOptions(request: Request, configuredOrigin?: string) {
  return {
    path: "/",
    sameSite: "lax" as const,
    secure: new URL(getRequestOrigin(request, configuredOrigin)).protocol === "https:",
  };
}
