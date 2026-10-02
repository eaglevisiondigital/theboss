# Boss platform security

## Phase 3B registration and private files

Registration tables use RLS and explicit revokes for `anon`, `authenticated` and
`service_role`. Authenticated clients receive finite public invoker read/mutation
RPCs backed by caller-bound private functions, rather than raw table access.
The mutation guard requires the current confirmed non-anonymous managed Auth user,
a live owned session and active canonical account/person. The database independently
checks tenant, exact scope, role window, actual family relationship, module and
feature for each operation, including an idempotent retry.

The server accepts a finite command/field vocabulary, bounded bodies and typed
resource IDs. Same-origin checks precede sensitive actions. Supabase verifies
the signed identity; getClaims/getUser must agree. Safe application and SQL errors
omit SQL details, stacks and credentials. Authority is enforced through PostgreSQL
and Storage RLS even when UI controls or input IDs are forged.

Private upload intents bind actor, live Auth session, document, immutable random
object path, allowed MIME/size and a short expiration. Storage accepts only that
current unused intent during the exact server-established `object.upload` route;
upsert, direct update and delete are closed. Its rolled-back upload preflight uses
MIME plus `contentLength`, while backend object metadata uses MIME plus `size`.
Every supplied size must exactly match the intent, and malformed or conflicting
values are denied. Completion independently checks the actual private object's
persisted backend MIME/size before marking submission. An intent-bound SELECT
branch permits upload INSERT RETURNING only during that same upload operation.
The hosted path bounds actual streamed bytes to 5 MiB and checks PDF/JPEG/PNG
signatures. Its content digest binds retry content, rather than certifying malware
absence or independently verifying Storage bytes. The bucket/requirement ceiling
is 10 MiB. Files remain private, subject to explicit review and lifecycle metadata.

Every sensitive document/form/emergency access appends a safe audit record.
Two-minute Storage read leases are actor/session/purpose bound and recheck actual
role, feature and relationship on every authenticated download GET; the leased
SELECT policy accepts only exact `object.get_authenticated` and
`object.get_authenticated_info`, the documented managed file-access pair. Both
use the same already authorized object, actor/session and audited lease. Revocation takes
effect before lease expiration. Emergency paths require exact-team coach/staff and
participant relationships and expose restricted fields or explicitly eligible
approved unexpired medical documents. Signed upload/download URL minting, listing,
public info, HEAD, copying, moving and rendering routes are denied even with a valid
intent or lease. Empty or partial operation names are also denied. No public file
or reusable signed URL is returned by the application. These operation restrictions
prevent signed bearer delivery from bypassing later lease or authority revocation;
see [Supabase file-access policies](https://supabase.com/docs/guides/storage/security/access-control),
[Supabase operation helpers](https://supabase.com/docs/guides/storage/schema/helper-functions)
and the [Storage uploader](https://github.com/supabase/storage/blob/master/src/storage/uploader.ts).

Canonical medical/form answers, waiver text/signature evidence and document paths
are excluded from ordinary lists, generic mutation projections and audit payloads.
Private mutation receipts can hold the original family mutation command to bind
retries, but are RLS-protected with no client privileges. Sensitive retrievals
bypass receipts so they do not create a second medical response copy there.
Cash/check operations lock actual obligations, append allocations and reject
over-allocation. No service credential, payment processor, wallet execution,
production Auth setting change or broad medical role is introduced.
The live payment table and command both permit cash/check only. Planned electronic
or internal-value methods remain nonexecuting contract/documentation types, with
an approved future migration required to extend the table constraint.

File validation is limited; antivirus/content-disarm scanning, retention/object
purging, regulatory/legal consent assurance, recovery automation and incident
response remain separate operational work. See [Document security](DOCUMENT_SECURITY.md),
[Forms/waivers](FORMS_WAIVERS_ARCHITECTURE.md) and
[Fees/charges](FEES_CHARGES_ARCHITECTURE.md). Test, advisor, hosted and deployment
evidence belongs in CURRENT_BUILD_STATE.md.

## Phase 3A calendar boundary

The eight Calendar tables have RLS and authenticated SELECT-only privileges.
Direct client writes, anonymous table reads and anonymous `boss_private` access
remain closed. A public invoker RPC delegates anonymous publication reads to one
bounded fixed-field function in the separate non-exposed `boss_calendar_public`
schema. Signed-in general schedule visibility uses safe projections; it does not
expose full private event rows, facilities, target labels, instructions or family
and roster data.

Sensitive calendar read/preview/mutation paths require the current confirmed,
non-anonymous Auth user and live owned session plus an active canonical identity.
Mutation requires every actual current/proposed target active and authorized, in
its exact tenant scope, with module/feature and finite input checks. Request
receipts reauthorize on replay. No editable Auth metadata authorizes access.

Conflict checks use effective canceled/rescheduled occurrences across the complete
finite recurrence horizon, including dates beyond the visible 93-day window.
Transactional organization serialization prevents two concurrent schedulers from
committing an unreviewed occupied resource. Explicit override requires scoped
`events.override_conflict` and organization feature policy. Hidden conflicts reveal
only Busy/time metadata; real conflict references are audited within the protected
boundary. Failed mutations leave no partial event, receipt or audit writes.

Versions prevent stale series/occurrence updates. Whole-series status dominates
older exceptions; all-day exceptions retain local-midnight bounds. Timing/rule
changes with active exceptions require an explicit audited reset that archives
rows rather than discarding history. General error messages omit raw SQL details.
No privileged key, feed credential, new production environment variable or Auth
security change is introduced by Calendar. Attendance response, ICS subscriptions,
following and message delivery are deferred.
[Exact boundaries and limits](CALENDAR_ARCHITECTURE.md).

## Foundation security controls

At the Phase 2A checkpoint, the foundation was applied to the canonical Boss
project: 22 exposed application tables, all with RLS enabled and explicit access grants. That checkpoint
A-P suite passed 642 assertions; 269 additional role checks passed locally and live,
with transaction rollback and zero fixtures afterward. Hierarchy concurrency
checks pass at three isolation levels. See `CURRENT_BUILD_STATE.md`.

Anonymous users have no application table access or `boss_private` execution.
The Calendar publication projection is their sole event read surface.
Authenticated clients receive SELECT only; every read requires a canonical active
Boss identity plus the appropriate relationship or explicit scoped permission.
Catalog definitions require that identity but no tenant relationship.
An Auth login alone, membership label, module activation, entitlement, visibility
field or feature flag never grants broad access. No anonymous identity projection
or automatic publication policy exists. Phase 2B adds a protected names-only
projection and finite operational RPCs; current live/validation evidence belongs
in `CURRENT_BUILD_STATE.md`. Private team visibility is the default.

Private person DOB/contact information is restricted to self, currently verified
explicit guardian profile authority, or platform `person.profile.view`.
Household membership does not establish guardian authority. Scoped participant
metadata access does not reveal another person's private canonical profile.

The private `boss_private` schema contains invoker integrity functions and small
caller-bound definer lookups. Definers are needed to resolve canonical mapping,
relationship and permission records without recursive policies. Phase 2B adds
a finite private mutation dispatcher, not an arbitrary table/SQL or impersonation
endpoint. All use an empty search path,
fully qualified references, database-owned mapping/role records and restricted
EXECUTE. No user-editable metadata supplies authority. Private schema USAGE does
not itself add it to PostgREST exposed-schema configuration. Spoofing, missing
identity, anonymous claims and temporary-object shadowing are covered by the
passing test matrix. Live checks exercise database roles; they do not emulate
HTTP routing or JWT signature verification.

Role scope and actual resource context are validated, including same-tenant
composite FKs. Unit permissions are exact; there is no implicit descendant
inheritance. Lifecycle windows and status checks invalidate relationship/role
authority. Historical self-relationship reads do not activate membership-based
entitlements. Cross-tenant writes also fail structurally under trusted writers.

Authenticated mutation grants/policies are deliberately absent. The trusted
`service_role` writer receives explicit CRUD for foundation records but no
TRUNCATE; audit access is SELECT/INSERT only. No service key is retrieved or
added to the application. A platform person role does not become a database
BYPASSRLS role. Audit UPDATE/DELETE/TRUNCATE guards reject casual history rewrites;
superusers/database owners remain an operational trust boundary.

The migration owner's future table/sequence/function grants are hardened.
Managed `supabase_admin` future defaults are outside its ownership and remain
unchanged; every new application object explicitly sets ACLs. At the foundation
checkpoint existing managed Auth/Storage settings, functions and policies were
not modified. Phase 3B adds only the explicit private-bucket Storage INSERT/SELECT
policies described above; it does not change Auth settings.

Configuration JSON is for low-risk settings; audit JSON must be safe structured
context. Neither is a credential store or public profile store. Phase 2B audit
capture records safe changed field names and actor/resource/scope metadata only.
Field-level consent and later business mutation paths require separate approved
implementation. Transactional test fixtures are separate
from production catalog migrations; no real identity is provisioned or assigned
authority by a seed.

The approved initial role-permission matrix has 112 explicit potential-capability
pairs and validates the role's permitted scope kinds. At the foundation checkpoint, live advisors reported no new schema security
warning; separate existing Auth findings were unchanged. Current advisor results
are recorded in `CURRENT_BUILD_STATE.md`. Required
FK/scoped-query indexes are retained despite fresh-schema unused-index information.

## Phase 2B mutation boundary

Authenticated callers may execute the finite public invoker RPC wrappers, with no
anonymous/PUBLIC execution grant. The private definer dispatcher has an empty
search path, qualified object names, typed input allowlists, caller-bound identity
and exact permission/context checks. Private helper execution is restricted.
Direct table writes remain unavailable and no application service key is needed.

Global lifecycle read projections separately require the existing collection
read key and expose approved unit/team/audit metadata even when a referenced
resource is archived. They do not alter table SELECT policies, widen scoped
access or reveal audit payloads. Audit actor names additionally require platform
`person.profile.view`; otherwise the projection shows an opaque canonical actor
identifier. Neither Auth identifiers nor session values appear.

Sensitive administration validates the signed Auth session against the current
managed `auth.sessions` row and user confirmation/deletion/ban state. Revoking or
removing that session prevents a subsequent operational request even when an old
access token has not expired. No user-editable metadata participates in authority.

The server POST adapter checks same-origin requests, validates bounded commands,
uses the authenticated SSR client, and returns safe errors. The database RPC
applies the same authorization independently, including direct authenticated API
calls. Invalid UUIDs/references/windows, forged context, role escalation, duplicate
active periods and input fields fail closed. Household/guardian authority remains
explicit; no global household mutation is inferred from a tenant permission.

Batches are transactional, with append-only safe audit events and a private
RLS-protected receipt for request idempotency. Replays recheck current authority.
Relationship collision checks use physical resource anchors so stale higher
isolation snapshots fail with a safe conflict instead of committing duplicates.
No raw before/after profile payload, password, token or session value is captured.

The controlled bootstrap is a separate, documented one-time trusted procedure,
not a hard-coded account bypass or automatic seed grant. Its explicit link and
minimum approved platform role are audited. Acceptance data must be marked as
test data and contain no real minor data. Security/performance advisor and hosted
acceptance results are reported in `CURRENT_BUILD_STATE.md`; the existing Auth
leaked-password-protection warning is not weakened or silently changed.

## APPROVED BUT NOT IMPLEMENTED

Sensitive-field consent, retention/correction procedures and tenant-family
authority require approved direction. Organization household grants cannot infer
an unmodeled tenant-family relationship; household RLS remains unchanged. No
out-of-scope business module is included.

## Historical Phase 1B shell controls and limits

Technical foundation through Phase 1B hosted validation. This document is not a final authorization
matrix or a production-readiness certification. No business table, policy,
privileged credential was added. One owner-supplied controlled Auth identity was
used for hosted acceptance; no customer or business record was created.

## Implemented

- Public configuration accepts the canonical Boss HTTPS Supabase endpoint and
  a modern publishable-key format, rejecting missing, placeholder, legacy JWT
  and privileged-key input. Diagnostics identify configuration names without
  printing supplied values. Format checks cannot prove a key's project pairing.
- Server-only environment, session and server/route client modules use the
  `server-only` boundary. Browser code reads only the explicit public URL/key.
  No server secret is required or implemented in this phase.
- Supabase `getClaims()` verifies the session; additional checks validate subject,
  canonical issuer, role, expiry and non-anonymous identity. Only a subject is
  returned. User metadata grants no access. Proxy plus protected layouts/pages
  each enforce authentication, failing closed to the login route.
- SSR adapters propagate refreshed cookies through redirects and forbid shared
  caching using private/no-store and CDN-specific response headers. Cookies use
  SameSite Lax and Secure on HTTPS. Browser-readable cookies follow Supabase's
  browser/SSR design; they are not presented as HttpOnly cookies.
- Password login and local-browser logout use POST only, require an explicit
  matching server-approved Origin and non-forwarded Host, check fetch-site metadata
  when provided, and return generic
  errors. Login input is bounded and duplicate credentials rejected. Redirect
  targets stay within local `/app` paths. No signup, OAuth, recovery or callback
  workflow is enabled by this shell.
- Production requires server-only, non-secret `BOSS_PLATFORM_ORIGIN`. It fixes
  the observed hosted POST rejection while controlling redirect destinations and
  Secure cookies. Arbitrary forwarding headers do not determine these decisions.
  A shared header policy is applied directly to early proxy responses because
  hosted redirects otherwise bypassed the framework's configured headers.
- All surfaces are noindex. Security headers enforce frame denial, CSP
  frame-ancestors/base/form/object restrictions, MIME sniffing prevention,
  referrer policy, limited browser capabilities and HTTPS HSTS. A stricter
  script CSP is report-only because Next hydration uses inline scripts; an
  enforced nonce/hash design requires later hosted validation. No report
  collector or telemetry backend is invented here.
- `/health` reports local configuration readiness only. It returns no keys,
  settings or user details and makes no upstream service request. UI errors
  disclose no provider messages, stack traces or configuration values.

## Known limits and required operational checks

Supabase claim verification does not guarantee immediate server-side session
revocation detection. Sensitive future operations require current session/user
checks, relationship and entitlement checks and reviewed database policies.
Logout affects the current browser only; cross-device policy is not settled.
No business action is authorized merely by reaching this shell.

Required public configuration is provisioned for the dedicated platform's
production context, builds are active and previews remain disabled. The canonical
publishable key successfully retrieves public Auth settings; no privileged key
was fetched. Hosted public routes and unauthenticated guards were tested. Initial
POST-origin and redirect-header defects are fixed and all 25 hosted HTTP retests
passed. Invalid-session cookie cleanup was observed with Secure/SameSite Lax and
no Domain, and anonymous auth responses had private/CDN no-store instructions.
The subsequent controlled-account test passed valid login, authenticated SSR
Home/Account, navigation/reload/fresh server requests, natural-expiry server
refresh with rotation and persistent renewed-session state, authenticated POST
logout and post-logout guards. Anonymous-after-auth requests did not receive
protected content. Password entry stayed with the human, and no token/session
value was captured. Private Auth settings were reviewed without changes.

Direct valid-session cookie attributes and authenticated response cache/CDN
headers remain unverified because the browser tools expose no inspection API.
Functional session persistence and prior invalid-session cookie/cache observations
are not a substitute. No debug endpoint or security-policy weakening was used.
No staging backend or custom platform domain was created. Server credentials must
never be put in `NEXT_PUBLIC_` variables or untrusted preview contexts. Auth email
redirect/SMTP/account-security defaults and public build-log policy still need
operational review before launch. The current account-security advisor finding
was left unchanged pending that review.

This shell does not add custom abuse/rate-limiting infrastructure or account
enumeration telemetry. Review upstream Auth rate limits and operational abuse
controls before enabling authentication. It does not certify recovery, backup,
incident response, access logging or production availability.

## Historical Phase 1B future requirements

Approved data-model work must establish RLS and explicit least-privilege grants,
deny-by-default organization/team/household/merchant isolation, minor privacy,
private Storage policies, scoped roles, verified relationships and entitlements.
Authentication and hidden UI controls cannot replace those protections. Review
default grants before creating any exposed table or privileged function.
The Phase 1B read-only audit found broad default public privileges but no business
relations. Those defaults do not establish deny-by-default security for future tables.

Audit logs, webhook signature verification, financial idempotency, ledger
integrity, reversal behavior and transactional unique Money Board claims require
their approved module assignments and meaningful concurrency/authorization tests.
No policy SQL, canonical schema or business behavior is implemented here.

Implementation references: [Supabase SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client),
[Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys),
[Next.js CSP](https://nextjs.org/docs/app/guides/content-security-policy).
