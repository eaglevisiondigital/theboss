import type { NextConfig } from "next";
import path from "node:path";
import { SECURITY_HEADERS } from "./src/lib/security-headers";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  productionBrowserSourceMaps: false,
  // Compile only existing Netlify public build identifiers, never environment data.
  env: {
    BOSS_DIAGNOSTIC_COMMIT: /^[a-f0-9]{40}$/.test(process.env.COMMIT_REF ?? "") ? process.env.COMMIT_REF : "local",
    BOSS_DIAGNOSTIC_DEPLOY: /^[a-f0-9]{24}$/.test(process.env.DEPLOY_ID ?? "") ? process.env.DEPLOY_ID : "local",
  },
  turbopack: { root: path.resolve(process.cwd()) },
  outputFileTracingRoot: path.resolve(process.cwd()),
  async headers() {
    return [
      { source: "/:path*", headers: [...SECURITY_HEADERS] },
      ...["/app/:path*", "/auth/:path*", "/login", "/health"].map((source) => ({
        source,
        headers: [{ key: "Cache-Control", value: "private, no-store, max-age=0" }],
      })),
      { source: "/recruiting/:path*", headers: [{ key: "Cache-Control", value: "private, no-store, max-age=0" }, { key: "Netlify-CDN-Cache-Control", value: "no-store" }, { key: "CDN-Cache-Control", value: "no-store" }, { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive, noimageindex" }] },
    ];
  },
};

export default nextConfig;
