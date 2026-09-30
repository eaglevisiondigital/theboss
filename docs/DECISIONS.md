# Boss foundation implementation decisions

## IMPLEMENTED

The Phase 2A approved architecture is expressed in 22 application tables and six
canonical migrations under `supabase/migrations`. No new business module is
implemented. Applied/live status and validation results belong in
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
| Authenticated SELECT only | Mutations need reviewed workflows and audit capture; management permission names alone do not enable writes |
| No anonymous publication policies | A `public` visibility value is insufficient to publish data without an approved projection/workflow |
| Opaque historical Auth actor ID on audits | Preserves provenance after Auth deletion; live identity ownership remains the strong FK in `user_accounts` |
| Audit UPDATE/DELETE/TRUNCATE guard | Casual rewrites are rejected even by a trusted writer; database owners can still change DDL under an operational process |

Visibility currently has one governed named check on `teams`: public,
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

## APPROVED BUT NOT IMPLEMENTED

Global households have no approved tenant authority anchor; organization-scoped
household keys remain potential capabilities and do not bypass household RLS.
Unit-scoped roles cannot read organization membership lists through a unit
assignment because those membership rows lack a unit resource context. These
limits preserve the approved model rather than inventing relationships.

No descendant-unit authority, consent process, operational correction/deletion
workflow, public identity projection, automatic audit capture, product pricing,
module-specific entitlement rule or feature-flag override evaluator is invented.

## FUTURE

The next assignment should settle canonical identity provisioning, tenant-family
resource context and delegation rules, then implement a minimal authorized, audited
server mutation path with meaningful acceptance tests. Business modules remain
separate future assignments. Existing Auth/email/session operational findings
and Phase 1B direct cookie/header inspection limits remain separate work.
