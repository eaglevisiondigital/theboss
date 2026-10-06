# Boss foundation permissions

## Phase 6C profile and showcase capability

Six potential capabilities are added: `athlete_profiles.view`,
`athlete_profiles.manage`, `athlete_profiles.verify`,
`recruiting_showcases.view`, `recruiting_showcases.manage` and
`recruiting_showcases.publish`. Platform/organization administration receives the
finite management set; sport/program administration receives current scoped view,
verification and limited showcase view; head coach/team administration receives
exact-team view and verification only.

Every use still requires current person, tenant, exact team/organization,
participant and resource relationships. A role mapping or remembered identifier
never authorizes access. Minor publication requires a current verified guardian
with `can_manage_profile` and revision/category-specific consent. Household
membership grants nothing. Phase 6C does not infer athlete self-publication from an
Auth account and introduces no public-discovery capability.

## Phase 5D Football and athlete history

Football reuses exact-game operating assignments and existing scoped game
permissions. Selecting Football or enabling its four finite feature flags creates
no operator authority. Current session, original tenant/team scope, roster side,
operator/role windows and features remain server enforced. Historical corrections
use the originating game's current authorized correction workflow.

Portable sealed history is subject-only: authenticated self or a current verified
guardian may read the athlete's own safe record. Household membership, coach,
new-team membership or platform role alone provides no history authority. This
read grants no original-team roster, communications, Attendance, other-family,
operator or correction access. Future family-authorized sharing is a separate
contract and is not implemented here.

## Phase 5C exact-game Soccer operation

Soccer adds no role, permission or broader mapping. Existing current game
administrator/scorekeeper functions authorize bounded segment, clock, event,
lineup and keeper entry only with exact current resource/relationship/feature
checks. Private attribution requires actual roster-side authority. Unknown
opponent/team facts never grant private roster access. Elevated correction,
finalization and reopen gates remain independent. Household membership confers
no family authority; current own/dependent relationships determine identity
projection. Implementation validation is in progress.


## Phase 5B exact-game Basketball operation

No role or permission mapping is broadened. Existing current `games.operate`
potential capability plus an exact current game assignment authorizes period,
clock, play and substitution entry. A coach role alone grants no scoring.
Attributed entry uses only the exact assigned team or independently authorized
roster side, through minimal snapshot name/jersey references. Opponent team
events may remain explicitly unattributed. Existing elevated `games.correct`
permission gates event correction/reversal and core reopening; existing
`games.finalize` gates sealing. Scorekeeper potential does not confer these
elevated capabilities. A separate statistician function is unnecessary for this
bounded engine and is not introduced.

## Phase 5A canonical potential capabilities

Seven applied keys are `games.view`, `games.create`, `games.manage`,
`games.operate`, `games.finalize`, `games.correct` and `games.publish`.
The migrations add 53 explicit mappings, preserving the 21 roles and 14 modules.
Platform and organization administrators receive all seven; athletic directors
omit publish; program/sport administrators omit correct/publish. Team admin and
head coach management require separate default-off Sports policy. Assistant
coaches, team staff and livestream operators receive view only. Scorekeepers
receive view/operate potential and need an explicit exact-game assignment plus
current exact-team membership and referenced role for every operation/replay.
Organization/unit grants additionally require current organization membership.
Own/dependent safe reads require actual current relationships; household alone
is insufficient. Focused runtime checks pass; these mappings are applied canonically.
The finite Game Center configuration command uses existing org.manage plus current
organization context; it adds no new role mapping or module activation.

## Phase 4B verified potential capabilities

The eight new keys are `attendance.view`, `attendance.respond`, `attendance.manage`, `attendance.checkin`, `volunteers.view`, `volunteers.signup`, `volunteers.manage` and `volunteers.assign`. The applied canonical catalog retains 21 roles and 14 modules with 52 permissions and 393 role-permission mappings. The independent runtime matrix and read-only canonical capability checks passed. Controlled hosted restricted-role acceptance is partial; final temporary-grant cleanup is verified with zero residual access and the original administrator restored. See [Phase 4B validation](PHASE_4B_VALIDATION.md) for the remaining hosted gaps.

| Existing role | Attendance potential | Volunteer potential |
| --- | --- | --- |
| Super/platform administrator; organization owner/admin; athletic director; program/sport administrator | view, respond, manage, check-in | view, signup, manage, assign |
| Team administrator | view, respond, manage, check-in | view, signup, manage, assign |
| Head coach | view, respond, manage, check-in | view, signup, manage; no assign |
| Assistant coach | view, respond, manage, check-in | view, signup |
| Team staff | view, respond | view, signup |
| Volunteer coordinator | view, respond | view, signup, manage, assign |
| All other existing roles | none | none |

Potential capability never replaces current scope, relationship, resource or feature checks. Unit grants cover their exact unit and directly related team resources; no descendant-unit inheritance is introduced. Team grants require the current exact team relationship. The volunteer-coordinator role retains its existing team-only scope. Head/assistant management also requires its independent feature policy.

Guardian responses require the dedicated current verified capability and the exact dependent roster/event relationship. Household membership and legacy guardian flags cannot substitute. Adult self-response and volunteer signup require known age meeting the configured minimum, at least 18 in this implementation. No new parent or participant role is created. Selected-volunteer announcements require both scoped volunteer management and the existing announcements permission; no extra communications mappings are seeded.

## Phase 4A communication permissions

Ten finite keys add potential capability only: `communications.view`,
`communications.send`, `communications.manage`, `announcements.send`, `team_chat.view`,
`team_chat.send`, `notifications.view`, `notifications.manage`, `delivery_history.view`
and `moderation.manage`. Migrations assign no real roles. Current identity, exact
scope, actual channel/audience relationships and enabled features remain mandatory.
Organization/unit/team resource IDs and role names provide no independent authority.

Super/platform administrators and organization owner/administrator gain these keys
within their existing allowed scopes. Athletic director gains communication view and
announcement send. Program/sport administrators gain exact-unit communication,
announcement and team-chat capability plus safe scoped delivery history. Head coach
receives own-team communication management, announcements and chat. Assistant coach
and team staff gain own-team view/chat with staff sending disabled by default.
Finance receives no private chat permission merely because it manages fees.

Guardian `can_receive_communications` and `can_send_communications` are explicit,
false-default capabilities separate from registration, signature, document and payment
flags. Household membership alone confers no guardian communication access. Parent
and participant access derives from current actual relationships and configured
policy, without adding inferred roles. Broad communication management alone does
not open private direct/group messages to a nonmember administrator.
Ordinary organization membership supplies recipient context, not sender authority.
Direct/group sending still needs the exact mapped capability or explicit current
guardian/self-participant policy.
[Minor safety](MINOR_COMMUNICATION_SAFETY.md) and [communication contracts](COMMUNICATIONS_ARCHITECTURE.md).

## Phase 3B registration permissions

Phase 3B adds `registration.view`, `registration.create`, `registration.manage`,
`registration.review`, `forms.manage`, `waivers.manage`, `documents.view`,
`documents.review`, `documents.emergency_view`, `fees.view`, `fees.manage` and
`payments.record_offline`. The new `registrar` and `organization_finance` roles
accept organization, exact organization-unit or exact team assignments. The
migrations create potential capability mappings, never real role assignments.

| Role | Added potential capability |
| --- | --- |
| Super/platform administrator, organization owner/administrator | All 12 keys within their existing permitted scope; family signatures still require the actual signer relationship |
| Registrar, program/sport administrator, athletic director | Registration view/create/manage/review, forms/waivers manage and ordinary documents view/review; no financial keys |
| Finance, organization finance | Fees view/manage and offline payment recording; no registration review or medical/document access |
| Head coach, assistant coach, team staff | Scoped registration summary when the organization enables it, plus emergency capability requiring the additional exact-team checks |
| Other existing roles | No new keys |

Assignments, permission records, tenant resources, module activation, feature
policy and actual relationships must be current. Organization-unit reach remains
the exact unit and teams directly attached to it; no descendant inheritance is
added. Possession of registration, document, event or charge IDs is insufficient.

Family registration uses actual self identity or a verified active guardian with
`can_register`. Dependent signatures require `can_sign_waivers`; private document
reads require `can_view_documents`, and dependent fee visibility requires
`can_manage_payments`. Upload additionally requires `can_register`. Household
membership does not substitute for these flags. No staff permission allows forging
the family's form response or signature.

Ordinary registration summary authority does not expose medical answers or raw
documents. Sensitive form and emergency retrievals use audited commands. Emergency
access needs a team-scoped `documents.emergency_view` assignment, actual current
coach/staff membership, the participant's current membership in that exact team,
active document/emergency features and a bounded projection. An organization-wide
grant alone does not authorize that emergency path. Finance authority provides no
medical access. Coaches receive no fee editing or payment recording capability.

[Detailed access contracts](REGISTRATION_ARCHITECTURE.md) and
[Private document boundary](DOCUMENT_SECURITY.md) describe these checks. Runtime
and hosted verification are recorded separately in CURRENT_BUILD_STATE.md.

## Phase 3A calendar permissions

Five keys add 35 explicit mappings: `events.view`, `events.create`, `events.manage`,
`events.publish` and `events.override_conflict`. Phase 3A totals are 22 permissions,
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
| Finance, merchant network staff | Platform | None at the Phase 2A checkpoint; Phase 3B separately adds the listed finance keys |
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
Phase 3B implements the guardian registration/document/payment-view/signature
actions described above. Broader consent and tenant-household administration
remain separate approved work. Entitlement administration is
deferred because the approved catalog has no entitlement-management permission
and the operational acceptance workflows do not require it.

## FUTURE

Business operations must combine caller identity, relationship, scoped permission,
appropriate entitlement/module capability, rollout availability, visibility and
resource context. Permission alone is not a replacement for those module rules.
Consent, sensitive-field projections, cross-unit inheritance and rollout override
precedence are not inferred by this foundation.

## Phase 5E stat configuration

Existing `games.manage` mappings authorize exact-scope profile configuration;
no roles, permissions or role mappings are added. A current scorekeeper/operator
assignment does not grant configuration authority. Game-side edits use exact
participating-team scope; organization/unit/team/season edits use their existing
identities and relationship requirements. Current roles, memberships, resources,
module policy and live Auth state are rechecked after lock waits. Settings
inheritance never creates permission inheritance.


## Phase 6A prepared statistical intelligence

Phase 6A introduces no new role permission or broader grant. Athlete career is subject/self/guardian only. Individual origin-team season slices additionally require explicit organization/team/season scope, existing games.view plus team.roster.view and original resource visibility. Team-season totals require exact existing games.view and every relevant official source game's existing visibility policy. Administrator status alone does not authorize a child's cross-team career. Operational rebuild requires existing organization.manage and the same disclosure policy as the requested projection. Classification uses current games.manage over the canonical game's required sides and requires reopen/refinalize after sealing.


## Phase 6B finite comparative potential capabilities

Twelve new keys: competition.view/manage/policy_manage; standings.view/manage/rebuild;
leaderboard.view/manage/rebuild; records.view/manage/rebuild. Platform administrator,
organization administrator and exact CompetitionManager map all twelve. Athletic
Director, program administrator and sport administrator map the nine view/manage/
rebuild capabilities excluding competition.manage and competition.policy_manage.
Head coach/team administrator map only the four view keys. All other roles gain
none; scoring is not ranking management. No real role assignment is seeded.

The competition_manager catalog role permits competition/competition_edition scopes
only through the dedicated bounded assignment bridge. Existing role_assignments
retain platform/organization/exact unit/exact team scopes. Every mapping remains
potential only: current exact relationship/resource/source/audience authorization
and features are mandatory. No descendant inheritance or fake foreign membership.
Guardian/self authority does not independently include comparative rankings.
