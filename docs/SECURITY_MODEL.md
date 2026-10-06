# Boss platform security

## Phase 6C profile, consent and share-link boundary

Ten new public tables and the private receipt table have RLS enabled and no raw API
role access. Public authenticated RPCs are invokers over closed fixed-path private
helpers. Mutations verify a live current identity, finite input, relationship and
permission before and after row locks, bind idempotency receipts to the caller and
enforce optimistic revisions. Immutable history triggers protect profile/showcase
revisions, measurements, achievements, verifications and media facts.

Unlisted recruiting links use a 256-bit random raw token generated on the server;
only its SHA-256 digest reaches PostgreSQL. Every read rechecks link status/expiry,
profile/showcase state, published revision and current consent. Responses are
no-store and noindex. Public output excludes DOB-derived age, addresses, guardian
identity/contact, household, attendance, medical, documents, private corrections
and internal controls. Revocation immediately closes subsequent reads and preserves
audit history.

## Phase 5D Football and history isolation

Football raw state/facts/lineups/seals/stats have closed RLS and no direct client
writes. Typed finite commands reuse current-session validation, event-before-game
serialization, current authority checks, caller-bound receipts and optimistic
versions. Each supplied player reference must match the current immutable
snapshot, actual side and independently authorized roster context. Wrong-sport
commands fail closed. Engine ownership survives feature disable.

The history read resolves authorized subjects first and projects only whitelisted
sealed player stats and minimal provenance. It does not depend on old-team or
source-module availability and never grants a future team implicit read/correction
rights. Guardian revocation/expiry and subject status are checked at request time.
No credential extraction or new test endpoint is part of hosted acceptance.
Controlled acceptance requires recovery rehearsed before activation, fixed
stop-new/cleanup/hard deadlines and explicit restoration before hard expiry.

## Phase 5C Soccer boundary

Five new raw tables are RLS-enabled and closed to API roles. Fixed-path private
helpers reuse current caller liveness, exact game/operator and side authority,
caller-bound receipt replay and post-lock checks. Wrong sport, tenant, side,
athlete/keeper, stale version, final status and disabled features fail closed.
Permanent engine ownership blocks legacy manual score/reversal and roster bypass
even after feature disable. Events/stat seals preserve immutable evidence.
Historical keeper corrections cannot use a later designation for an earlier
shot. Family/private masks and signed transport remain unchanged. Controlled
acceptance will use one fixed synthetic window with independently tested admin
recovery and exact zero-residual cleanup. No credential extraction, Auth-policy
change, production test endpoint or provider workaround is introduced. Runtime
and hosted validation remain distinct and are currently in progress.


## Phase 5B Basketball boundary

Basketball raw state, event, lineup, history and final-stat tables are immediately
RLS-enabled and closed to direct Data API writes/reads. Authorized canonical
Games RPCs retain current identity/session checks, same-origin transport,
caller-bound idempotency, event-before-game serialization and post-lock current
role/operator/module checks. Sport key, snapshot athlete, exact side, period,
version, final status and bounded feature state are independently validated.
Engine activation closes both manual score set and manual score reversal, even
if Basketball features are later disabled. Original plays/seals are immutable.
Family/public projections expose no private operator, Attendance, guardian,
request, correction-reason or audit data. Hosted evidence never requires cookie,
token or credential extraction or a test-only production endpoint.

## Phase 5A canonical security boundary

All six new public tables and private receipts have RLS enabled with raw client
privileges revoked. The two public authenticated entry points are invokers;
private dispatchers use fixed empty search paths, current confirmed live identity,
resource-qualified permissions, feature state and current relationships. Writes
lock event then game, recheck authority/liveness after waits, check optimistic
version and append audit/ledger history. Replays reauthorize. Final scores and
roster revisions remain immutable; corrections require elevated authority and
preserve prior history. Safe projections omit private profile/reason/contact,
operator and internal ledger data from families, and mask captured Attendance
fields when current source authority no longer permits them. Anonymous APIs stay
closed. Focused PostgreSQL security/concurrency and application checks pass; the full
historical run and canonical checks pass; hosted acceptance is interrupted.
The exact controlled baseline is restored with zero temporary authority and
pending run work; original administrator Home is verified. No restricted grant
was activated before the stop. See [the acceptance addendum](PHASE_5A_ACCEPTANCE_ADDENDUM.md).
New Game Center entry/post-wait checks use current-clock caller liveness, including
the natural session hard deadline; historical Auth helpers are unchanged.
Finite feature configuration uses existing org.manage and current active Sports,
with optimistic module revisions and current authority before receipt replay. No live Auth or security configuration changed.

## Phase 4B validated coordination security

Attendance and volunteer source work preserves deny-by-default RLS, closed raw tables, private helpers with empty search paths, verified canonical actors, finite same-origin POST handlers and transactional request receipts. Replays reauthorize current relationships and feature policy. RSVP notes and private snapshots do not enter audit/notification text.

Guardian attendance is an independent default-false flag administered through the existing bounded guardian dispatcher. No legacy guardian capability or household membership grants RSVP authority. Unknown/minor ages fail closed under the current adult self-action policy. No Auth, credential, provider or production environment setting changed.

Volunteer capacity cannot be exceeded or reduced below existing commitments. Unsafe capacity overrides, waitlists and quotas are absent. Current volunteer management also constrains the generic communications/attachment paths for selected-volunteer announcements. Reminder identities bind an active assignment episode to a stable UTC schedule context, rather than a capacity version changed by someone else's signup.

The complete disposable PostgreSQL suite passed, including 351 independent Phase 4B security assertions and ten new synchronized races. Read-only canonical checks verify 12 closed RLS tables including private receipts, four invoker RPCs and 72 private helpers with empty search paths and expected ACLs, all 38 new foreign keys indexed, and zero enabled guardian attendance flags with a non-null false default. Prior migration hashes remain unchanged.

Post-migration security advisors report 57 informational closed-RLS notices and one pre-existing Auth leaked-password-protection warning. Performance advisors report 117 unused-index informational notices and one pre-existing Auth connection informational notice. No new warning or Auth setting change was reported. Hosted security acceptance remains incomplete. Temporary-authority restoration and final residual-access verification passed, with zero temporary access and the original administrator restored. A Netlify proxy tool response exposed credential material; it was not used, written to files or committed, and validity/revocation remains unverified. See [Phase 4B validation](PHASE_4B_VALIDATION.md) for the incident and remaining acceptance gaps.

## Phase 4A communication boundary

Public invoker read/mutation wrappers delegate to private finite dispatchers. New
raw tables use RLS and no direct client table grants. Helpers accepting arbitrary
recipient identities remain private and nonexecutable to API roles. Same-origin
signed-session POSTs validate finite inputs and current scope, features, channel,
audience, guardian and age policy before canonical writes, receipts and safe audits
commit together. Retries reauthorize; knowing a UUID or destination link is not access.

Private PDF/PNG/JPEG attachments are limited to 5 MiB. Exact upload intents and short
audited same-object/same-actor/session download leases retain current channel checks
for managed Storage preflight and byte operations. Public links, signing, listing,
overwrite and cross-channel attachment binding remain denied. Message bodies,
document contents, credentials and provider internals are excluded from broad audits.

Participant messaging is disabled by default; missing age fails closed. Minor direct
messages remain denied. Explicit guardian visibility and group policy are required
for permitted minor group communication. Household membership or legacy registration
flags cannot substitute. Email remains unconfigured until an approved provider and
sender are supplied; SMS/push channels are future only. [Minor safety](MINOR_COMMUNICATION_SAFETY.md)
and [delivery boundary](EMAIL_DELIVERY_ARCHITECTURE.md).

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

## Phase 5E protected configuration and statistics

Eleven prepared public tables are deny-by-default under RLS with no raw
authenticated/anonymous/service-role CRUD grants. Private reducer, coverage,
resolution and command helpers expose no client EXECUTE grants. The existing
authenticated Game Center read/mutate boundaries are retained, with finite typed
inputs and tenant/game/side/roster-revision identity binding.

New profiles cannot grant access merely by naming a team or game. Disabled optional
statistics reject forged input; required rally/state controls stay available.
Corrections retain original evidence, validate the original tracking interval,
and replay all later dependencies. Finalized games reject direct changes.
Player coverage preserves gaps from missing attribution. Historical pre-profile
Basketball/Soccer/Football records are labeled legacy/unknown without fabricated
coverage or rewritten epochs. Practice is isolated synthetic state and cannot
pass official command parsing. No Auth/security policy was weakened.


## Phase 6A prepared statistical intelligence

Prepared Phase 6A tables enable RLS in their creation migration and revoke direct PUBLIC/anon/authenticated/service-role CRUD. Public statistical RPCs use finite scoped input and narrow private entry points. Self/current verified guardian may read private sport-career history; origin staff may read only explicit organization/team/season slices with existing games.view, team.roster.view for individuals, Calendar/Game Center eligibility and source-game visibility. Current-team relationship never authorizes prior-origin career history. Recheck identity, guardian and scoped role/membership after row waits. Pending projections disclose no stale totals. All changes remain local and unapplied pending release gates.


## Phase 6B implemented private comparative boundary (release pending)

Seventeen new public tables and private request receipts have RLS immediately and
no PUBLIC/anonymous/authenticated/service-role raw CRUD. Two finite authenticated
invoker RPCs reach only narrow private dispatchers; all other private helpers have
closed EXECUTE and empty search paths. Current Auth/person, catalog permission,
exact scope, memberships/windows, modules/features, source-game visibility and
athlete audience authorize each request and receipt replay. Physical authority
anchors protect revocation after lock waits, including stale repeatable-read work.

Safe team results can be shared through explicitly approved edition entries.
Foreign entries require originating-owner approval. Competition management provides
no foreign roster, private athlete, communication, history or correction authority.
Athlete cross-organization comparison and anonymous publication remain disabled.
Guardian/self history access supplies no peer leaderboard or comparative rank.
Current-team staff cannot inherit prior-origin career access. Signed writes enforce
same origin and finite bounded JSON; stale projections disclose no private rows.
