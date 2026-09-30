# Data model

## IMPLEMENTED

Phase 2A implements 22 foundation tables in `public`, with explicit grants and RLS
on every table. All six migrations are applied to the canonical Boss Supabase
project, `the-boss-platform` (`ilykgwgmxtrrikreacrz`). The SQL files in
[supabase/migrations](../supabase/migrations/) match its migration history.
This document describes their implementation;
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md) records deployment and validation
status. There is no automatic Auth-to-person provisioning or business-module UI.
The final fresh PostgreSQL 17 run passed 911 SQL assertions: 642 across categories
A–P and 269 no-DDL verification assertions. Three coordinated hierarchy checks
also passed, with no cycle and all fixtures and the temporary cluster removed.
Canonical database verification separately passed 269 assertions and confirmed
fixture rollback. Application and CI evidence is recorded separately.

| Area | Tables | Implemented responsibility |
| --- | --- | --- |
| Identity | `people`, `user_accounts` | Persistent person and separate Auth mapping |
| Organization | `organizations`, `organization_units`, `seasons`, `teams` | Tenant, reusable hierarchy, dedicated season/team records |
| Relationship | `organization_memberships`, `team_memberships` | Dated relationships, including non-athlete team members |
| Household | `households`, `household_memberships`, `guardian_relationships` | Explicit households and separately verified guardian authority |
| Participant | `participants` | Persistent participant identity linked to one person |
| Authorization | `roles`, `permissions`, `role_permissions`, `role_assignments` | Permission catalog and scoped, dated assignments |
| Product access | `modules`, `organization_modules`, `entitlements`, `feature_flags`, `feature_flag_overrides` | Independent capability, access and rollout records |
| Governance | `audit_events` | Append-oriented audit foundation |

### Persistent identity

`people.id` is the canonical human identifier. Names, birth date and contact
fields are protected identity data. A person can exist without an Auth account;
neither household membership nor participation requires login credentials.

`user_accounts.person_id` references a person. `auth_user_id` is a unique,
nullable FK to managed `auth.users.id`. A partial unique index permits at most
one active account per person, and an active account requires a non-null Auth
mapping. The mapping supplies identity, not authority from user-editable metadata.

Deleting an Auth user sets its mapping to null and an integrity trigger makes
that account inactive. The Boss account/person records and historical references
remain. An existing account cannot be rebound to a different Auth identity;
relinking workflows are outside Phase 2A.

`participants.person_id` is unique and non-null. Team or season changes do not
create a new participant. The optional participant reference on a team membership
uses `(participant_id, person_id)` to prevent connecting a different person's
participant record.

### Tenant and relationship integrity

Organizations have globally unique, normalized slugs. Units have a same-tenant
parent FK and sibling-slug uniqueness, including root units. Direct self-parenting
is prohibited. A private invoker trigger serializes hierarchy changes by updating
the organization row and checks ancestors for cycles.

Seasons and teams are dedicated tables. Composite FKs require each referenced
unit/season/team to belong to the supplied organization. Team slugs are unique
within an organization. Season and registration date ranges cannot run backward.

Relationships use explicit status, `starts_at` and optional exclusive `ends_at`.
History is retained by ending or deactivating rows. Identity, tenant, subject and
relationship-start columns are immutable on existing rows; a different relationship
requires a new row. FKs generally restrict deletion of referenced operational
records. These constraints support history; a complete retention/deletion workflow
has not been implemented.

Households are explicit records, not inferred from addresses or contact details.
Household membership and primary-contact labels do not grant guardian authority.
Guardian relationships prohibit self-guardianship and default authority and
capability booleans to pending/false. Profile access requires active, current,
verified guardian authority and `can_manage_profile`. The other guardian capability
fields are stored foundations; their corresponding workflows are not implemented.

### Scoped references and governance

Role assignment scopes are platform, organization, organization unit or team.
Scope checks and generated FK columns enforce real targets and tenant consistency.
Assignment scopes must also match the role's `allowed_scope_types`, which are
immutable catalog identity alongside the role key. Changing permitted scope kinds
requires a reviewed migration. See [PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md).

The catalog seed defines 19 roles, 17 permissions, 13 modules and 112 approved
role-permission mappings. Platform roles accept platform assignments; organization
owner, organization administrator and athletic director accept organization
assignments; program and sport administrators accept organization-unit assignments;
team roles accept team assignments. Finance and merchant-network staff have no
foundation permission mappings. No real person, account or role assignment is
seeded. Management permission keys describe potential authority without opening
client writes or implementing a management workflow.

Entitlements have organization, person, household or membership subjects.
`membership_kind` disambiguates organization/team/household membership subjects;
generated columns enforce the corresponding real FK. Feature flag overrides
use platform, organization or person targets, also backed by conditional FKs.
Generated columns are integrity projections and must not be supplied by clients.
Optional entitlement source IDs remain provenance identifiers rather than invented
business-domain relationships.

Audit events carry actor, resource and scope context plus optional object-shaped
before/after data. Supported scopes are platform, organization, organization unit,
team, person and household. Platform/person/household scopes have no organization
context; organization scopes match their tenant. Conditional generated FKs anchor
unit/team/person/household scopes to real records and enforce matching tenants for
unit/team references. Resource type/ID remain opaque provenance identifiers.
Historical Auth actor IDs are also opaque provenance, not a cascading Auth FK.
Service writers receive SELECT/INSERT only; UPDATE/DELETE/TRUNCATE triggers reject
audit rewrites. This is not a complete event emitter or tamper-proof external log.

Indexes cover real FK lookups, tenant hierarchy queries, canonical person/Auth
mapping, membership subjects, role scopes, entitlement subjects, flag scopes and
audit retrieval. Unique catalogs and relationship-period keys enforce stable
identifiers without speculative business indexes.

### Lifecycle and visibility

Lifecycle checks use `active`, `inactive`, `pending`, `suspended` and `archived`.
Visibility vocabulary is `public`, `authenticated`, `member`, `restricted` and
`private`; Phase 2A applies it to teams, which default to private. Visibility is a
classification, not a publishing grant. No foundation table is anonymously exposed.
See [TENANCY_MODEL.md](TENANCY_MODEL.md) and [SECURITY_MODEL.md](SECURITY_MODEL.md).

## APPROVED BUT NOT IMPLEMENTED

The foundation supports future server workflows that combine relationships,
permissions, product access, visibility and resource context. Account/person
provisioning, controlled administrative mutations, public publishing, granular
identity projections and full consent/retention workflows require subsequent work.

## FUTURE

Business tables, processing, pricing and product workflows for fundraising,
Boss Bucks, payments, commerce, registration, documents, messaging and advanced
sports are absent. Module catalog rows do not implement those products.
