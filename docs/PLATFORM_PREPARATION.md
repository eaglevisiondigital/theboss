# Platform preparation

Status: Phase 1A shell implemented, pending configured deployment and main Chat
review. Source provenance is in `SOURCE_PROVENANCE.md`; private handoffs remain
outside this repository. No product data model is approved by this document.

## Approved and implemented

- Separate application at `apps/platform`, independently installed from its own
  pinned manifest and lockfile. No root workspace, package manifest, Next.js
  config or Netlify config was added. The root README remains unchanged.
- Branch `build/boss-platform-v1` starts from verified `main` commit
  `47eb2f94a86737bae0a0dc5ecb0a083dac9a0aa4`. No website code was copied or moved.
- Public shell, password-login entry, protected Home/Account shell, logout and
  configuration-readiness endpoint. No user management or business module.
- Supabase browser/server/route clients use public configuration only; claims
  validation, SSR refresh, cookies and private-cache controls establish an
  authentication foundation. Business authorization remains unimplemented.
- Only the separate platform Netlify site was configured. See
  `PHASE_1A_NETLIFY.md` for verified settings and the deployment hold.

## Build and package isolation

Run all package commands from `apps/platform` or use
`npm --prefix apps/platform run <command>`. Installation and generated output
stay within that package. TypeScript includes only platform source/config/tests
and its generated Next types; build tracing and Turbopack root use the package
working directory. No website dependency or build script changed.

The website feature branches remain independent. Before integrating their code
with this branch, review their broad root TypeScript includes so nested platform
source is not accidentally part of the website's build. That root exclusion is
not changed here because the selected main baseline has no website application
and website branches must remain untouched. Future integration needs explicit
website regression and path/configuration tests.

## Planned, requiring a later assignment

- Supply authorized public platform configuration and review Supabase provider,
  signup, origin and callback settings. Real authentication has not been tested.
- Reactivate platform builds only after configuration is ready. Check the actual
  Netlify SSR adapter, headers, redirects, refresh and logout in a hosted test.
- Approve a preview backend and review/release strategy; previews are disabled
  while those choices are unresolved. No production domain is invented.
- Supply approved branding assets if replacing temporary text branding/system
  fonts. No asset from a website draft was silently copied into this baseline.
- Approve product architecture, authorization matrix and data model before any
  schema, module, permission engine, private storage or financial implementation.

An eventual `apps/website` move and shared packages remain future options. This
phase deliberately introduces neither. See `CURRENT_BUILD_STATE.md` for the
current validated checkpoint and `SECURITY_MODEL.md` for implemented controls
versus future requirements.
