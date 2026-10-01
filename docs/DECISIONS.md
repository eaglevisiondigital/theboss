# Boss foundation implementation decisions

## Phase 3A implementation choices

The approved Events/Calendar assignment adds one reusable canonical event model,
exact tenant associations and Calendar activation independent from Sports. Finite
local-time recurrence avoids future event copies and normalizes interval/weekly
anchor defaults. The subset is bounded to five years and is not a general RFC 5545
parser. DST gaps and invalid monthly dates are skipped; only valid emitted dates
count. Ambiguous recurring timestamps use PostgreSQL's post-transition offset, validated
against ordinary, negative-DST, half-hour, political and date-line transitions.

Durable exceptions retain original local keys. Whole-series timing/timezone/rule
changes with active exceptions require an explicit audited reset and preserve the
inactive rows. Ordinary title/lifecycle edits retain effective exceptions. Canonical
series cancellation dominates older scheduled exceptions. “This and following”
splitting is deferred.

Explicit public/authenticated publication is separate from private full-row access
and venue publication. General projections redact private facilities, instructions,
arrival and relationship labels. Audience labels and public/follower knowledge
cannot grant private schedule authority. Organization-wide read can retain inactive
team/unit history; exact inactive scope and inactive mutation targets fail closed.

Conflict review covers the complete finite series, rather than the displayed month.
Resource/team and actual shared coach/participant attachments are actionable; broad
organization audiences do not automatically reserve every team. Effective canceled/
moved slots prevent false original-slot warnings and missed rescheduled conflicts.
Organization serialization favors correctness over finer lock concurrency in this
initial core. An explicit authorized override additionally needs organization policy
and protected audit capture.

RSVP mode and reminders are configuration foundations. Attendance responses,
delivery, following, ICS export/feed tokens and external calendar subscriptions are
deferred. No guardian response authority, age/consent policy, entitlement rule or
later business module is inferred. Calendar uses finite organization-module
configuration rather than claiming a generic feature-flag precedence engine.
[Detailed calendar choices and limits](CALENDAR_ARCHITECTURE.md).

## Phase 2A/2B foundation choices

The Phase 2A approved architecture is expressed in 22 application tables and six
immutable canonical migrations. Phase 2B adds operational RPC migrations under
`supabase/migrations`, preserving that schema's RLS and approved role matrix. No
business module was implemented in Phase 2B. Phase 3A adds Calendar above. Applied/live status and validation results belong in
`CURRENT_BUILD_STATE.md`; migration files alone do not establish deployment.

| Technical choice | Reason and limit |
| --- | --- |
| Global people, households and participants | Canonical identities may span organizations and need not have Auth accounts; protected relationships provide tenant resource context |
| Auth FK detaches mapping and marks it inactive | Auth deletion preserves canonical person/history; rebinding an old mapping is rejected |
| Partial unique active account per person | Allows historical inactive mappings while preventing concurrent active mappings |
| Same-tenant composite FKs | Units, seasons, teams and scoped assignments cannot point across organizations |
| Conditional generated foreign-key columns | Polymorphic role, entitlement, flag and audit scopes remain anchored to real records |
| Membership entitlement kind | Distinguishes organization, team and household membership references without guessing which UUID table owns a subject |
| Immutable identity/relationship keys | End/archive relationships and create replacements; do not silently repoint history |
| Per-tenant serialized hierarchy edits | Prevent concurrent cycles, including stale repeatable-read snapshots; rare structural writes update the shared organization row |
| Immutable role scope definitions | Avoid a global catalog-row write bottleneck on every scoped assignment; a reviewed migration is needed to change permitted kinds |
| Private caller-bound authorization helpers | Avoid recursive RLS across mapping/relationship/grant tables without exposing an impersonation RPC |
| Authenticated table SELECT only | Finite authenticated RPC commands validate caller, permission and context; no direct client table mutation grants or policies are added |
| No anonymous publication policies | A `public` visibility value is insufficient to publish data without an approved projection/workflow |
| Opaque historical Auth actor ID on audits | Preserves provenance after Auth deletion; live identity ownership remains the strong FK in `user_accounts` |
| Audit UPDATE/DELETE/TRUNCATE guard | Casual rewrites are rejected even by a trusted writer; database owners can still change DDL under an operational process |

Foundation team visibility has one governed named check on `teams`: public,
authenticated, member, restricted and private. Private is the default. Lifecycle
checks use active, inactive, pending, suspended and archived; nullable end times
represent open windows. These checks can be extended by reviewed migrations.

The approved initial role matrix is seeded as 112 explicit potential-capability
pairs. Organization owner/administrator/director roles accept organization scope;
program/sport administrators accept exact unit scope; team roles accept exact
team scope. Support/sales/compliance receive organization visibility only, and
finance/merchant staff receive no current grants. See `PERMISSIONS_MODEL.md`.
No existing Auth user is assigned a Boss person or role automatically.

The migration owner `postgres` can harden its defaults but does not hold managed
`supabase_admin` ownership. That managed owner's future defaults remain unchanged.
All application objects are explicitly revoked/granted and must be created by
the canonical migration owner. PostgreSQL's built-in global PUBLIC function
EXECUTE default cannot be removed by a per-schema revoke alone, so future
`postgres` functions require explicit grants. Existing Auth/Storage functions and
managed owner defaults are unaffected.

### Phase 2B operational implementation choices

| Technical choice | Reason and limit |
| --- | --- |
| Protected authenticated RPCs | Atomic database validation and audit capture without a service credential, direct client table grants or wider role mappings |
| Strict managed Auth session checks | Sensitive operations require the current signed session and eligible Auth user, in addition to canonical identity |
| Explicit self provisioning and account link | Auth UID/canonical UUID are strong identifiers; email/name matches never silently merge people or confer roles |
| Bounded typed batch with prior-result references | Multi-record family, organization and staff/role workflows commit together or roll back together |
| Private per-actor request receipts | Identical requests replay only after current authorization; no duplicate committed records or audit events |
| Physical resource anchors for period checks | Concurrent relationship mutations use fresh snapshots or fail safely at higher isolation levels |
| Existing exact role permissions for delegation | `roles.assign` and every target permission are required at the actual permitted scope; role names alone confer no grant authority |
| Names-only scoped discovery | Operational organization/roster discovery does not reveal DOB/contact fields or create ordinary global person search |
| Household administration remains platform scoped | The approved schema has no tenant-household authority anchor; tenant grants cannot claim global families |
| Immutable season/team attachments | Unit/season references are assigned at creation, retaining the Phase 2A historical identity constraints |
| Deferred optional entitlement administration | No approved management key exists and core acceptance does not need an invented permission |
| Safe audit projection | Actor/action/resource/time/scope and field names are recorded; raw profile payloads and credential/session values are excluded |

The one-time controlled bootstrap is documented and audited separately. It uses
an existing approved platform role, does not weaken Auth settings, and introduces
no account-specific application bypass. Current test/live/deployment evidence is
recorded in `CURRENT_BUILD_STATE.md`, not inferred from migration source alone.

## APPROVED BUT NOT IMPLEMENTED

Global households have no approved tenant authority anchor; organization-scoped
household keys remain potential capabilities and do not bypass household RLS.
Unit-scoped roles cannot read organization membership lists through a unit
assignment because those membership rows lack a unit resource context. These
limits preserve the approved model rather than inventing relationships.

No descendant-unit authority, consent process, operational account-rebinding/
deletion workflow, anonymous identity projection, product pricing, module-specific
entitlement rule or feature-flag override evaluator is invented. Phase 2B audit
capture and protected name projections implement only the approved operational
core.

## FUTURE

Tenant-family authority, sensitive-field consent and later business-module rules
remain decisions for the main Boss chat. Phase 2B's explicit provisioning, finite
mutation API and permission-subset delegation are implemented within the approved
foundation. Other business modules remain separate future assignments. Existing Auth/email/session operational findings
and Phase 1B direct cookie/header inspection limits remain separate work.
