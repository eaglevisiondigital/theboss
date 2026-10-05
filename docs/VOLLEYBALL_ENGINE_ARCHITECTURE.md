# Volleyball engine — Phase 5E

Status: implementation migrated, deployed and runtime validated; core hosted
acceptance verified. Final release/cleanup status belongs in the Phase 5E report.

## Shared tracking and console amendment

Volleyball must use [Boss Stat Tracking Profiles and Live Stat
Console](STAT_TRACKING_PROFILES_ARCHITECTURE.md) from inception. The complete
stat engine remains underneath profile-selected input. Required rally/set/service
facts cannot be disabled. Optional observations and attribution follow game-side
snapshots with tracked/not-tracked/partial coverage. The approved shared model and
Volleyball console are implemented. Previous engines and seals remain
intact.

Volleyball extends the canonical Calendar occurrence, Game Center game, roster
snapshot, exact-game operators, caller receipts and monotonic operation sequence.
The existing game administrator and scorekeeper assignments suffice. Phase 5E
does not introduce a statistician role or broader coach permissions.

## Rally and statistic facts

One rally awards exactly one point. Its finite terminal outcome is kill, attack
error, ace, service error, solo block, assisted block, reception error or
unattributed team point. Error outcomes award the opposing side; other outcomes
award the entered side. A recorded kill/error also credits one attack attempt.
An assisted block credits each entered blocker one block assist and the team one
block, independently of the number of blockers. Solo blocks credit one player
and one team block. No attribution is invented for a team-only outcome.

Nonterminal attack attempts, digs and receptions are separate observations that
award no point. An assist references an active same-side kill, allows one assist
per kill and rejects self-assist/opposing/unknown athletes. Reception errors and
aces describe the same rally through one terminal outcome; a secondary receiver
may be recorded on the ace without awarding another point. Advanced passing
grades, rotation efficiency and federation-specific scoring formulas are deferred.
Hitting percentage is derived from kills, errors and attempts, and is null when
attempts are zero.

## Sets and service

Configuration supports best-of-three/five, normal/deciding targets, win-by-two
and an optional bounded score cap. A set ends at target plus required margin,
or at the explicitly configured cap. Completed set results are captured in the
append-only operation history and later final seal. The next set starts only
through an explicit command identifying its initial serving side. The match
score in Game Center is sets won; current-set points and cumulative rally points
are distinct projections derived from the same ledger.

The point winner retains or receives service. A receiving winner rotates its
ordered court lineup one position before serving. Slot one is the next server;
strict tracking requires the recorded server to match that slot. With tracking
disabled, team-only server attribution remains honest. Service sequence counts
accepted rallies, independently of point totals. Corrections replay these fields
with scores rather than leaving a stale serving state.

## Participation and libero boundary

Court size is configurable from one through six. Initial ordered lineups are
set before each set. Same-side substitutions preserve slot, roster eligibility,
configured substitution limit and re-entry policy. A designated libero is an
explicit roster identity, with configurable service permission; this bounded
foundation prohibits libero attack/block credit. It does not infer association-
specific back-row zones, replacement exemptions, dual libero or jersey rules.
Those differences remain deferred and must not be represented as a complete
federation rules engine.

## Corrections and seals

Facts are append-only with one active leaf per origin. Reversal/replacement
prospectively replays the entire accepted sequence, including set-start,
lineup/substitution, service/rotation and assist dependencies. A correction that
makes a later set or participation fact incoherent is rejected atomically;
dependent facts must be corrected or reversed first. Original completed-set
evidence stays in operation history; corrected set results belong to the later
state and epoch. A match can finalize only after the configured winning number
of sets, with score, roster revision and all active facts reconciled.

Volleyball seals link to canonical Game Center finalization and stable roster
person/participant provenance. Reopen preserves prior seals; refinalization adds
a new epoch. The Phase 5D caller/guardian-owned history reader gains one finite
Volleyball source branch, with no new sharing grant or new-team authority.

## Authorization and release boundary

New raw tables immediately enable RLS and deny direct client access. Private
functions use empty search paths and explicit ACLs. Mutations reuse live native
identity, current role/resource relationship, module/feature checks, authority
locks, optimistic versions and caller-bound idempotency, rechecked after waits.
Four default-off Volleyball flags remain independent of prior engines. Feature
disable never restores legacy manual score authority on an initialized match.

Release requires fresh PostgreSQL 17 historical/Volleyball assertions and real
two-connection races, exact canonical migration/types, application validation,
deployment, one bounded controlled hosted window, on-time explicit cleanup and
zero residual authority. No temporary live authority is activated during design
or disposable validation. No later sport or aggregation is included.

## October 5 approved model and implementation checkpoint

Main Boss Chat approved the shared architecture and authorized Phase 5E in the
latest assignment. The earlier proposal wording above is historical. The shared
catalog, exact-context profiles, immutable per-side snapshots, coverage intervals,
sealed coverage, and profile-aware Volleyball console are implemented locally.
Live migrations/deployment and the single hosted acceptance window remain pending.

Every rally contributes one team service attempt. A player service attempt is
credited only when the strict court order identifies the server, or an accepted
ace/service-error explicitly identifies one. Unknown attribution produces partial
player coverage; it is never presented as a complete measured zero. Unattributed
assisted-block participants and ace receivers likewise retain partial coverage.
Play-by-play context uses the same canonical transition as scoring and replay.

Configuration management reuses mapped `games.manage` with exact resource scope.
The management surface exposes the selected organization plus explicitly filtered
program/team and matching team-season contexts. It does not scan a tenant's full
team hierarchy. Existing sport reducers and sealed history remain unchanged.
Practice currently has the isolated synthetic in-memory contract; full practice
UX is deferred as authorized. No official practice games or history rows are made.
