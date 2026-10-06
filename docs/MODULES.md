# Modules and product access

## Phase 6C Athlete Profiles and Recruiting Showcase

Phase 6C extends the authenticated platform with `/app/athletes`, Family Hub profile
links and an unlisted `/recruiting/[token]` presentation. It adds no independently
activatable organization module or feature flag: access is derived from existing
identity, current relationship, permission and consent contracts. Profile
completeness is informational and never changes visibility.

Showcases start as private drafts. A current authorized guardian approves the exact
revision/categories before publication; a manager may create, revoke or expire
individual links and disable the showcase. Highlight support is limited to approved
HTTPS references. Recruiter contact interest remains a documented future inbox
contract; no recruiter CRM, direct contact disclosure, public athlete directory,
media hosting, marketplace or later module is activated.

## Phase 5D Football controls

`football_live_scoring`, `football_stats`, `football_play_by_play` and
`football_lineups` are finite default-off Sports configuration, independent of
Basketball/Soccer. Current Sports/Calendar and exact-game authority gates remain.
A configured Football game cannot fall back to manual score/roster mutation when
flags are disabled. Portable athlete history is a separate safe sealed-record
read; disabling a former team's live module does not erase a child's verified
historical record. No provider infrastructure or later sport is activated.

## Phase 5C finite Soccer controls

Sports adds independent default-off `soccer_live_scoring`, `soccer_stats`,
`soccer_play_by_play` and `soccer_lineups`, for thirteen implemented Game Center
booleans overall. Existing Game Center, operations, current Sports and Calendar
context still gate access. Configuration activates no organization implicitly and
cannot enable another engine, public Game Center or later module. Live Soccer
requires live scoring and stats; enforced participation requires lineups;
play-by-play display has its own gate. Already configured Soccer ownership stays
closed to legacy manual scoring after disable. Validation is in progress.


## Phase 5B finite Basketball controls

Sports adds four finite default-off controls: `basketball_live_scoring`,
`basketball_stats`, `basketball_play_by_play` and `basketball_lineups`. Game
Center/operations and current Calendar/module activation remain independently
required. A game is not silently adopted: explicit pregame initialization requires
a zero-score snapshot and no prior manual score history. Live entry requires
live-scoring and stats controls; enforced lineups require lineup controls.
Play-by-play display is independent. No feature activates another sport, public
Game Center, season/career totals, records, leaderboards or provider infrastructure.

## Phase 5A canonical Sports capability

Game Center extends the existing Sports module with default-off `game_center`,
`game_operations`, `public_game_center`, `team_game_management` and
`head_coach_game_management`. Migration creates no organization activation.
Core game views, explicit operating assignments, manual audited summaries and
finalization are the implemented capabilities. Live sport scoring, statistics,
leaderboards, clock engines and livestream remain nonoperational regardless of
unrecognized configuration names. Calendar and Attendance remain their canonical
authorities. Existing Notifications receive low-volume source hooks only; no
score push, SMS or provider activation is added. Finite configuration is available to currently authorized org.manage callers
while Game Center itself is disabled, provided Sports is already current/active.
It merges the five implemented booleans using module-version concurrency and
preserves unrelated fields. Canonical migration application passes; hosted acceptance is interrupted and
incomplete. Temporary configuration was restored to its captured baseline;
see [the acceptance addendum](PHASE_5A_ACCEPTANCE_ADDENDUM.md).

## Phase 4B independent controls

Calendar attendance and the existing Volunteers module are separate opt-ins. Four supported combinations are Calendar alone, Calendar with attendance, Calendar with Volunteers, and Calendar with both. The independent runtime combination matrix passed in the full disposable PostgreSQL suite.

Attendance flags include attendance, RSVP, participant self-response, guardian RSVP, attendance reminders, check-in, head/assistant coach management and an adult minimum self-response age. Attendance-specific keys are prefixed in stored Calendar configuration to prevent legacy flag collisions. Volunteers flags include volunteers, self signup, reminders, head/assistant management and an adult minimum signup age.

An active module assignment alone does not activate its private features. Authorized administrators can enter a configuration-only context for a disabled feature; ordinary users receive no private collections or actions. Configuration updates merge finite fields into the existing active module assignment and do not create implicit grants. Disabled or expired assignments close current application access.

The applied canonical catalog projection marks Volunteers implemented. Availability still requires an explicit current module assignment and feature configuration; migration application creates no implicit organization access. Hosted acceptance remains incomplete. Final controlled-authority cleanup and exact selected module baselines are verified with zero residual temporary access and the original administrator restored. See [Phase 4B validation](PHASE_4B_VALIDATION.md) for the remaining hosted gaps. The public website and all later module implementations are untouched.

## Phase 4A shared communications

The existing stable `messaging` catalog key serves Communications. One shared
notification engine integrates Calendar and Registration source events, including
safe document decisions and offline fee receipts; these modules do not create
separate notification systems. Independent finite controls gate announcements,
team chat, staff send, direct/group messaging, guardian visibility, participant
messaging, minor groups, attachments, moderation, in-app and email channels.

Within an active module, communications, announcements, guardian visibility and
in-app notifications default on. Conversational/participant/attachment/moderation
and email features default off. Participant minimum age defaults to 18, with
participant messaging independently disabled; lower-age production policy is not
silently activated. Disabled features hide controls and deny server operations.
Guardian visibility controls permitted minor groups; ordinary guardian team-chat
access separately requires the current explicit receive/send capability.
Email templates and an injected provider-neutral adapter do not configure live
email. SMS/push, fundraising, Boss Bucks, Money Board and later modules stay outside
Phase 4A. [Communications](COMMUNICATIONS_ARCHITECTURE.md), [notifications](NOTIFICATION_ARCHITECTURE.md).

## Phase 3B Registration capability

Phase 3B implements Registration with reusable forms, waivers, private document
review and fee/offline-payment foundations. They operate under the active
`registration` organization module. The existing `documents` catalog entry remains
separate; activating it alone does not expose Registration files. Calendar and
Sports activation are independent, and an optional same-tenant event association
does not enable or authorize Calendar actions.

`registration.configure` accepts a finite Boolean configuration and requires
organization-wide `organization.manage`. Unit/team roles cannot enable broader
organization features. Within an active Registration module, `registration`,
`forms` and `waivers` default enabled; `documents`, `fees`, `payment_plans`,
`coupons`, `waitlists`, `offline_payments`, `emergency_access` and
`coach_registration_view` default disabled. Malformed Boolean configuration fails
closed. Activation/settings provide availability, never permission or relationship.

Every read/mutation/Storage access evaluates the applicable feature and current
authority. Emergency access needs document and emergency features plus actual
exact-team context. Offline receipt entry needs fee and offline-payment features
plus its scoped permission. A coach summary setting grants no document or financial
capability. Disabling a feature preserves its canonical history while closing the
corresponding runtime path.

These bounded module settings do not implement the future generic entitlement or
feature-flag precedence engine. Payment-plan selection stores context and explicit
authorized installment schedules; it does not charge a card or bank automatically.
Card/ACH/Boss Bucks are planned static contract types; live payment rows and commands
permit cash/check only. Future methods require an approved migration and validated
integration before becoming executable.
[Registration contract](REGISTRATION_ARCHITECTURE.md) and
[Finance boundary](FEES_CHARGES_ARCHITECTURE.md) describe the implemented limits.

## Phase 3A independent Calendar module

Calendar extends the catalog to 14 modules. Active Sports does not automatically
enable Calendar, and Calendar operates without Sports. The existing authorized
module activation workflow enables it; activation never grants event permission.
At the Phase 3A checkpoint the organization projection marks Calendar implemented
while later modules retain their future classification. Phase 3B additionally
implements Registration.

`calendar.configure` accepts only finite Boolean organization-module settings and
requires organization-wide `organization.manage`. Organization/team calendars,
recurrence and conflict detection default enabled after activation. Public
schedules, head-coach management, conflict overrides and attendance default disabled.
Head-coach management and conflict override require both potential role capability
and the corresponding organization policy. Unit/team grants cannot configure the
organization module or enable broader authority.

Calendar read/mutation paths independently enforce active module, target context,
features, roles/relationships and visibility. Configuration is distinct from the
unfinished generic feature-flag/entitlement evaluator. No large settings engine is
added. The attendance setting cannot be enabled in Phase 3A: RSVP modes are stored
but response/guardian-response workflows and attendance permissions are deferred.

Event type labels, minimal game opponent/site details and reminder configuration
implement no registration, fundraising, volunteer engine, Game Center, notifications
or other later product. ICS export/subscriptions and following remain deferred.
[Configuration and runtime contract](CALENDAR_ARCHITECTURE.md).

## Product-access foundation

Phase 2A implements the capability/access/rollout data foundation. Phase 2B
adds authorized organization module activation administration, without implementing
business modules. These
three concerns remain separate from authorization. Deployment and validation
status is recorded in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).
All six foundation migrations are applied to the canonical Boss project. Live
inspection at the Phase 2A checkpoint verified 13 module definitions and no
operational activations, entitlements or feature flags after fixture rollback. The live suite passed 269
assertions. The final disposable run passed 911 SQL assertions and three
concurrent hierarchy checks, with no cycle and verified fixture/cluster cleanup.
Application and CI validation remain separate from these database results.

| Concern | Tables | Meaning |
| --- | --- | --- |
| Organization capability | `modules`, `organization_modules` | Catalog and dated organization activation/configuration |
| Product access | `entitlements` | Dated access records for an explicit subject |
| Rollout/availability | `feature_flags`, `feature_flag_overrides` | Definitions and dated platform/organization/person overrides |
| Authorization | `roles`, `permissions`, `role_permissions`, `role_assignments` | Independent permission decision in resource context |

The Phase 2A authorization catalog seeds 19 roles, 17 permissions and 112 approved
role-permission mappings. Those potential capabilities require a valid active
assignment in its permitted scope; no real assignments are seeded. Organization
owner/administrator and athletic director use organization scope, program/sport
administrators use exact organization-unit scope, and team roles use team scope.
These mappings implement no business module or direct client table write API.
Phase 2B administration uses protected, audited RPC commands.

### Modules

Module keys are stable, unique catalog identifiers. The initial Phase 2A catalog covers
`fundraising`, `boss_bucks`, `sports`, `engage`, `registration`, `documents`,
`messaging`, `volunteers`, `money_board`, `commerce`, `livestream`, `fan` and
`reporting`. Phase 3A adds `calendar`. Catalog presence does not mean product functionality exists.
The catalog migration records the final seed implementation; no organizations,
families, teams or customers are seed data.

`organization_modules` links a real organization/module with a lifecycle state,
source, start/end window and object-shaped configuration. Activation defaults to
inactive. Relationship identity/start fields are immutable; changes can end an
old period and create another. The `organization_module_active` helper checks the
caller's authorized subject visibility, an active module and a current active
activation. It does not grant permission to read any other data.

### Phase 2B activation administration

The organization admin view shows each catalog module's current activation as
active/inactive and separately identifies implementation status. Phase 3A marks
Calendar implemented at that checkpoint; Phase 3B additionally implements Registration.
Activation/deactivation is a validated, audited transactional
operation with same-organization references. It creates or updates the current
activation period; immutable historical keys remain intact. Request replays do
not duplicate writes or audits.

Sports activation can be recorded alongside the approved organizational sports
foundation: units, seasons, teams, participants and rosters. Activation supplies no
permission by itself and does not enable schedules, registration, games, scoring,
statistics, livestreaming or any other sports module workflow. Calendar has its own authorized UI; no placeholder later-module workflows are
activated by Sports.

### Entitlements

An entitlement targets an organization, person, household or explicit membership.
Membership targets require `membership_kind` of organization, team or household;
conditional generated FKs prevent ambiguous or nonexistent subjects. Records
include type/key, lifecycle/window, provenance and object-shaped configuration.
They default to inactive and have no hard-coded prices or geographic products.

The `has_active_entitlement` helper first checks authorized subject visibility,
then the entitlement's status/window/key and active subject. Membership subjects
also require a current active underlying relationship and active parent resources.
Seeing one's historical membership or its entitlement row does not activate
product access. An entitlement does not replace scoped permission or authorize
an unrelated organization, team, person or household.
No entitlement purchasing, assignment UI, pricing engine or commercial workflow
is implemented. Optional entitlement administration is deferred: no approved
entitlement-management key exists, and the Phase 2B core acceptance workflow
does not require it. No broader permission is invented.

### Feature flags

Definitions have a unique key, enabled value, lifecycle and configuration.
Rollout classifications are `experimental`, `phased`, `organization_pilot`,
`emergency_disable` and `internal_only`. Flags default disabled. Overrides target
platform, organization or person, with real FKs for organization/person scopes and
an explicit status/window. Phase 2A does not seed speculative flag definitions.

These records supply a configurable foundation. Rollout percentages, precedence
resolution, emergency-disable evaluation and application feature gates have not
been implemented. A classification alone neither changes runtime behavior nor
authorizes access. No RLS predicate uses a flag or entitlement as a permission.

### Protection

Product-access tables have RLS and explicit client SELECT grants only. Catalog
reads require a usable canonical identity. Organization activations, entitlements
and overrides remain subject/context restricted. Trusted server writers may
populate them under the trusted boundary. Phase 2B adds a protected `module.set`
operation and module administration UI using organization-wide
`organization.manage`; unit/team grants cannot activate an entire organization
module. Direct client table mutation remains denied.
See [SECURITY_MODEL.md](SECURITY_MODEL.md) and
[PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md).

## APPROVED BUT NOT IMPLEMENTED

Future module endpoints must separately evaluate applicable capability,
entitlement, rollout, permission, relationship, visibility and resource context.
The Phase 2A helpers provide foundations for those checks, without selecting new
pricing, assignment, publishing or flag-resolution rules.

## FUTURE

Later workflows remain unimplemented: campaigns/donations/referrals, Boss Bucks
memberships/geographic discounts and value execution, Money Board, processor and
settlement ledgers, merchants/offers/redemption, messaging/notifications, volunteer
scheduling, Game Center/scoring/statistics, livestreaming, products/orders/fulfillment
and CRM. Registration/forms/private document review and offline allocations are
the bounded Phase 3B implementation above. No catalog/configuration row activates
the later products.

## Phase 5E Volleyball

Volleyball is a Game Center adapter within Sports, using existing Calendar games,
roster snapshots, exact operator assignments, finalization epochs and athlete
history. Finite Sports flags are `volleyball_live_scoring`, `volleyball_stats`,
`volleyball_play_by_play` and `volleyball_lineups`; they default off. Required
match state remains independent of optional analytics depth. Basketball, Soccer
and Football participate through catalog/console contracts while keeping their
canonical engines. No Baseball/Softball or later module is introduced.
