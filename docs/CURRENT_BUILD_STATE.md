# Current build state

Current Phase 1B checkpoint, September 30, 2026: the shell is hosted on the
dedicated platform site. Public configuration is installed and builds active.
Hosted POST-origin and early-redirect-header defects are repaired in code;
repaired deployment retest and controlled-account tests remain pending. See
[Phase 1B hosted validation](PHASE_1B_HOSTED_VALIDATION.md) for current status.
The Phase 1A evidence below is a historical baseline, including its deployment
hold. No business model or production data schema is approved by this document.

## Verified infrastructure

- Repository: `eaglevisiondigital/theboss`. Live starting `main` and branch
  parent: `47eb2f94a86737bae0a0dc5ecb0a083dac9a0aa4`.
- Dedicated branch: `build/boss-platform-v1`, created from that exact main
  commit. The Phase 1A draft PR targets `main`; it must remain unmerged pending
  review. The PR head is the authoritative implementation commit.
- Website branch heads checked before work:
  `build/premium-site-v1` at `fbe850ab90eb56f6b190e639444467d5c8eca4c1` and
  `build/approved-homepage` at `e4912fba334006f1dcb4cab9011bc18e5a2845a0`.
  Existing PRs #1 and #2 were open drafts. Their histories and files were not
  changed; root README is identical to the parent.
- Dedicated Supabase project: `the-boss-platform`, ref
  `ilykgwgmxtrrikreacrz`, `us-east-1`, read-only status `ACTIVE_HEALTHY`.
  No backend writes, key retrieval, user creation or migration occurred.
- Only `thebossplatform` Netlify settings changed. Builds stopped, production
  branch set to the platform branch, base `apps/platform`, build `npm run build`,
  output `.next`, previews disabled. Both public website site settings compare
  unchanged. Existing platform root publication remains; the shell is not hosted.
  Details: [Netlify configuration](PHASE_1A_NETLIFY.md).
  Draft PR #3 also caused an automatic repository-root preview on `bossplus`
  under its existing policy. That is not a platform preview. All three published
  deployment pointers were rechecked after the PR and remain unchanged.

## Implemented

- Independent strict TypeScript Next.js App Router application, exact dependency
  pins, nested lockfile, ESLint configuration, Node version and Netlify config.
  No root package/workspace/build configuration or website migration.
- Text branding, responsive landing/login, authenticated Home/Account placeholders,
  browser/server Supabase helpers, SSR cookie refresh, independently guarded
  pages/layout, same-origin POST login/logout and readiness route.
- Public/server environment validation with startup/build preflight; safe local
  return paths, generic errors, private auth caching, noindex, security headers
  and a partial enforced CSP plus stricter report-only script policy.
- Platform-only GitHub validation workflow with SHA-pinned official actions and
  synthetic public test configuration. It deploys nothing and uses no secrets.
- Implementation documentation and provenance record. Private source handoffs,
  raw brief and private audit evidence stay outside this public repository.

## Validation performed locally

- Clean `npm ci --ignore-scripts`: passed; dependency audit: zero advisories.
- `npm run typecheck`, `npm run lint`, `npm test`: passed, 16 tests, zero lint
  warnings. Tests cover configuration, environment-file selection, safe redirects,
  verified identity, same-origin request/input checks, health and cookie caching.
- Production build passed with a deliberately nonworking synthetic publishable
  key. Missing required public configuration fails clearly. This validates the
  build and guard plumbing, not a real key/project pairing or authenticated session.
- Local production HTTP checks: public landing/login/health 200; unauthenticated
  `/app` and `/app/account` 307 to safe login return paths with private/no-store;
  missing/external POST origins 403; malformed same-origin login 303 with generic
  error and safe return path; GET logout 405. No credentials were submitted.
- Browser review: desktop landing/login and 320px landing/390px login readable
  without horizontal overflow; protected account redirects to login. Approved
  logo/font assets were absent from the baseline, so branding uses text/system fonts.
- Git whitespace checks passed. Website branches remain outside this branch's
  ancestry and no website build input was changed. Final remote ref/PR checks,
  CI results and exact commit are recorded in the completion report.
- GitHub Actions push and PR validation passed for implementation commit
  `1db9619672608a562a7ec1d7fcde923cc60bebf7`. Final documentation updates do not
  change application code. The workflow also validates the platform technical
  documentation paths so subsequent documentation commits receive checks.

## Planned and pending main Chat approval

Supply authorized public configuration, review Auth providers/signup/SMTP and
origins, select a platform release/preview flow and isolated preview backend,
then authorize build reactivation and a hosted test. Confirm the Netlify adapter,
request origin/protocol, Secure cookies, refresh/logout and response caching.
Next's local production server normalizes its request URL to `localhost`; use
the `localhost` browser origin for local POST tests. A `127.0.0.1` Origin is
rejected by the strict origin check in that runtime. Arbitrary forwarding
headers are not trusted to bypass it. Hosted origin behavior is unverified.

Product architecture, schema, permission/relationship/entitlement rules, private
Storage, minor privacy and financial/concurrency behavior require later approved
assignments. None is implemented. Authentication alone grants no business
authority, and verified JWT claims do not guarantee immediate revocation detection.
See [security controls and limits](SECURITY_MODEL.md) and
[package commands and configuration](../apps/platform/README.md).
