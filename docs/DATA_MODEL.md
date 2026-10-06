# Data model

## Phase 6D tournament and bracket extension

Tournament stages, brackets and stable matches extend an existing Phase 6B
Competition Edition. Immutable revision, seed, advancement and ruling records
preserve structure and decision provenance. A seed references an existing
competition entry; a scheduled match references one existing Game Center game and
its Calendar event. No team, schedule, score, roster or statistics record is
duplicated. See [the tournament architecture](TOURNAMENT_BRACKET_ARCHITECTURE.md).

## Phase 6C Athlete Profile and Recruiting Showcase

`athlete_profiles` is a one-to-one presentation extension of the existing
participant/person pair. It does not create identity, membership or statistical
truth. Immutable `athlete_profile_revisions` hold approved presentation fields;
append-oriented measurables, achievements, verifications and media references keep
actor, date, source and visibility provenance. Historical origins remain the
canonical memberships and Phase 6A/6B materializations.

`recruiting_showcases` points to immutable showcase revisions, one explicit active
consent and the published profile revision. Consent records retain subject, actor,
categories, version, grant/revocation and optional expiry. Share-link rows store a
SHA-256 digest and short display prefix only; raw 256-bit tokens exist solely in the
bounded server response. Current stat/record/ranking facts are read by reference
from existing materializations and are never copied into a second stat database.
See [the full architecture](ATHLETE_PROFILE_RECRUITING_ARCHITECTURE.md).

## Phase 5D Football and portable sealed athlete history

Football adds bounded state, typed whole-play facts, current lineup state,
immutable sport finalization headers and UUID-keyed JSON stat rows. All retain
canonical game/organization/roster/operation identities. Whole kick/return and
fumble/recovery outcomes capture their underlying action once; immutable
supersession preserves original facts and origin order. Source Basketball and
Soccer stats are not rewritten or copied.

A closed cross-sport projection joins player seals through immutable roster
snapshots to persistent person/participant identity and originating game/team/
organization/season/epoch. Current verified self/guardian authority permits only
that athlete's history. Current original-team membership is unnecessary; new-team
membership grants no access. Older seals remain distinguishable from the latest
sealed and currently authoritative epoch. No season/career aggregation is added.
See [Football](FOOTBALL_ENGINE_ARCHITECTURE.md) and
[athlete history](ATHLETE_HISTORY_ARCHITECTURE.md). Validation is in progress.

## Phase 5C Soccer extension

Soccer uses five tenant-qualified tables for bounded state, typed events, current
lineups, epoch metadata and normalized UUID-keyed final stats. It reuses canonical
game/Calendar/roster/operator/operation identities. Typed event participation
snapshots provide interval history; no duplicate schedule or sport identity is
created. Single shot outcomes derive score, attempts, SOG and saves; own goals
retain conceding-side attribution. Complete participation supports minutes and
keeper GA; incomplete evidence yields null. Immutable Soccer epochs bind existing
core finalizations. Implementation validation is in progress. See
[Soccer architecture](SOCCER_ENGINE_ARCHITECTURE.md).


## Phase 5B Basketball extension

Basketball binds to the existing `games` identity, exact Calendar occurrence,
snapshot roster and canonical operation sequence. `game_basketball_states`
records bounded period/clock/lineup policy; typed `game_basketball_events` reference
the same ordered operations. Immutable supersession/reversal links preserve
original plays. `game_basketball_lineups` is current state; immutable lineup
history records substitution boundaries. Event-derived per-game totals are
reconciled to the canonical score. Basketball finalization and normalized stat
rows bind to the existing core finalization epoch, not another final-game system.
Season/career aggregates and records remain future contracts. See
[the Basketball architecture](BASKETBALL_ENGINE_ARCHITECTURE.md).

## Phase 5A canonical Game Center records

The applied migrations complement `events` and `event_game_details` with
`game_sports`, `games`, immutable `game_roster_snapshots`, explicit
`game_operator_assignments`, ordered immutable `game_operations` and sealed
`game_finalizations`. Private caller-bound receipts preserve idempotent requests.
Tenant-qualified event/team/unit/season/venue references prevent cross-tenant
linkage. Single events have one durable game; recurring games bind one exact
original occurrence. Competitors are frozen after linkage, while scheduling
follows Calendar. Snapshot revisions and finalization epochs retain history.
No sport engine, private profile copy or statistics aggregate is added.
organization_modules.version adds monotonic optimistic-concurrency metadata; only
actual configuration/status/window changes advance it, and direct revision rewrites
are rejected. Focused runtime checks pass; final full checks and canonical
application passed. See
[Game Center architecture](GAME_CENTER_ARCHITECTURE.md).

## Phase 4B canonical coordination records

The applied migrations add six closed attendance tables: `event_attendance_settings`, `attendance_responses`, `attendance_response_history`, `attendance_checkins`, `attendance_checkin_history` and `attendance_requests`; plus four closed volunteer tables: `volunteer_role_definitions`, `volunteer_shifts`, `volunteer_assignments` and `volunteer_assignment_history`. Two private operation-receipt tables bind retries to the canonical actor, request and input.

Responses identify the canonical event, retained occurrence key, participant/staff context, subject and responder. Guardian authority uses the dedicated default-false `can_respond_attendance` capability. Reasons, notes and arrival/departure differences remain private. Material context changes preserve snapshots and may require explicit reconfirmation. Single-event anchors survive rescheduling; changes between single and recurring modes retire old anchors while retaining history.

Volunteer shifts carry exact organization/unit/team scope, optional canonical event occurrence, finite capacity, deadline, visibility and reminder offset. Assignments retain an active/canceled episode, actor and immutable history. Capacity changes and signup transitions share one transactional shift anchor. A selected-volunteer announcement adds a tenant-qualified optional shift reference to an existing communication audience; messages and attachments continue to use the existing communications records.

Read-only canonical verification confirms these 12 closed RLS tables, all 38 new foreign keys with supporting indexes, and 73 public tables overall. All 29 migrations are applied, including six Phase 4B migrations; the previous 23 remain unchanged. Final controlled-authority cleanup is verified with zero residual temporary access and the original administrator restored. Hosted acceptance remains incomplete. See [Phase 4B validation](PHASE_4B_VALIDATION.md).

## Phase 4A communications and notifications

One tenant-owned thread holds canonical messages and sequences. `communication_threads`,
`communication_thread_members` and `communication_audiences` separate channel context,
bounded explicit membership and authorized announcement targets. `communication_messages`
retains one content record; revisions preserve edits and removed messages retain
their canonical history while disappearing from ordinary projections. `communication_read_state`
records monotonic per-person read watermarks. Attachments and reports use
`communication_attachments` and `communication_reports` with tenant-qualified references.
All new raw tables use RLS and are closed to anonymous/authenticated direct access.
Private receipts, upload intents and short access leases support guarded operations.

`notification_events` identifies a canonical existing-module source and stable revision.
`notifications` deduplicates that event by canonical person; context explains the
projection without merging team chat membership. `notification_preferences` separates
channel/category/context choices. `notification_deliveries` separates channel state,
attempts and provider acceptance from confirmed delivery. Private expansion jobs
support bounded resumable audience processing; no broad client-defined payload,
recipient or notification type is accepted. See [communications](COMMUNICATIONS_ARCHITECTURE.md)
and [notifications](NOTIFICATION_ARCHITECTURE.md). Application/live validation remains
separate in CURRENT_BUILD_STATE.md.

## Phase 3B registration records

Phase 3B adds 21 tenant-owned public tables, with RLS and no anonymous or
authenticated direct table privileges. Authenticated reads and writes use finite
caller-bound RPCs. Migration source defines the model; application, live migration
and acceptance evidence belongs in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

| Area | Tables | Responsibility |
| --- | --- | --- |
| Offering | `registration_offerings` | Exact organization/unit/team context, optional existing season/event, dates, eligibility, capacity and manual assignment policy |
| Versioned collection | `registration_form_versions`, `registration_waiver_versions`, `document_requirements` | Immutable published form, consent text and document requirement versions |
| Offering attachments | `registration_offering_forms`, `registration_offering_waivers`, `registration_offering_documents` | Future registration requirements, independent from frozen historical snapshots |
| Registration | `registrations`, `registration_form_answers`, `waiver_signatures` | Persistent participant reference, independent workflow states, draft answers and immutable completed evidence |
| Private documents | `registration_documents`, `document_upload_intents` | Private object reference, session-bound upload intent, review, expiration and renewal metadata |
| Emergency information | `participant_emergency_records` | Restricted contacts, medical, physician and insurance fields with audited access |
| Finance | `registration_fee_rules`, `registration_coupons`, `charges`, `charge_adjustments`, `payments`, `payment_allocations`, `payment_plans`, `payment_installments` | Explicit minor-unit obligations, adjustments, offline receipts, allocations and installment schedules |

Same-tenant composite foreign keys bind each registration, attachment, charge,
allocation and plan to its actual organization. Canonical participants and
households remain global; their IDs alone provide no registration authority.
Registration start freezes the offering requirements and participant/family
context. Later published versions affect future registrations. Completed answers,
signed waiver evidence, charge origins, adjustments, payments, allocations and
installments cannot be rewritten through ordinary updates.

Registration, forms, waiver, document, eligibility, approval and roster states
remain separate. Payment status is derived from obligations and allocations.
The current `payments.method` table constraint permits cash/check only; planned
card, ACH and Boss Bucks method types are a static future integration contract.
Extending live methods requires a separately approved migration and validated
execution boundary. Explicit credits remain charge adjustment records.
Draft, submitted or paid registrations create no automatic team relationship or
role. Explicit assignment writes the existing canonical roster only after scoped
authorization and configured prerequisites; explicit removal retains history.

Private request receipts bind actor/request IDs to input hashes and results.
Current authority is rechecked on retry. Private document access leases bind the
actor, current Auth session, purpose and optional exact team. Sensitive responses
are audited without copying their contents into receipt or audit JSON. See
[Registration](REGISTRATION_ARCHITECTURE.md),
[Forms and waivers](FORMS_WAIVERS_ARCHITECTURE.md),
[Document security](DOCUMENT_SECURITY.md) and
[Fees and charges](FEES_CHARGES_ARCHITECTURE.md).

## Phase 3A event records

The Phase 3A checkpoint has 30 public tables: the 22 identity/organization/authorization
foundation tables and eight Calendar tables. Calendar adds `event_types`, `venues`,
`venue_resources`, `events`, `event_targets`, `event_game_details`,
`event_occurrence_exceptions` and `event_reminders`, each with RLS and authenticated
SELECT-only access. Anonymous table access and direct client writes remain closed.

One event is associated with its organization, exact unit or one/many teams through
tenant-qualified targets. Its type uses one extensible catalog. Optional game
details hold only opponent/site/schedule metadata. Venue resources belong to one
same-tenant venue; precise coordinates are not required or stored.

Finite recurrence stores normalized rules rather than future event copies. The
complete series is bounded to five years; count limits are 1-1,000. Exceptions use
original local timestamp keys and retain inactive rows after an explicit whole-
series timing/rule reset. Event versions protect both series and single occurrence
updates. Whole-series lifecycle status takes precedence over prior exceptions.
Effective moved/canceled slots participate correctly in date queries and conflicts.

The private `calendar_operation_receipts` table is RLS-enabled, has no client
privileges and binds an actor/request pair to its input hash/result. It is separate
from Phase 2B receipts. `boss_calendar_mutate` commits its canonical record,
associations, settings, receipt and safe audit together. Same-input retry rechecks
current authority. New calendar features extend the catalog to 14 modules, 22
permissions and 147 role-permission mappings without creating real identities or
assigning roles in migrations.

RSVP mode and reminder configuration are foundations only. Attendance responses,
following, ICS feeds/subscriptions and reminder delivery remain deferred.
[Calendar architecture](CALENDAR_ARCHITECTURE.md) defines exact recurrence, timezone,
exception, projection, publication and conflict limits. Current deployment/test
status remains separate in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

## Phase 2A/2B foundation

Phase 2A implements 22 foundation tables in `public`, with explicit grants and RLS
on every table. All six migrations are applied to the canonical Boss Supabase
project, `the-boss-platform` (`ilykgwgmxtrrikreacrz`). Their applied SQL is recorded in [supabase/migrations](../supabase/migrations/).
The six Phase 2A files remain immutable. Phase 2B adds operational RPC migrations;
application, live migration and acceptance status are tracked separately. This
document describes the implemented model;
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md) records deployment and validation
status. Phase 2B implements explicit identity provisioning and operational admin
UI. No Auth trigger silently provisions identities or roles. Phase 2B did not
implement business module UI; Phase 3A adds the separate Calendar described above.
At the Phase 2A checkpoint, the final fresh PostgreSQL 17 run passed 911 SQL assertions: 642 across categories
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
Phase 2B permits an explicit, audited first link to an eligible verified Auth
identity. Rebinding an existing mapping remains prohibited.

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
fields were stored foundations at the Phase 2A/2B checkpoint. Phase 3B separately
enforces `can_register`, `can_sign_waivers`, `can_view_documents` and
`can_manage_payments` for the corresponding registration workflows.

### Scoped references and governance

Role assignment scopes are platform, organization, organization unit or team.
Scope checks and generated FK columns enforce real targets and tenant consistency.
Assignment scopes must also match the role's `allowed_scope_types`, which are
immutable catalog identity alongside the role key. Changing permitted scope kinds
requires a reviewed migration. See [PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md).

The Phase 2A catalog seed defines 19 roles, 17 permissions, 13 modules and 112 approved
role-permission mappings. Platform roles accept platform assignments; organization
owner, organization administrator and athletic director accept organization
assignments; program and sport administrators accept organization-unit assignments;
team roles accept team assignments. Finance and merchant-network staff have no
foundation permission mappings. No real person, account or role assignment is
seeded. Management permission keys describe potential authority without opening
direct client table writes. Phase 2B implements the finite protected operational
workflows described below, without changing these mappings.

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
classification, not a publishing grant. No foundation table is anonymously exposed. Phase 3A uses an explicit safe
calendar RPC projection without opening anonymous table privileges.
See [TENANCY_MODEL.md](TENANCY_MODEL.md) and [SECURITY_MODEL.md](SECURITY_MODEL.md).

### Phase 2B operational records and writes

The 22 public foundation tables and their SELECT RLS policies are preserved.
`boss_admin_mutate` exposes a finite command set for explicit self provisioning,
account linking, organizations, module activation, units, seasons, teams, names,
households, participants, guardians, memberships and scoped role assignments.
Commands contain only approved fields and typed references to earlier results.
A bounded batch is one PostgreSQL transaction, so a later failure rolls back its
records, audit events and receipt.

Self provisioning requires a confirmed, non-anonymous, current managed Auth
identity and session. It creates a new canonical person/account pair without a
role. An existing strong Auth mapping is reused. A matching canonical email
requires administrative review; email/name matching never silently merges people.
Account linking requires platform `person.profile.manage`, explicit canonical
person/Auth identifiers and an eligible Auth account. Existing mappings cannot be
rebound. People and participants may be created without Auth.

Operational person writes and scoped discovery expose names only, excluding DOB,
email and phone. Scoped discovery resolves actual active organization/roster
relationships. Household membership does not establish guardian authority;
verification and stored capability changes require the existing explicit platform
permissions. The Phase 2B workflow itself did not implement registration, document,
waiver or payment actions. Phase 3B combines those independently stored flags with
the actual registration context; household membership remains insufficient.

Season parent units and team parent-unit/season attachments are selected at
creation and remain immutable. Existing relationships retain their identity/type/
start; ending/inactivation followed by a new record preserves history. Active
period collisions and duplicate primary contacts are rejected. Physical resource
anchor updates serialize relationship checks, including stale repeatable-read
snapshots, without altering business fields.

Each significant mutation appends an actor-bound event with operation, resource,
actual scope, request identifier and changed field names. Raw input profiles,
credentials and session values are not audit payloads. A private RLS-protected
`boss_private.admin_operation_receipts` table provides per-actor request
idempotency. No client table ACL permits receipt access. Retries require identical
input and current authorization, and do not duplicate committed records/events.

## APPROVED BUT NOT IMPLEMENTED

Public publishing, sensitive-field consent projections, full consent/retention
workflows and tenant-family authority relationships still require approved
direction. No descendant-unit inheritance or account-rebinding correction flow
is inferred from the operational API.

## FUTURE

Fundraising, Boss Bucks value/ledger execution, processor settlement, commerce,
messaging and advanced sports remain absent. Phase 3B implements registration,
private documents and cash/check allocation foundations described above, without
executing card, ACH or Boss Bucks payments. Catalog rows do not implement later
products.

## Phase 5E prepared forward schema

Shared tables: `game_stat_catalog_versions`, `game_stat_catalog_items`,
`game_tracking_profiles`, `game_tracking_profile_revisions`,
`game_tracking_snapshots`, `game_stat_coverage_intervals`,
`game_finalization_tracking_seals`. Volleyball tables: `game_volleyball_states`,
`game_volleyball_events`, `game_volleyball_finalizations`,
`game_volleyball_final_stats`. All enable RLS immediately and revoke raw client
access. Composite tenant/resource foreign keys have matching indexes. Catalogs,
revisions, snapshots, coverage and final seals are immutable. Profile lifecycle
updates preserve identity; authorized RPCs append audited revisions.

Exact resolution order: sport default, organization, direct organization unit,
team, matching team-season, game side. No implicit descendant inheritance.
Intervals are ordered by canonical sequence; their end is the next snapshot
boundary or finalization cutoff. Reopen/refinalize appends a new epoch without
rewriting prior tracking/fact seals. **NOT TRACKED IS NOT ZERO** is permanent.


## Phase 6A prepared statistical intelligence

Five prepared Phase 6A tables separate immutable versioned competition classification/contributions from rebuildable current-epoch selectors, originating-team summaries and refresh work. Contributions bind canonical organization/game/final epoch, game season, roster revision, person/participant, tracking snapshot, source-stat identity, coverage, participation and definition versions. NULL game seasons remain unassigned career segments; no current membership attribution. Only explicitly official current final epochs contribute. No canonical Phase 6A migration has been applied at this checkpoint.


## Phase 6B implemented local schema (canonical application pending)

Four forward migrations add seventeen closed public tables for stable Competition,
Edition, flat edition groups, canonical team entries and explicit group windows;
exact Competition/Edition manager assignments; immutable policy, game-assignment
and ruling revisions; private comparison definitions; rebuildable scopes/standings/
candidates/work; immutable record events and scope-bound current co-holders.
All tenant/source identities use canonical foreign keys and indexed referencing
vectors. Record holder/event/candidate composite foreign keys prevent one group
from adopting another group's recognition. Legacy role assignment scopes remain
unchanged; the explicit competition bridge does not create organization memberships.

Current final official Phase 6A selections and sealed contributions remain statistical
truth. Explicit counting game assignment is separate from statistical eligibility.
Unplayed forfeit outcomes do not manufacture athlete statistics or differential;
played rulings preserve canonical scores. Records retain definition/policy versions,
original organization/team/season/person/participant, game/finalization/epoch/source
generation, qualification/coverage and separate achievement/recognition timestamps.
Immutable prior recognition survives corrections and subsequent restoration.

## Phase 6E verified recognition

`athlete_achievements` remains the canonical athlete honor. Its optional immutable
definition revision identifies Phase 6E issuance; earlier rows remain valid. New
`entity_achievements` covers only team and organization recipients. Definitions,
immutable revisions, source-aware recognition state/history, display choices, award
nominations/decisions, competition-close snapshots, bounded refresh work and private
request receipts supply recognition over existing facts. Source ID/generation,
organization/team, sport/season, achieved/recognized dates and issuer remain distinct.
No parallel athlete identity, score, statistics or records authority is introduced.
