# Boss Stat Tracking Profiles and Live Stat Console

Status: data and interaction model approved by Main Boss Chat on October 5, 2026.
Implementation integration and validation are pending. This is a permanent
cross-sport requirement, not a Phase 5E release
claim. Volleyball must use this foundation before release. Basketball, Soccer
and Football retain their canonical engines and historical evidence.

## Ownership

Calendar owns schedule identity. Game Center owns game identity, roster revision,
exact-game operators, caller receipts, ordered operations, lifecycle and final
epochs. Sport engines own typed facts, valid transitions and score/stat reducers.
A profile controls optional input expectations and presentation. It cannot change
sport rules, formulas, permissions, visibility, roster eligibility or features.
Settings inheritance never carries authorization or descendant-unit authority.

## Proposed shared records

These names describe proposed new records, not deployed tables. All raw tables
receive immediate RLS and deny direct client writes. Server commands require
current authorization, optimistic versions, caller-bound receipts and audit.

| Record | Responsibility |
| --- | --- |
| `game_stat_catalog_versions` | Immutable code/migration-defined sport catalog versions; no client-defined executable formulas. |
| `game_stat_catalog_items` | Finite sport-qualified keys, classification, supported input actions, dependency keys, team/player scope, implementation availability and derived-formula identifier. |
| `game_tracking_profiles` | Stable profile identity at platform sport default, organization, exact program/unit, team, team-season or game-side scope. Validated tenant-qualified FKs, lifecycle window and monotonic version. |
| `game_tracking_profile_revisions` | Append-only preset/custom selections, enabled optional keys, ordered Quick Stats, catalog version, actor, request and reason. |
| `game_tracking_snapshots` | Immutable effective profile for one canonical game and side, roster revision, resolved selections, source revision chain and exact effective operation sequence. |
| `game_stat_coverage_intervals` | Append-only per-stat/side coverage evidence at canonical operation boundaries; tracked and not-tracked intervals, with partial coverage derived from mixed or uncertain intervals. Attribution coverage is explicit where necessary. |
| `game_finalization_tracking_seals` | Immutable link from canonical final epoch to exact snapshot revisions, coverage summary and cutoff. Reopen/refinalize creates another seal. |

Each side gets its own snapshot: one team's choices cannot change its opponent's
tracking expectations. Shared required match facts remain common. An external
opponent uses a game-side profile without creating another team identity. Profile
configuration does not reveal an opposing private roster.

No sport fact is duplicated in these records. Optional input still invokes the
existing typed sport commands. Profile changes use shared Game Center ordering
and receipts; coverage boundaries use operation sequences, not client clocks.

## Catalog and presets

Classification and implementation availability are separate. Full means all
implemented optional inputs, not future analytics or unimplemented measures.

| Class | Examples and behavior |
| --- | --- |
| Required scoring/game-state | Shot value/result, goal/result, Football play placement/possession/down/distance, Volleyball rally point/set/service. Cannot be disabled. Lineup rules remain mandatory when the engine configuration requires them. |
| Optional manual observations/attribution | Assist, dig, rebound, reception and eligible player/defensive attribution. Omission is allowed only where the engine's contract permits it. |
| Derived | Hitting/shooting percentage and typed-play totals. Never directly editable; availability and coverage follow engine-defined dependencies. |
| Advanced | Future passing grades or rotation efficiency. Unavailable/deferred until separately approved and implemented. |

Dependencies form a finite server-validated acyclic graph. Selecting a derived
measure exposes its necessary inputs before saving. Quick Stats select enabled
supported input actions, not percentages or unavailable measures. A kill/error
credits its attack exactly once; an optional assist references the same kill and
does not award another point.

Score Only provides mandatory score/state entry, omitting optional attribution
only where valid. Essential, Standard, Advanced and Full are versioned,
sport-specific presets; Custom stores explicit selections. The configuration
screen previews exact selections/dependencies. Preset names grant no authority.

## Resolution and immutable expectations

Resolve each side through explicitly applicable settings:

platform sport default → organization → team's exact program/unit → team →
matching team-season → game-side override.

Program applicability uses the team's canonical direct unit, with no descendant
traversal. Season selection must match both team and game context. A lower scope
can inherit or supply an explicit selection. Store the complete source chain.

Snapshot at engine setup before play. Later defaults affect future games, never
silently change a configured game. An explicitly authorized game-side change
appends another snapshot at an ordered operation boundary. Required facts remain
enabled in every revision.

Optional stats enabled after play begins are partial unless legitimate audited
historical reconstruction establishes complete coverage. Disable/re-enable cannot
erase gaps. Corrections do not prove unobserved events never occurred.

## Not tracked is not zero

Add a coverage envelope alongside engine counters:

```json
{
  "digs": {"recorded_value": 3, "coverage": "partially_tracked"},
  "assists": {"recorded_value": null, "coverage": "not_tracked"}
}
```

Tracked zero means zero measured under complete declared coverage. Untracked
returns no measured value even when the raw accumulator is zero. Partial exposes
only a labeled recorded subtotal. Attribution gaps cannot turn a complete team
count into a falsely complete individual-athlete count.

Hitting percentage requires kills, attack errors and attempts coverage; zero
attempts yields null. A partial-input ratio, if shown, must be labeled partial.
Athlete history uses the same envelope without changing provenance or ownership.
Future aggregates must consume coverage, not silently sum untracked zeros. No
aggregation is implemented in Phase 5E.

Legacy games have no tracking declaration. Preserve their raw totals and sealed
epochs unchanged; expose partial/unknown coverage with `legacy_unknown` reason
unless complete coverage can actually be established. Do not retroactively apply
Full or claim every zero is measured.

## Permission and mutation model

Propose reusing current scoped `games.manage` capability and existing
coach-management feature policy for configuration. Validate actual target scope,
current role and relationship. Platform/organization/program defaults require
corresponding current management scope. Team/season overrides require that exact
team. Game-side override requires management of that side in that game. No new
role mapping is implied.

Non-game scopes need resource-specific authorization using that approved
capability; do not synthesize a fake game or broaden an assignment. A scorekeeper's
`games.operate` alone cannot configure profiles. A game-administrator operator
assignment alone does not substitute for scoped profile-management authority.

Optional entry still requires current exact-game operation authority, valid
session, features, resource context and expected version. The server rejects new
disabled optional-stat commands as well as hiding controls. Required game facts
remain subject to ordinary engine gates. Correction/reversal of an existing fact
uses its origin snapshot plus current correction authority even if that stat is
now disabled; profile changes cannot obstruct legitimate undo or erase evidence.

Serialize profile changes, input and finalization on shared game ordering.
Recheck authority/features after waits and before receipt replay. Finalization
seals profile/coverage references atomically with sport state/stats. Family and
private-side projections cannot leak operator/audit details or opposing roster.

## Live Stat Console

A shared shell hosts sport adapters. Tablet landscape is the primary layout.
Keep score, period/set/quarter, clock where applicable, possession/server and
game status in a persistent state strip. Provide eligible active participants,
large Quick Stats, contextual selection, recent entries and prominent Undo/Correct.
More Stats, substitutions, Box Score, Play-by-Play and essential controls remain
reachable surfaces. Detailed tables belong outside rapid entry.

Allow an ordered maximum of eight Quick Stats; five to eight is recommended when
enough inputs exist. Score Only can have fewer. Required scoring/state controls
remain visible independently. Disabled optional controls disappear; enabled
non-quick controls appear in More.

Action first: Kill → eligible attacker if attribution is enabled → optional
Assist prompt only if enabled. Player first: eligible athlete → Kill → same
canonical command. Where assist uses a second command, show its independent
pending/saved receipt state. A failed assist never re-awards the accepted point;
retry references the existing kill.

Volleyball prioritizes rally/server/rotation/attack/dig/block/substitution.
Basketball retains shot/result/rebound/assist flow; Soccer goal/shot/save/card;
Football play/down/distance/possession and required placement fields. A shared
visual system does not remove required sport-specific fields or rules.

Recent entries retain receipt-backed pending/saved/error state. Undo/Correct
targets immutable fact identity and current version, requires normal authority
and reason, and preserves evidence. Never retry stale input as a new request or
present an optimistic second point.

At 390px/320px, stack the same workflow with large tap targets and drawers/tabs
for lineup, recent entries and More. Keep critical state reachable during athlete
selection/correction. Do not squeeze desktop stat tables into primary mobile input.

## Practice isolation

Use synthetic participants and isolated in-memory practice state, visibly labeled
Practice throughout. No canonical game/event identifiers, official mutation,
notification, finalization or history/result linkage. No production roles or
guardian authority are created. Reset/discard practice explicitly.

Reuse console interactions and validation adapters where they can run without
writes. Any simulation contract must be unable to invoke official write procedures.
A `practice` boolean on an official game RPC is not sufficient isolation.
Persistent/shared practice storage remains a later product decision; this
foundation introduces no second official ledger or production identity system.

## Integration and evidence

1. Implement shared catalog/profile/snapshot/coverage contracts and validate
   required/dependency rules and exact-scope permissions in disposable PostgreSQL.
2. Integrate Volleyball from inception with profile-gated optional commands,
   console adapter, coverage projections and final/history seal references.
3. Retrofit previous sports through adapters and safe coverage projections,
   preserving canonical reducers, historical migrations and immutable events/seals.
4. Test profile-change/input/finalization races, revocation, forged disabled input,
   replay, corrections under changed profiles, opposing-side isolation and
   practice inability to affect official state.
5. Verify equal facts from action-first/player-first workflows, prompt gating,
   recent-entry recovery, presets/custom selection, desktop/tablet/390px/320px,
   then all historical and Phase 5E validation.
6. Release only through the authorized Phase 5E workflow and one controlled window
   with baseline, prepared recovery, fixed deadline and explicit on-time cleanup.

Volleyball does not yet have a completed console integration. This approved model
creates no live schema, temporary authority or deployment. Keep PR #3 open,
draft and unmerged. No Baseball/Softball or later module is started.

## Approved implementation checkpoint

Main Boss Chat approved this model in the October 5 Phase 5E continuation.
The local implementation uses the catalog version `boss-tracking-v1`, existing
Boss identities/scopes, six ordinary presets and immutable per-side snapshots.
Quick Stats are ordered (maximum eight); required scoring/state controls remain
separate. Volleyball is the first profile-aware live console. Earlier sport
adapters define real finite catalogs/actions/prompts without changing their
reducers, accepted facts or sealed history. Full practice UX remains deferred;
the isolated synthetic contract is implemented. Runtime and release evidence
will be recorded in Phase 5E validation/hosted reports.
