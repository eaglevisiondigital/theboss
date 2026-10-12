# Game Center foundation

## Phase 6D tournament linkage

A bracket match has stable identity before scheduling, then links exactly one
authorized canonical Game Center game whose sport and entry teams match. Game
Center remains authoritative for operators, roster, scoring, sport rules,
statistics, finalization and correction epochs. Tournament advancement consumes
only the current official winner/finalization and never replays sport events. A
changed winner reconciles before downstream play; after downstream play starts it
requires an explicit tournament ruling. See
[the tournament architecture](TOURNAMENT_BRACKET_ARCHITECTURE.md).

## Phase 5E deployed implementation

Volleyball and the approved shared stat catalog/profile/snapshot/coverage foundation
are deployed on Boss. Volleyball uses the first profile-aware Live Stat Console;
earlier sport engines retain their accepted facts and sealed history through finite
adapter contracts and honest legacy coverage annotations. See
[Phase 5E acceptance](PHASE_5E_HOSTED_ACCEPTANCE.md) and
[the 70-point report](PHASE_5E_COMPLETION_REPORT.md) for actual release gates,
hosted/runtime distinctions, temporary-authority restoration and remaining limits.
This does not authorize another sport, aggregation or public athlete statistics.

## Permanent tracking-profile and live-console amendment

Main Boss Chat requires a shared optional-input layer across sport engines:
[Boss Stat Tracking Profiles and Live Stat Console](STAT_TRACKING_PROFILES_ARCHITECTURE.md).
Required scoring/state remains mandatory. Game-side snapshots preserve tracking
expectations and coverage: not tracked is not zero. Volleyball must use this from
inception; prior sports receive adapters without rewriting canonical facts or
seals. Practice stays isolated from official writes/history. The linked model is
proposed; integration and validation are pending. No later sport is started.

## Phase 5D Football extension and history portability

Football is the third engine on the same Calendar/game, roster, operator,
operation/receipt, lifecycle and final-epoch foundation. It adds typed football
plays, normalized field/down/possession state, bounded drives, countdown quarters
and explicit overtime boundaries. All score/stat facts remain engine derived.
Cross-sport history reads sealed individual records through persistent person and
participant identity. Transfer preserves origin provenance and correction
ownership; it does not expose prior-team private resources to the new team.
See [Football](FOOTBALL_ENGINE_ARCHITECTURE.md) and
[history](ATHLETE_HISTORY_ARCHITECTURE.md). Implementation is in progress;
previous phase history remains below.

## Phase 5C Soccer extension

The second sport engine layers onto the same game, exact Calendar occurrence,
roster, operator functions, receipt/sequence, lifecycle and final epoch. Soccer
has an ascending server clock and appropriate shot/card/keeper/participation
semantics; it does not rename Basketball's countdown model. Four independent
controls remain default off. Canonical sport keys and permanent engine ownership
prevent overlap or legacy scoring bypass. Safe family projections, low-volume
notifications and authenticated refresh reuse existing interfaces. See
[Soccer architecture](SOCCER_ENGINE_ARCHITECTURE.md). Validation is in progress;
prior foundation and Basketball evidence below is historical and preserved.


Phase 5A implementation contract. The starting branch head is
`378b93e8db2880527dd80b640ca3989ce5c5c409`. This phase establishes shared operating
records for competitive Calendar occurrences. Sport scoring engines, statistics
and fan delivery remain future work. Validation and deployment results will be
recorded separately after execution.

## Existing foundation audited before migrations

The Phase 3A `events` table owns organization, scheduling/timezone, venue/resource,
status, visibility/publication, recurrence and audience. `event_targets` attaches
organization, exact unit and team recipients to the same event. Supporting/cheer
targets are recipients, not automatically competitive sides. `event_game_details`
already records an internal opponent or external name, home/away/neutral and
schedule status. These facts are reused, not rebuilt as another schedule.

Calendar updates replace target and game-detail rows transactionally. Durable
operating records therefore reference tenant-qualified `events`, never a transient
target/detail row. The existing `calendar_occurrences` expansion and occurrence
exceptions supply exact recurring identity. Phase 4B Attendance supplies current
roster availability and check-in, with no second attendance system.

Existing Sports activation is dated organization-module state. Existing team-only
scorekeeper and livestream-operator roles currently have only `team.view`.
There is no reliable canonical sport field in team/unit labels. A six-entry stable
sport catalog and an explicit required game sport selection are the minimum
extension. No sport is inferred, no existing team/unit is backfilled, and no sport
engine becomes operational merely by selecting that sport.

## Canonical identity and Calendar authority

One-time competitive events have at most one operating game. Its original local
occurrence key stays fixed even when Calendar reschedules the event; effective
schedule fields follow the current one-time event. Recurring games have one
identity per event and original occurrence key. They are created explicitly only
for competitive event types. Practice series do not become games.

An internal opponent is a same-tenant participating team targeted by the same
Calendar event. An external opponent remains the existing external name and
requires no new organization. Two competitive sides are supported in Phase 5A;
future sport-specific multi-team competitions require a reviewed extension.
Home/away/neutral is relative to the primary team. Competitors and home/away are
frozen after linkage. Calendar may still change time, venue and supporting targets.
Recurring anchor/timezone/rule edits that invalidate linked identity fail closed;
exact occurrence exceptions provide rescheduling/cancellation.

Scheduling and operating commands lock the event before the game. A completed
Calendar command reconciles game schedule/context/version and appends history;
it does not reject Calendar's transient delete/reinsert steps. Cancel/postpone
blocks ordinary operations immediately. Finalized score, roster and ledger facts
remain sealed even if the Calendar is subsequently changed.

## Lifecycle, state and score

Core lifecycle is scheduled, pregame, live, paused, delayed, suspended, final,
canceled, postponed or abandoned. A finite transition matrix fails closed.
Starting, finalizing and reopening are separate protected commands. Starting
requires current event/occurrence, participating-team validity, feature state,
operator authority and roster readiness. Concurrent or retried commands cannot
create another active game session.

Only shared lifecycle, ordered version, score summaries and finalization context
belong in core. No nullable quarter/inning/clock/possession collection is introduced.
The initial manual score-summary operation appends before/after history. It is
not a basketball goal/shot, football touchdown or another sport event engine.
An explicit reversal references a prior valid operation rather than deleting it.
Ordering and a caller-bound request receipt make retries deterministic. Authority
is rechecked before a receipt is returned, so revocation defeats stale retries.

Finalization seals an immutable score/roster revision with actor/time and epoch.
Ordinary operations stop. Elevated correction permission and a reason are required
to reopen; prior finalizations remain intact and refinalization creates a new epoch.
No season or career aggregate is computed.

## Roster and operators

Roster snapshots preserve minimal game-time athlete/person identity, safe display
name, jersey, position foundation, active/captain/starter foundation and finite
availability/check-in state. They omit DOB, contact, guardian information and
private absence reasons. Pregame replacement creates another immutable revision;
later season membership changes do not rewrite historical revisions.

Explicit assignments link a person, game, current authorizing role assignment,
exact participating team, function, start/end, status and assigning actor.
Only game administrator and scorekeeper functions operate in Phase 5A. Future
clock/statistician/livestream functions require their own reviewed policy/engine.
An assignment never replaces permission, actual relationship, feature or resource
checks. Team role alone never grants all-team game operations. A coach never gains
live score operation merely from the coach role. Scorekeepers cannot finalize,
reopen, publish, assign broader authority or manage another team's roster.

## Authorization and projections

Seven distinct permissions cover view, create, manage, operate, finalize, correct
and publish. Platform and organization administration receive scoped capability;
athletic directors omit publishing, program/sport administrators omit correction
and publishing. Team administrators/head coaches receive exact-team management
only behind separate default-off policy. Assistant coaches, staff and livestream
operators receive view only; scorekeepers receive view/operate potential only.
Actual authority also requires live canonical identity/session, current scoped
relationship, Sports feature state, game/event context and visibility. Scope has
no descendant inheritance. Management preserves Calendar's all-target authority
when changing/linking scheduling context.

Private roster reads require exact-side roster authority or current own/dependent
relationship. Household membership grants none. A Falcons operator may update the
shared Falcons/Wildcats score but cannot read Wildcats private roster or operate an
unrelated game. Family projections omit operator/correction/audit details and
never offer operating controls. Anonymous game APIs remain closed in this phase.
Future public summaries may contain matchup, schedule, venue, status and score;
publication cannot bypass Calendar visibility/publication authority.

## Features and integration

Game Center is a Sports capability, with independent default-off `game_center`,
`game_operations`, `public_game_center`, `team_game_management` and
`head_coach_game_management` controls. Future live-scoring/statistics/leaderboard/
livestream names remain nonoperational. Calendar is scheduling authority;
Attendance is availability authority. Existing Communications/Notifications receive
safe source hooks for lifecycle and assignment, with no high-volume score pushes
or new SMS/provider infrastructure. Calendar and Family Hub link to the authorized
game view rather than duplicating records or controls.

Authorized administrators configure only these five implemented boolean flags
through the transactional games.configure command, using existing org.manage
and current organization relationship. The existing Sports module must already
be active. organization_modules.version is monotonic concurrency metadata: actual
configuration/status/window changes advance it, explicit revision rewriting is
rejected, and this command merges only approved booleans while retaining unrelated
configuration. Receipt replay still requires current Auth and organization
management authority. Disabled Game Center can be configured back on without
creating new module activation or future capability.

## Extension contract

A future sport engine binds to stable sport/game identity, owns normalized
sport-specific state and event types, validates segments/clock/roster/positions,
and deterministically projects the canonical score. It uses the core ordering,
idempotency, current operator authorization, reversal/audit and finalization gates.
It must not create another game, schedule, identity or score database.

A future statistics engine consumes sealed finalization epochs and versioned
sport definitions to produce game/player/team/season/career projections. Reopen
invalidates derived results through explicit supersession, not silent rewriting.
No aggregation or statistical product is implemented in Phase 5A.

## Bounded performance and evidence

Reads cap date windows at 93 days and collections at finite limits, use tenant /
team / status / time indexes, resolve current occurrence once per request context,
and project only authorized fields. No persistent private cache or timeout increase
is introduced. All historical migrations remain immutable.

Fresh PostgreSQL 17 SQL and concurrency evidence, current schema/type/advisor
verification and native hosted acceptance will be reported with actual results.
Forged signed hosted requests unavailable through approved browser tools retain
the accepted SQL/runtime evidence label. No test-only production endpoint or
session extraction is allowed. Controlled testing uses synthetic records with
baseline, fixed expiry, recovery and immediate zero-residual cleanup.

## Main Boss Chat closure record — October 4, 2026 UTC

Main Boss Chat approved **Phase 5A Game Center Foundation: COMPLETE** after
reviewing the second/final controlled hosted acceptance and accepting six
residual evidence limitations. Reviewed branch head:
`520a32be5827e45e0f53b93b7dd42ada6aad8eeb`; successor CI PASS. This records closure
of the implemented foundation and changes no architecture or product rule.

Repeated administrator LIVE-detail navigation/reload passed in the final window;
the first-window failure did not recur. Its historical root cause remains
undetermined. No known Phase 5A product/runtime defect or architecture
contradiction remains. Original administrator access and exact baseline were
restored with zero residual temporary authority and pending controlled work.

The accepted limitations cover roster-change versus historical-snapshot hosted
comparison; positive started/operator-assigned/canceled notification receipt;
separate scorekeeper sibling-program/organization negatives; Phase 5A household-
only hosted context; Start/final confirmation interaction at 390px/320px; and
forged signed requests unavailable through approved tooling. Their exact
classifications are preserved in
[the appended closure record](PHASE_5A_BLOCKER_INVESTIGATION.md#main-boss-chat-phase-5a-closure)
and [the acceptance record](PHASE_5A_ACCEPTANCE_ADDENDUM.md). They are accepted
test-evidence limitations, not known production defects; unperformed hosted
cases retain their original classifications.

All historical implementation contracts, INCOMPLETE reports and first-window/
investigation evidence remain preserved. This closure is documentation only:
no application, schema, migration, Auth, security-policy, deployment or
architecture change. No third acceptance window or Phase 5B is authorized or
opened by this task. PR #3 remains OPEN/DRAFT/UNMERGED. STOP after Phase 5A closure.

## Phase 5B Basketball extension

Phase 5B extends this historical foundation with the approved Basketball engine.
The original Phase 5A contract above remains preserved. The current extension is
documented in [Basketball engine architecture](BASKETBALL_ENGINE_ARCHITECTURE.md):
one core game identity, operation ledger and finalization epoch, with typed
Basketball state, plays and immutable statistical seals. No other sport engine or
season/career statistics are included.


## Phase 6A prepared statistical intelligence

Prepared Phase 6A derives statistics only from the current authoritative sealed epoch of all six implemented sport engines. Versioned finite classification binds an epoch boundary; legacy sources remain pending. Finalize/reopen/refinalize atomically changes statistical generation/work; deferred bounded refresh runs after sport/tracking seals exist. Prior contributions and seals remain immutable. Contested origin locks return pending rather than waiting while retaining game locks. Silent season changes remain rejected by existing immutable game identity; no new season-correction architecture is invented.
