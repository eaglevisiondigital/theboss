# Current build state

## Phase 2B operational core

### IMPLEMENTED

Phase 2B adds explicit canonical provisioning/linking, protected transactional
mutations and safe admin read projections. Home, Organizations, People, Families,
Teams, Access, Audit and Account expose tools from current permissions and actual
resource context. Organization selection does not change authority. All 22 public
table policies and SELECT-only authenticated table grants remain unchanged;
the 19-role/17-permission/112-mapping catalog remains the approved Phase 2A model.

Three new migrations add authenticated-only invoker RPCs backed by private,
caller-bound authorization and a private receipt table. Mutations validate a live
confirmed non-anonymous Auth session plus active canonical identity, exact scope,
actual references and allowed fields. Atomic batches, type-checked earlier-resource
references, retry fingerprints, overlap guards and safe audit capture are included.
No privileged key, production secret or new environment variable is introduced.

Organizations/modules/units/seasons/teams, names-only people, households,
participants, explicit guardians, historical memberships and role assignments
have authorized administration. Verified guardian profile management permits only
dependent name edits. Household membership implies no guardian authority.
Delegation checks every target-role permission at the actual target scope.
Existing team season/parent and relationship identity keys remain immutable.
All later module products remain unavailable even when configuration is active.
See [operational procedures and limits](OPERATIONAL_CORE.md).

### VALIDATION AND PUBLICATION

The final complete local run passed 1,776 SQL assertions and five coordinated
concurrency cases. Application typecheck, zero-warning lint, all 28 tests and the
production build pass with locked dependencies and synthetic public configuration.
The final application run used an identical isolated temporary source copy because
local synced dependency directories contained duplicate generated type folders;
clean CI installations also passed both jobs.
The canonical project has all three migrations, a successful transactional
live verifier with zero fixture remnants, and an explicitly authorized controlled
canonical account with one approved platform-administrator grant and three audit
events. Public database types were regenerated live. The equivalent scoped-people
query optimization passed 2,000-row isolation and search regressions.
Hosted acceptance passed on the deployed implementation commit
`d364d6ee602e7ba7855548d95c9b9601477cf0e1`. Both push and PR validation runs
passed their application and database jobs. Starting branch
SHA: `20acee683f67b854ecefd6c7c91a87a3b8a6a3f8`. The branch remains
`build/boss-platform-v1`; [PR #3](https://github.com/eaglevisiondigital/theboss/pull/3)
must remain OPEN/DRAFT/UNMERGED. Public website releases are separate and preserved.

| Applied Phase 2B version | Migration |
| --- | --- |
| `20261001134826` | Protected operational mutations and private receipts |
| `20261001134845` | Safe permission-aware admin read projections |
| `20261001140101` | Authorized candidate-first scoped people discovery |

The existing six Phase 2A migrations remain unchanged. Hosted DML-only checks
completed without errors and all seven synthetic cleanup counts were zero.
SQL role tests model database authorization; hosted acceptance verifies actual
signed browser sessions separately. Security advisors retain the existing Auth
leaked-password warning and an intentional private receipt RLS-without-policy
information item. Performance advisors report 19 unused-index information items
and the existing absolute Auth connection allocation information; no warning,
missing FK index or schema security warning was introduced. No Auth setting changed.

### HOSTED ACCEPTANCE

The controlled administrator's existing valid signed session opened every
authorized admin route and retained the canonical identity across navigation,
account access and a full page reload. Hosted forms created a clearly labeled
test organization, activated Sports configuration, created a sport unit, season
and team, and created synthetic people without Auth accounts. Household setup,
an atomic person/participant/household/explicit-guardian batch, guardian
verification, organization memberships, athlete team membership and atomic coach
membership plus exact-team role all passed. The read-only audit showed matching
actor/action/resource/time/context fields without before/after payloads.

A duplicate organization slug returned only the safe UI error and created no
extra organization. Switching between two clearly labeled test organizations
cleared the prior team context. A nonexistent organization deep link exposed
no records or mutation controls. Cross-tenant, exact-scope, guardian isolation,
role escalation and direct-write failures passed the transactional local/live
database-role suites; the one hosted account is globally authorized, so it was
not presented as a restricted-tenant HTTP negative test.

Desktop at 1280 pixels and mobile at 390/320 pixels had no horizontal page overflow.
At 320 pixels all visible form controls fit the page, and keyboard Tab moved into
the next labeled family field. A team-membership metadata change saved on mobile.
Browser console inspection found zero entries. No password, access/refresh token,
cookie/session value, production secret or private request attachment was captured,
stored, printed or committed during this assignment. Managed service log histories
were not exhaustively inspected. No production environment variable changed.

The retained acceptance data is explicitly marked CONTROLLED TEST: two
organizations, three synthetic people, one unit/season/team/household/participant,
two household memberships, one verified guardian, two organization memberships,
two team memberships, one exact-team coach role and one Sports configuration.
Synthetic people have no Auth mapping. Together with the controlled bootstrap,
the database contains 24 append-only audits and 17 completed mutation receipts.
No real youth data was used. Transactional verifier fixtures remain absent.

### PLANNED / FUTURE

Entitlement administration is deferred because it is unnecessary for this slice
and no approved entitlement-management permission exists. Tenant-family authority
anchors, invitations/email onboarding, reviewed identity corrections, consent,
publication and all business modules require separate direction. Phase 2B ends
after its operational core is validated and published; no next module is started.

## Historical Phase 2A core schema and RLS foundation

### IMPLEMENTED AND VERIFIED LIVE

Six canonical migrations are applied to the verified Boss Supabase project
`the-boss-platform`, ref `ilykgwgmxtrrikreacrz`, region `us-east-1`.
Repository migration filenames match the observed hosted history; reconciliation
preserved the reviewed SQL bytes and migration order.

| Migration version | Foundation |
| --- | --- |
| `20260930212353` | Grant hardening |
| `20260930212410` | Identity and organizations |
| `20260930212417` | Relationships, access and governance |
| `20260930212421` | Integrity triggers |
| `20260930212426` | Authorization helpers and RLS |
| `20260930212430` | Approved catalog seeds |

The 22 approved tables have 167 constraints (22 primary keys, 45 foreign keys,
79 checks and 21 unique constraints), 35 explicit indexes (78 total including
constraint indexes), 26 integrity triggers, and 22 authenticated SELECT policies.
Every public table has RLS. Anonymous access and all client mutation grants/policies
are absent. Seventeen private functions include ten narrowly caller-bound definers;
only twelve reviewed policy helpers are executable by authenticated clients.

Catalog seeds contain 19 roles, 17 foundation permissions, 112 approved mappings
and 13 module definitions. All 18 non-catalog tables are empty. No real Boss
identity/account mapping, tenant, household, team, role assignment, module
activation or customer record is seeded. Existing managed Auth identities,
Storage and Edge Functions are preserved; no Auth policy or environment changed.

### VERIFIED DATABASE ACCEPTANCE

The complete A–P suite passed 642 assertions in three fresh PostgreSQL 17.11
runs. The last two also passed 269 DML-only verification assertions and coordinated
hierarchy concurrency checks: READ COMMITTED rejected a cycle with `23514`;
REPEATABLE READ/SERIALIZABLE rejected stale writes with `40001`. Every run rolled
back fixtures and removed its private Unix-socket cluster.

The 269-assertion verification then passed on canonical hosted PostgreSQL 17,
using actual `anon` and `authenticated` database roles with synthetic request
claims. All synthetic records rolled back and cleanup counts were zero.
These SQL checks model Data API database-role enforcement; they do not certify
HTTP JWT signature verification or production load performance.

Live advisors found no new schema security warning, missing RLS or unindexed FK.
The separate existing Auth security warning and connection-allocation information
remain unchanged. Fresh-schema unused-index information is retained for workload
review: those indexes support integrity and scoped retrieval, and an empty
operational schema cannot establish production index usefulness.

### APPLICATION AND PUBLICATION

Public-schema TypeScript types are generated from the validated live project at
`apps/platform/src/lib/supabase/database.types.ts`. All four existing browser/SSR
adapters use that Database generic; no new query, UI, mutation API or privileged
credential is introduced. Local typecheck, zero-warning lint, all 22 application tests and the production
build pass with locked dependencies and synthetic public build configuration.
Final branch/CI metadata is recorded in the assignment completion report and
[PR #3](https://github.com/eaglevisiondigital/theboss/pull/3).
The validation workflow includes the isolated PostgreSQL 17 SQL/concurrency job.

The branch remains `build/boss-platform-v1`, starting this assignment at
`d560e46e307a9c6aa18e9c402eacff312c4eeea6`. PR #3 must stay OPEN/DRAFT/UNMERGED.
Public website code, configurations and production deployment pointers are
preserved. The private source brief remains outside the public repository.

### APPROVED BUT NOT IMPLEMENTED

Canonical identity provisioning, authorized audited mutation workflows,
delegation, consent and publication projections require a subsequent assignment.
Organization household permissions remain potential capabilities without an
approved tenant-family resource anchor. Unit-scoped authority does not invent an
organization membership unit relationship. No descendant-unit inheritance exists.

### FUTURE

Fundraising, Boss Bucks, payments, Money Board, commerce, registration, messaging,
Storage/document workflows and all other business modules remain outside Phase 2A.
Phase 2A ends with this foundation; Phase 2B is not started.

## Historical Phase 1B checkpoint

The dedicated platform is published at
[thebossplatform.netlify.app](https://thebossplatform.netlify.app).

## IMPLEMENTED

Public Supabase configuration and server-only approved platform origin are scoped
to the dedicated site's production context. Platform builds are active; previews
remain disabled. Hosted POST-origin and early-redirect-header defects are fixed,
with six regression tests. No business schema or authorization model is created.

## VERIFIED HOSTED

The repair deployment passed all 25 HTTP checks for public routes, unauthenticated
guards, invalid/malformed login, origins, redirects, headers and private caching.
Invalid-session cookie cleanup used Secure/SameSite Lax/root path and no Domain.
Hosted desktop/mobile screens and browser protected-route navigation were checked.
All 22 local tests, typecheck, lint, production build and repair-commit CI passed.
Both public website production deployments/configurations remain unchanged.

Controlled-account acceptance subsequently passed valid login, authenticated
Home/Account, navigation, full reload and a fresh browser-tab server request.
Natural-expiry server refresh and renewed-session persistence passed using
protected requests plus read-only refresh timestamps/rotation counts. Authenticated
POST logout passed, followed by login redirects from both protected routes.
Password entry remained with the human; no credential/token/session values were
retrieved or included in artifacts. Private Auth settings were reviewed read-only.

## UNVERIFIED

Direct valid-session cookie attribute and authenticated response cache/CDN-header
inspection remains unavailable through the current browser API. Metadata-only
human inspection was requested. Cookie-backed persistence/refresh/logout and
anonymous-after-auth isolation are verified; those do not replace direct header
observations. No Auth setting changed. Email redirect/SMTP/account-security
configuration needs its later operational review before production email flows.

## PENDING ARCHITECTURE

Identity, organizations, households, participants, permissions, entitlements,
private storage and all business modules require the main Boss Chat's approved
architecture. No business authority follows from authentication alone.

See [Phase 1B hosted validation](PHASE_1B_HOSTED_VALIDATION.md) for detailed
verified results and remaining manual steps. Final commit/deployment/CI metadata
is in the completion report.

## Historical Phase 1A baseline

The material below records Phase 1A, including its former deployment hold and
then-current website SHAs. Phase 1B status above supersedes those operational
statements; the truncated source brief remains unchanged.

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
