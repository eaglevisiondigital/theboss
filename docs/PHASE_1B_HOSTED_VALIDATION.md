# Phase 1B hosted platform validation

Checkpoint September 30, 2026. Infrastructure/Auth validation only. No business
schema, permanent identity/role model, customer data or authorization system.

## IMPLEMENTED

- Approved public Supabase URL and active modern publishable key installed only
  on `thebossplatform`, production context, build/function/runtime scopes. No
  real key is stored in this repository and no privileged key was retrieved.
- Only platform builds reactivated, production branch `build/boss-platform-v1`,
  base/config `apps/platform` / `apps/platform/netlify.toml`.
- Non-secret server-only `BOSS_PLATFORM_ORIGIN` configured to the existing
  `https://thebossplatform.netlify.app` origin. Production validation requires
  an exact origin; hosted HTTP, paths, credentials, wildcards and query/fragment
  values are rejected. Loopback HTTP is accepted only for local usage.
- Verified hosted defects fixed: the old request-URL comparison
  rejected legitimate hosted POSTs, and early proxy redirects omitted framework security headers.
  POSTs now bind explicit Origin and non-forwarded Host to approved configuration;
  redirects and cookie security use the same origin. Forwarded headers are not
  trusted. Shared headers also cover early redirects and auth error responses.
- Six new regression tests cover origin/Host/forwarding behavior, Secure cookie
  selection, production readiness projection and early redirect/header/cookie
  preservation. Typecheck, zero-warning lint, all 22 tests and build pass locally.

## VERIFIED HOSTED: initial deployment

Initial production deploy `6abd0180faf1b743b10d892e`, commit
`f8bac9e6afc61c723f00cda355d684ad34142720`, served the platform at
[thebossplatform.netlify.app](https://thebossplatform.netlify.app). Logs confirmed
the nested package/config, Node 24.20.0, npm 11.19.0, Next 16.3.7 and Netlify
Next runtime 5.16.0. The adapter generated its server/edge handlers; no authored
Supabase Edge Function was created.

Public landing/login/readiness returned 200 and unknown route 404. Protected
Home/Account returned private/no-store 307 login redirects with safe return paths.
External/missing-origin POSTs returned 403 and GET logout 405. Legitimate POSTs
also returned 403, and protected redirects lacked most security headers; these
failures led to the documented repairs. The deployed repairs passed the retest below.

## VERIFIED HOSTED: repaired deployment

Repair commit `a9f99c1f980508a3871e4f7e4510058777bfd613` was published by automatic
Git deployment `6abd071e00051b00089a6a1f`. All 25 hosted HTTP cases passed:

- Landing, login and readiness 200; unknown route 404. Unauthenticated Home and
  Account 307 to login with their local return paths.
- Same-origin malformed/empty/duplicate login fields, hostile return paths and
  unsupported content types 303 to a generic error at the configured HTTPS origin.
  A password attempt for a nonexistent `.invalid` address also returned the
  generic error; this did not create an identity or test a valid account.
- External/missing Origin POSTs 403; GET logout 405; no-session POST logout 303
  to login. Hostile forwarded host/protocol did not change approved destinations.
- All expected security headers were present, including early protected 307s and
  403 errors: frame denial, both CSP policies, HSTS, nosniff, referrer/capability
  restrictions and noindex. The stricter script CSP remains report-only.
- Login, health, protected redirects and auth POST responses had private/no-store
  and CDN no-store instructions. Repeated login responses were bypassed/misses;
  no observed auth response was marked stored. The anonymous landing was public,
  revalidated/cacheable and set no session cookies. Netlify consumes its
  CDN-specific header; browser-visible standard headers and Cache-Status were
  inspected. Authenticated cache isolation is still unverified.
- Synthetic invalid-session GET Account and POST logout both emitted cookie
  deletion (`Max-Age=0`, `Path=/`, `Secure`, `SameSite=Lax`, no Domain) despite
  hostile forwarding headers. This verifies cleanup attributes, not valid-session
  issuance, refresh or authenticated logout.
- Browser review confirmed hosted desktop landing/login and Account-to-login
  navigation. The 390px login and 320px landing layouts had no horizontal overflow.

Both push and PR GitHub validation runs passed for the repair commit. Final
metadata and documentation-only commit are recorded in the private completion
report. No application-code change followed these hosted tests.

Read-only public Auth settings returned 200 using the canonical publishable key:
email/password enabled, public signup enabled, confirmation required, anonymous,
OAuth, SAML and passkeys disabled. No policy change was made. These settings do
not imply that this application implements signup, recovery or callbacks.

Both public website configurations compare unchanged. Premium branch remains
`fbe850ab90eb56f6b190e639444467d5c8eca4c1`; approved-homepage independently advanced
before Phase 1B to `34b6abea368ffc3f5930b667e9a0e7edc581613f`, which is this phase's
preservation baseline. The pre-existing `bossplus` PR-to-main policy still creates
root website previews for platform PR updates. Recommend a separately reviewed
path-filter/release policy; this phase does not change website settings.

## UNVERIFIED: controlled-account and dashboard checks

The connector exposes no Auth-user creation or Auth configuration tool and the
dashboard is signed out. No test user is available. Dashboard sign-in and human
entry of a new test-account password were requested. No email address or
credential was invented, no signup/confirmation setting weakened and no Auth
user or business record created.

Valid login, authenticated SSR/navigation/reload, session-cookie issuance,
refresh-token exchange/cookie propagation and authenticated logout require that
controlled account. Site URL, redirect/callback allowlist, recovery, MFA, SMTP
and private JWT/session policy remain unverified pending dashboard access.

Do not call this end-to-end authentication proven until those tests pass.
Use natural expiry or isolated test-session expiry metadata to induce refresh;
do not change global JWT/session policy, expose tokens or add a debug endpoint.

## Backend safety

Read-only baseline and post-test audit: healthy canonical Boss project in us-east-1, no business
relations/functions/policies, migrations, buckets/objects or Edge Functions; Auth
users zero; security advisors clear. Auth connection allocation has one
informational performance advisory. [Supabase production guidance](https://supabase.com/docs/guides/deployment/going-into-prod).
Default public grants are broad; explicit grants/RLS must precede future business
schema work. No grants were changed. PostgreSQL 17.6 is live; operational review
of the [17.11 rollout](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes)
is separate from this assignment. No database upgrade was initiated.

Private, sanitized HTTP/settings/deployment evidence stays outside this public
repository. The completion report records final commits, CI, retests and limits.

## PENDING ARCHITECTURE

Product architecture, tenant/household/minor isolation, permissions, entitlements,
private storage, financial integrity and module schemas remain unimplemented.
