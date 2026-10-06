# Tenancy model

## Phase 6D tournament isolation

Every tournament row carries its Competition Edition boundary. Entries retain
their owning team organization, while bracket projection shares only safe team
identity, seed, schedule and result facts. Cross-organization participation does
not grant roster, athlete, document, communication, history or correction access.
Exact competition managers need no synthetic tenant/team membership. Guardian and
coach reads remain current subject/team relationships; household membership alone
does nothing.

## Phase 6C athlete-profile isolation

The profile is globally anchored to one canonical participant/person while every
staff view remains derived from a current exact tenant/team relationship. Historical
statistics retain their originating organization, team, season and sealed source.
A transfer does not rewrite provenance, and a new-team relationship cannot unlock
old-team corrections, notes, rosters, communications or private comparative data.

Self/current guardian projections are subject-bound. Household membership alone is
not authority. The unlisted recruiting reader authorizes one active link digest,
active showcase revision and current consent, then emits only approved safe fields.
It has no tenant browsing, roster, Family Hub, document or administration path.
There is no public athlete listing or cross-tenant search endpoint.

## Phase 5A canonical game isolation

Game Center uses the Calendar tenant and one exact competitive occurrence.
Both internal sides must belong to that tenant and target the same event.
An external opponent is a name, not another invented tenant. Supporting teams
remain Calendar recipients rather than competing sides. Exact-unit scope has
no descendant inheritance. A legitimate Falcons operator may operate a shared
Falcons/Wildcats score but gains no Wildcats roster, team management or unrelated
game authority. Roster projections require exact-side or own/dependent authority;
family controls are always closed. These boundaries are SQL/RUNTIME VERIFIED; restricted-role hosted testing was
not reached before the acceptance interruption. The underlying closed raw tables expose only bounded authorized RPCs.

## Phase 4B attendance and volunteer boundaries

All ten new public tables and private receipts are closed to direct anonymous, authenticated and service-role table access. Tenant-qualified foreign keys bind settings, histories, shifts, assignments and optional communication audiences. Public invoker RPCs enter private caller-bound finite dispatchers; clients cannot supply authority or arbitrary recipient identities.

Attendance reads and mutations recheck current event/roster context. Staff summaries filter subjects to authorized exact targets; full event management cannot borrow authority over an unrelated target. Private notes require explicit row capability. Ended guardianships and memberships close current projection access while preserving canonical history.

Volunteer reads, signup and staff assignment require current exact context. Knowing a shift, event or thread identifier creates no access. An old assignment cannot keep private shift visibility after its relationship ends. A former volunteer may cancel an owned commitment through a minimal ownership-only result without recovering private projection access.

Notification recipients are qualified against current access and source-dated relationships/assignment episodes. A selected-volunteer audience adds a current assignment predicate to normal communications, including generic management and attachment paths. No organization-wide authority follows from the shift anchor. The full runtime suite passed, including 100 Phase 4B integration assertions. Canonical checks verify closed raw access and tenant-qualified foreign-key index coverage. Final temporary-authority cleanup is verified with zero residual access and the original administrator restored. Additional controlled hosted isolation acceptance remains incomplete; see [Phase 4B validation](PHASE_4B_VALIDATION.md) for the actual observations and gaps.

## Phase 4A communication boundaries

Communication content, target audience and delivery are tenant-qualified. Multi-team
announcements keep one content record with separate authorized targets; they do not
merge private team channels or expose cross-team recipient lists. Direct/group
members must be bounded and related to the chosen tenant/resource context. Names-only
candidate discovery is scoped; no unrestricted global person search is added.

Every read, attachment byte request and queued notification rechecks current source
and relationship authority. Ending a relationship cannot preserve private channel
access through a remembered UUID, membership projection, stale inbox item or prior
access lease. Exact units include directly attached teams only, with no descendant
inheritance. Global households remain canonical identities rather than tenant grants;
family channels require explicit tenant context, current household membership and
current guardian authority.

## Phase 3B registration isolation

Every offering owns one tenant and an immutable organization, exact unit or exact
team scope. Existing season associations must belong to that tenant and match its
offering context; an optional same-tenant event also requires current authorized
Calendar visibility. Registration requirements, responses,
documents, obligations, payments and installment references use same-tenant
foreign keys. Event association reuses the canonical Calendar event; it neither
copies the event nor grants scheduling authority.

Global participant identity is reused across offerings and seasons. A family
must have actual self authority or the current verified guardian capability for
the requested action. Optional household selection requires current membership of
both the actor and participant in that household, in addition to guardian checks.
An unrelated household, guessed child ID or shared address confers no access.

The registration read RPC independently authorizes list/detail/context selectors.
Staff summary, registration review, financial and sensitive document projections
are separate. A finance assignment can expose an obligation in its actual offering
scope without revealing medical answers; a coach summary exposes no family profile,
charge amounts or payment receipts. Ordinary medical answer retrieval is suppressed and requires
the explicit audited sensitive path. Module/feature deactivation closes access
without deleting history.

Emergency access is narrower than ordinary staff review: an exact team role,
actual active coach/staff membership and the participant's actual active membership
in that same team are all required. A sibling team, ancestor unit, organization-wide
role or guessed document ID supplies no emergency authority. Each private Storage
read rechecks the current actor/session lease and current relationships/permissions.

Cash/check allocations must reference same-tenant, same-currency obligations and
an actual payer in the registration's family/participant context. RLS-protected
private receipts cannot be used to replay an operation after its authority expires.
See [Registration architecture](REGISTRATION_ARCHITECTURE.md) and
[Document security](DOCUMENT_SECURITY.md).

## Phase 3A calendar isolation

Each canonical event has one organization owner. Composite foreign keys enforce
the same organization for targets, venue/resources, internal opponents, game
extensions, exceptions and reminders. Organization, exact unit and team calendars
project that same event. Three targets do not create three event copies.

Family views use currently verified active guardians and the dependent's active
participant/team relationships. Global household/person identifiers are never a
tenant authority anchor. Household membership, public team knowledge, following
or an event UUID cannot reveal private family, roster or schedule records. Child
filters narrow existing authority and deduplicate shared canonical occurrences.
Filter options and target labels are independently authorized.

Both existing and proposed targets must authorize a mutation in their actual
organization/unit/team context. Unit scope remains exact. Inactive targets cannot
be mutated even through platform calendar capability. Organization-wide readers
can retain appropriate inactive team/unit event history while organization and
Calendar remain active; inactive exact scopes do not regain scheduling authority.

Public and authenticated general publication are fixed-field schedule projections,
not anonymous/full-row table grants. General readers never receive private facility
IDs/instructions, private team labels, family or roster data. Public projection
requires explicit public publication, active tenant/Calendar and public-schedules
feature. Disabled/inactive Calendar closes runtime access without deleting history.
See [Calendar architecture](CALENDAR_ARCHITECTURE.md).

## Foundation tenant boundaries

An organization is the primary tenant. Canonical people, participants and
households persist independently of a single organization. Membership and scoped
assignment records connect them to the context in which access is evaluated.
The implementation uses one schema with tenant keys and RLS rather than per-tenant
code forks. Current deployment/test evidence belongs in
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).
At the Phase 2A checkpoint, all six foundation migrations were applied to the
canonical Boss project. Live inspection verified RLS on all 22 foundation tables, 22 authenticated SELECT policies, no mutation
policies, no anonymous table rights and no client write grants. Live verification
passed 269 assertions and confirmed fixture rollback. The final disposable run
passed 911 SQL assertions plus three coordinated hierarchy checks: unsafe edits
failed with `23514` at READ COMMITTED and `40001` at REPEATABLE READ/SERIALIZABLE,
with no cycle. Fixtures and the temporary cluster were removed. Application and
CI validation remain separate from these database results.

### Structural tenant boundaries

`organization_id` anchors units, seasons, teams, organization memberships,
team memberships and organization module records. Composite FKs require units,
seasons and teams referenced by another tenant-scoped record to belong to that
record's organization. Units cannot point across organizations or form cycles.
Generated target columns also constrain role assignment organization/unit/team
scopes to real, matching tenant records.

Person, participant and household IDs are global canonical identifiers. They
are not globally readable. A shared identifier or contact value establishes no
cross-tenant access. Household and guardian relationships are separate from
organization/team membership.

### Read access

Every foundation table has RLS. `anon` receives no application table privileges
or policies. `authenticated` receives SELECT only, subject to caller-bound policy
checks. A usable Boss identity requires an active account/person mapping, a
non-anonymous authenticated request and a matching managed Auth user ID.

| Resource | Baseline access |
| --- | --- |
| Canonical person | Own identity, currently verified dependent profile authority, or explicit platform `person.profile.view` |
| User account | Own account mapping or explicit platform `person.profile.view`; guardian authority does not expose a dependent's account record |
| Organization and units | Active organization membership or the relevant scoped view permission |
| Season | Organization context or a legitimate active relationship with one of its teams |
| Private team | Active relationship with that team or a permission covering its actual context |
| Membership history | Own relationship rows or a reader with the corresponding scope/permission |
| Household | Active membership in that household or explicitly privileged household permission |
| Household membership/guardian relationship | Own relationship rows or explicitly privileged household permission; household membership alone does not expose every member's private relationships |
| Participant | Own/authorized dependent participant or explicitly permitted organization/team/platform context |
| Product access records | Authorized visibility of the record's subject; existence never grants unrelated record access |
| Audit history | Explicit `audit.view` permission in the applicable context |

Private person birth dates/contact information do not become visible to an
organization or team merely through roster membership. Explicit verified guardian
profile authority is separate from household participation. No public/minor
identity projection exists in this phase.

### Permission scope

Membership type labels do not grant administrative authority. A role contributes
only its active permission mappings, through an active assignment within its
relationship window. Team scope matches the specific team; it never supplies an
organization-wide permission. Organization-unit scope matches the exact unit and
resources directly anchored there. It does not implicitly inherit down descendant
units. A permission check validates the actual organization/unit/team resource
context before considering any role assignment.

The approved catalog permits organization owner, organization administrator and
athletic director assignments only at organization scope. Program and sport
administrators are restricted to organization-unit scope; coaches and other team
roles are restricted to team scope. Platform roles use platform scope only.
Allowed scope types are immutable catalog identity. The 112 Phase 2A mappings and 35 added Calendar mappings do
not assign a role to anyone, and management keys do not enable client mutations.

Platform-scoped assignments may cross tenants only for permissions actually mapped
to the role. Authentication alone, module activation, an entitlement and a feature
flag supply no permission. See [PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md) for
the canonical permission contract and catalog decisions.

Inactive, suspended, future or expired relationships do not authorize further
resource access. A person may still read their own historical relationship rows;
reading history does not reactivate its authority.

### Mutation boundary

Client Data API roles cannot create, update, delete or truncate foundation rows.
The migration owner and trusted server-side `service_role` writers remain
privileged operational boundaries. Phase 2B additionally supplies finite protected
RPC commands evaluated as the verified authenticated caller's canonical identity
and exact permissions; clients still cannot mutate tables directly. Service role bypasses RLS and therefore is a privileged
boundary requiring independent server authorization, input validation and audit
context in future workflows. Its credentials must never enter browser code.
Audit grants and triggers further restrict service writers to appending events.
Phase 2A added no administrative write endpoint. Phase 2B uses a public invoker
RPC wrapper with a private definer dispatcher; no privileged application key is
retrieved or required.

Explicit object ACLs and hardened `postgres` future defaults prevent accidental
client grants. Managed owners' defaults are a separate documented operational
boundary; application migrations must continue to declare grants/revokes and RLS.

### Phase 2B operational context

Organization selection is a navigation preference, never an authorization grant.
Every deep link and mutation resolves current identity, actual resource and scope.
Scoped people discovery reveals approved names through real current organization/
team relationships while underlying private person rows remain protected. An
ordinary user cannot search the global people directory. Scoped discovery starts
with authorized relationship IDs before canonical person lookup. Explicit global
read keys separately permit bounded, safe unit/team/audit lifecycle projections,
including archived resources; they do not change base table RLS or grant scoped
callers inactive-resource authority. Global substring search, directory pagination
and load validation at the eventual million-user scale remain future work.

Organization, unit, season and team creation/editing, memberships and scoped roles
use existing approved capabilities. Teams and seasons keep tenant/unit/season
identity attachments immutable after creation. Unit hierarchy changes retain the
same-tenant and cycle guards and introduce no descendant inheritance. Existing
relationships are ended/inactivated and replaced instead of repointed.

Household management stays explicitly platform scoped because no approved
organization-household authority anchor exists. Household membership does not
imply guardian authority or access to another person's private profile. Guardian
verification/capabilities are explicit. Phase 2B supports dependent name updates
through `can_manage_profile`; Phase 3B separately requires the registration,
signature, document and payment capability for each relevant action.

Transactional commands validate references and target relationships inside the
database and append audit events with the actual organization/unit/team/person/
household context. Role grants require every target permission at that same
scope, preventing context selection or guessed resource IDs from widening power.

## APPROVED BUT NOT IMPLEMENTED

Future module workflows must combine their applicable permission, relationship,
module, entitlement, visibility and context. Anonymous publication needs an
approved safe projection/policy. Tenant-family authority and unit inheritance
beyond exact matches remain unresolved; Phase 2B does not infer either.

## FUTURE

No organization-specific product forks, tenant billing, regional discount rules
or cross-product data sharing are implemented. Phase 3B cash/check charge allocation
is a bounded registration foundation; wallet, processor and settlement ledgers
remain future work. Canonical Boss records remain within its dedicated backend.

## Phase 6E origin and relationship isolation

Recognition retains its source organization/team even after transfer. Current-team
staff require authority over that exact current subject/origin context. Wildcats
membership cannot expose private Falcons honors, award notes or restricted peer
rankings. Family access follows verified guardian authority; household membership
alone grants nothing. Career definitions evaluate the explicitly scoped source
organization and optional team; they do not infer cross-tenant aggregation rights.
