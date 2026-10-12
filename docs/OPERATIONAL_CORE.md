# Operational core

## IMPLEMENTED

Phase 2B adds a protected operational admin slice to the 22-table foundation.
The existing 19 roles, 17 permission keys, 112 mappings, exact scopes and table
SELECT policies remain unchanged. Deployment and acceptance status is recorded
in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

### Canonical identity

A verified, non-anonymous Auth account may explicitly create its own canonical
person and account mapping with `identity.provision_self`. This grants no role.
An existing Auth mapping is reused; suspended/inactive mappings fail closed.
An existing matching canonical email requires operator review, never an automatic
merge. Names, shared email, address and household membership do not prove identity.

An authorized platform operator may create a person without Auth or link an
explicit reviewed person UUID to a verified Auth UUID with `account.link`.
Mappings cannot be rebound. Database unique constraints serialize strong Auth
identity collisions and prevent multiple active accounts for one person.
The operational UI accepts names and foundation status only, excluding DOB,
contact details and editable Auth metadata from authority and public projections.

### One-time platform bootstrap

[bootstrap-platform-admin.sql](../supabase/operations/bootstrap-platform-admin.sql)
is a trusted-operator procedure, outside the application RPC surface. Its use
requires explicit approval for the target identity and platform role. Supply the
approved email through the psql variable `bootstrap_email`; optionally supply a
reviewed `bootstrap_person_id`. Never supply a password, token or session value.

The transaction requires exactly one confirmed, non-anonymous, non-banned Auth
identity, creates/reuses an active canonical mapping, and grants the existing
`platform_administrator` role. Existing identity ambiguity requires explicit
review. It records identity/link/role audit events and safely repeats without
duplicate active mappings or grants. It contains no named-user exception,
startup trigger or client bypass. Removing or changing this privileged grant is
a separately authorized operational action, never ordinary user provisioning.

### Trusted mutation path

`POST /app/admin/mutate` accepts `{request_id, commands}`. The application checks
same-origin POST, Host, bounded JSON, finite fields, verified claims and the current
Auth user. It sends the caller's existing session to `boss_admin_mutate` using the
publishable client. No service key or new environment variable is used.

The public RPC is SECURITY INVOKER and authenticated-only. Its private definer
implementation resolves the caller from database-owned accounts and validates the
signed session identifier against the caller's current Auth session. Confirmation,
account/person status, anonymous status, bans, deletion and session lifetime fail
closed. All functions use an empty search path and qualified references.
No authenticated table INSERT/UPDATE/DELETE/TRUNCATE rights are granted.

Each batch contains 1–12 finite operations. UUID fields may reference earlier
created resources with `{"$ref":"name"}`; the server validates the expected
resource type. Arbitrary table/field names, actor input, permissions, configuration
JSON, SQL and audit payloads are rejected. Resource context is resolved from the
actual database row. Forged tenant/team IDs do not supply authority.

The entire batch and all audits/receipts commit together. Person + participant +
household membership, organization + explicit initial membership + role, and
team membership + explicitly requested role are atomic. Failures roll back every
record. Caller/request UUID receipts in a private RLS table fingerprint the input;
same-input retries recheck current authorization before returning their result,
and different-input reuse conflicts. Clients reuse the request UUID after an
uncertain response. Overlapping active relationship windows are rejected under
shared locks. Stable anchor writes protect against stale repeatable-read snapshots.

Errors returned to the UI are fixed authentication/permission/conflict/validation
or availability messages. SQL, stack traces, RLS details and session values are
not returned or logged. Auth and admin responses retain private/no-store caching.

### Administrative scope

Organizations, module activation, units, seasons, teams, people, households,
participants, explicit guardians, dated memberships and scoped role assignments
have finite create/update/status operations. Normal deletion is absent.
Membership labels and module/visibility states grant no authority. Household
writes require the existing platform household capability; organization-scoped
household keys do not invent a missing tenant-family authority anchor.

Verified guardian `can_manage_profile` permits only dependent name edits, not
status, household management, role administration or the later capability actions.
Guardian verification cannot be self-approved. Stored registration, waiver,
document and payment flags describe future capabilities only.

Delegation requires `roles.assign` plus every permission on the requested role at
the actual target scope. Organization grants cannot create platform authority.
Exact unit/team scope has no implicit descendant inheritance. Role/person/scope,
membership type/start/person, and existing team season/parent attachments retain
their immutable historical keys; choose attachments at creation and end/create a
new relationship when its historical identity changes.

### Safe reads, context and audit

`boss_admin_read` supplies bounded safe UI projections. Base collections execute
as the caller under unchanged RLS. Private caller-bound context/name helpers expose
only authorized organization headers and name fields from explicit organization
membership or team roster context. Ordinary users cannot run global people search.
An additional caller-bound platform projection requires the existing global read
key to expose archived unit/team recovery and safe audit history, including inactive
contexts. Scoped callers retain their existing active-resource/table-read limits.
Individual row operations describe exact available scope; context selection is UX
state and all deep links/mutations independently reauthorize.

The admin shell provides Home, Organizations, People, Families, Teams, Access,
Audit and Account according to current read permissions/relationships. Module
configuration shows active/inactive separately from future/unimplemented product
functionality. No future product navigation is enabled by a catalog activation.

Every significant mutation appends an audit event bound to the actual actor,
resource, scope and request. Payloads contain changed field names/procedure
provenance, never submitted names, emails, contact details or credentials.
The read-only audit UI shows safe actor/action/resource/time/context fields under
`audit.view`; it does not serialize blanket before/after payloads or Auth IDs.
Existing UPDATE/DELETE/TRUNCATE guards remain in force.

## PLANNED

Production onboarding/invitations, reviewed identity corrections and a tenant-family
authority anchor need separate direction. Operational acceptance uses clearly named
controlled test records and no real minor data. See `supabase/tests/README.md` for
disposable database reproduction and the A–R mutation/read safety matrix.

## FUTURE

Entitlement administration is deferred because this slice does not require it and
no approved entitlement-management permission exists. All fundraising, Boss Bucks,
Money Board, payments/ledgers, registration, documents, messaging, notifications,
scoring/statistics, commerce, merchant and livestreaming behavior remains unbuilt.
