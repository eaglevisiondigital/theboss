import type { NextConfig } from "next";
import path from "node:path";
import { SECURITY_HEADERS } from "./src/lib/security-headers";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  productionBrowserSourceMaps: false,
  turbopack: { root: path.resolve(process.cwd()) },
  outputFileTracingRoot: path.resolve(process.cwd()),
  async headers() {
    return [
      { source: "/:path*", headers: [...SECURITY_HEADERS] },
      ...["/app/:path*", "/auth/:path*", "/login", "/health"].map((source) => ({
        source,
        headers: [{ key: "Cache-Control", value: "private, no-store, max-age=0" }],
      })),
    ];
  },
};

export default nextConfig;
