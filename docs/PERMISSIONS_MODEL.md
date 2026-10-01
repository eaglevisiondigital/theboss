# Boss foundation permissions

## Phase 3A calendar permissions

Five keys add 35 explicit mappings: `events.view`, `events.create`, `events.manage`,
`events.publish` and `events.override_conflict`. Current totals are 22 permissions,
147 mappings and the same 19 roles. Capability mapping never replaces actual
tenant/target scope, active role/window, module, feature or relationship checks.

Super/platform administrator and organization owner/administrator receive all five
within their existing assignment scope. Athletic director receives view/create/
manage in the assigned organization. Program/sport administrator receives those
three in the exact assigned unit. Head coach gains view plus own-team create/manage
when the organization enables head-coach management. Assistant coach, team
administrator and team staff gain view only. Other roles gain no calendar keys.
Every current and proposed target must authorize edits; one owned team cannot
confer authority over another target in a multi-team event. Descendant inheritance
remains absent.

Publication requires `events.publish` and the public-schedules feature, for public
and authenticated general audiences. Anonymous callers receive only explicitly
published public schedule fields. Unrelated authenticated canonical users can see
published authenticated schedule fields through the safe RPC, without full event
rows, private facilities, instructions, family or roster data. Member/restricted/
private boundaries continue to require actual relationship or scoped authority.
Audience labels, follower knowledge, filters and UUID possession confer no grant.

Verified active guardian relationships provide relevant dependent schedule reads,
never scheduling or attendance-response authority. Household membership alone is
insufficient. No attendance permissions or response endpoint are added while the
response workflow is deferred.

Calendar writes require active actual targets even for platform roles. Organization-
wide calendar view can retain inactive team/unit history in an active organization
and Calendar module; draft/private history requires management authority. An
inactive exact unit/team scope does not acquire authority through historical reads.
[Full role, visibility and feature contract](CALENDAR_ARCHITECTURE.md).

## Identity and foundation permissions

Identity is resolved from the verified Auth subject through an active
`user_accounts` mapping to an active canonical `people` row. A valid Auth login
without that mapping grants no core data access. User-editable Auth metadata is
never consulted. Anonymous Auth identities are rejected by the identity helper.

Permissions belong to roles through `role_permissions`. Assignments belong to
people and carry a lifecycle window and one validated scope: platform,
organization, organization unit or team. Role keys and permitted scope kinds
are immutable catalog identity; changing a scope definition requires a reviewed
migration. No `is_admin` column, implicit role from membership labels or
automatic role assignment exists.

| Scope | Permission reach |
| --- | --- |
| Platform | Cross-tenant access only for explicitly mapped permissions |
| Organization | Matching organization and resources inside that tenant |
| Organization unit | Exact unit and resources attached directly to it |
| Team | Exact team; does not grant organization-wide authority |

Organization-unit descendants do not inherit authority automatically. Actual
organization/unit/team references are validated before a scoped permission is
considered. Assignments, roles and permissions must be active; assignment windows
must include the current time. Tenant/resource status checks also fail closed.
An expired relationship cannot grant access, although a person may still read
their own historical relationship row.

The catalog contains the approved foundation role names, the example foundation
permissions and two canonical identity permissions, `person.profile.view` and
`person.profile.manage`. Those two distinguish private person information from
participant metadata. The Phase 2A initial matrix contains 112 explicit
role-permission pairs. No person receives a role automatically.

| Role | Allowed assignment scope | Seeded potential permissions |
| --- | --- | --- |
| Super administrator, platform administrator | Platform | All 17 foundation keys |
| Support, sales, compliance | Platform | `organization.view` only |
| Finance, merchant network staff | Platform | None; no current operational need or module permission is inferred |
| Organization owner, organization administrator | Organization | The 15 approved operational keys, excluding canonical person profile keys |
| Athletic director | Organization | Organization/member view; team/roster view/manage; participant view/manage; household view; roles view |
| Program administrator, sport administrator | Organization unit | Organization/team/roster/participant view/manage and roles view, limited to exact unit context |
| Head coach | Team | Team/roster view/manage and participant view |
| Assistant coach | Team | Team/roster/participant view |
| Team administrator | Team | Team/roster view/manage |
| Team staff | Team | Team/roster view |
| Volunteer coordinator, scorekeeper, livestream operator | Team | Team view only |

Support/compliance are limited to organization visibility because no narrower
approved support or compliance operational context exists yet. Finance has no
current need for the optional organization visibility grant. Future module powers
are not inferred from any role name. Owner and administrator remain separate
catalog definitions even where their current permission sets are equal.

Mappings define potential capability. Organization-scoped `household.view` does
not expose global households: the foundation has no approved tenant-household
authority relationship. Those reads remain self-related or explicitly platform
privileged. Unit scopes do not imply organization membership-list authority;
memberships have no unit resource anchor. A future resource model/workflow must
settle either extension before those grants can authorize such operations.

Authenticated Data API foundation table clients retain SELECT only, subject to
their existing RLS. Calendar adds its own strict SELECT policies and safe projections. No INSERT/UPDATE/DELETE/TRUNCATE policy or grant is added, including for
platform administrators. Phase 2B implements protected `boss_admin_mutate` commands
through a public invoker wrapper and a private, finite definer dispatcher. A
platform person role does not confer database-owner privileges.

## Protected reads

- People: own identity, a dependent covered by currently verified explicit
  guardian profile authority, or explicit platform `person.profile.view`.
- Participants: own/dependent record or matching scoped
  `participant.profile.view`. This does not expose another person's DOB/contact.
- Organizations/units/seasons: active organization relationship or scoped read
  permission. An active team relationship can also reveal that team's season.
- Private teams: actual active team relationship or scoped `team.view`.
- Organization member lists/other team roster rows: respective scoped read
  permissions; the person's own relationship history remains readable.
- Households: active household relationship or platform `household.view`.
  Membership/guardian rows are self-related or explicitly platform privileged.
  Household membership never grants another person's private profile authority.
- Role assignments/audit events: exact scoped `roles.view`/`audit.view`.
  Own role history is readable; being an audit actor is not a read grant.
- Catalog definitions: active canonical Boss identity required. Configuration
  JSON is for low-risk settings and must contain no secrets or private profiles.

Modules, entitlements, flags and visibility do not grant permissions. Access-check
helpers first check subject visibility and then current status/windows; membership
entitlements additionally require an active underlying relationship and parent
resource. Seeing relationship history does not activate product access.

## Phase 2B protected operations

Both read and mutation RPCs require a confirmed, non-anonymous, non-banned,
non-deleted Auth user with a signed `session_id` owned by a live `auth.sessions`
row, including its `not_after` limit. Core operations additionally require an
active canonical account/person. Explicit self provisioning is the sole unmapped
identity operation and grants no role.

Each mutation resolves the actual resource, then checks the relevant existing
permission at its exact organization/unit/team context. A supplied organization
or team UUID cannot establish authority. Participants reached through scoped
management require an actual current organization or roster relationship; exact
unit management covers only a team attached directly to that unit. Platform
permissions may explicitly recover an inactive resource; scoped grants still fail
closed for inactive resources. Existing anchored relationships can be ended or
inactivated without activating an inactive target identity.

A role assignment requires `roles.assign` plus every permission mapped to the
target role in the same actual scope. Permitted scope kinds, active role/person,
windows and target relationships are checked independently. A caller cannot grant
powers they lack, assign a broader scope, or use module activation as authority.
The 19 roles, 17 keys and 112 approved mappings remain unchanged.

Household creation/membership administration uses platform `household.manage`;
organization household keys have no approved global-family authority anchor.
Guardian administration additionally requires platform `person.profile.manage`.
Verification is explicit and cannot be performed by the relationship's guardian
or dependent. A currently verified guardian with `can_manage_profile` may update
approved dependent name fields only, including no identity status or authority
flags. Household membership alone supplies no mutation authority.

`boss_admin_read` keeps table RLS unchanged and offers a names-only, bounded
scoped projection for legitimate organization/roster discovery. Separate global
lifecycle projections require the existing platform `organization.view`,
`team.view` or `audit.view` key for their respective collection. They expose safe
archived resource/history metadata so explicitly privileged operators can review
and recover records; scoped callers retain active-resource restrictions. Ordinary users have no
global people search. Scoped candidates are selected from authorized relationships
before canonical person lookup, and global capability checks are cached per
request. The global directory retains substring search and a bounded result set;
large-directory search/pagination and load validation remain future scale work.
UI tools are supplied from current capabilities; the RPC
reauthorizes every call and all request replays. No frontend context choice,
hidden control, membership label or Auth metadata is a security boundary.

## APPROVED BUT NOT IMPLEMENTED

Sensitive-field consent and tenant-household administration need approved
resource/permission direction. No person is automatically granted a role.
Guardian register/document/payment/waiver flags remain stored foundations only;
the corresponding business actions are absent. Entitlement administration is
deferred because the approved catalog has no entitlement-management permission
and the operational acceptance workflows do not require it.

## FUTURE

Business operations must combine caller identity, relationship, scoped permission,
appropriate entitlement/module capability, rollout availability, visibility and
resource context. Permission alone is not a replacement for those module rules.
Consent, sensitive-field projections, cross-unit inheritance and rollout override
precedence are not inferred by this foundation.
