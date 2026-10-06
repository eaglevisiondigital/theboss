# Phase 6D — Tournament and Bracket Management

## Status and boundary

Phase 6D extends a Phase 6B Competition Edition. It does not create another
tournament, team, schedule, game, score or statistics authority. The canonical
chain is:

`Competition Edition → Stage → Bracket → Bracket Match → Calendar Event → Game Center Game → Official Result → Advancement`.

The initial engine is sport-neutral single elimination for bracket sizes 2, 4,
8, 16, 32 and 64, with deterministic seeding, byes, play-in labeling, optional
third place, reviewed reseeding before play, official-result advancement,
correction reconciliation and administrative rulings. Double elimination,
consolation and round-robin finals are extension contracts only.

## Canonical records

- `tournament_stages` gives each edition stage a stable type and order. Types
  include play-in, rounds, quarterfinal, semifinal, championship and third place.
- `tournament_brackets` owns bracket type, capacity, current revision, lifecycle,
  champion pointer and optimistic version.
- `tournament_bracket_revisions` is immutable structural history. Its source
  manifest and digest preserve accepted inputs and reason.
- `tournament_seeds` references existing competition entries. It records seed,
  source scope, source generation, source rank and a manual override reason.
- `tournament_matches` has stable identity independent of Calendar/Game Center.
  Each side is a fixed entry, prior winner, prior loser, bye or unresolved
  qualifier; dependencies are foreign keys rather than display text.
- `tournament_advancements` is append-only, generation-numbered outcome history.
  Official finalization epoch, supersession, bye or ruling provenance is retained.
- `tournament_rulings` is immutable evidence for withdrawal, disqualification,
  forfeit, no contest, manual advancement and correction resolution.

Every public table has RLS enabled and no direct API-role table grant. Private
operation receipts are caller-bound and closed. Public invoker RPCs expose only
finite authenticated reads and signed mutations.

## Seeding, qualification and topology

The generator uses a deterministic recursive seed order, so identical accepted
inputs produce identical slots. Manual seeding requires a reason, version check
and manager authority. Published standings snapshots copy rank, scope and
generation into immutable seed rows. Equal source ranks are rejected; Boss does
not invent a tiebreak. Group qualification requires an explicit group standings
scope and rank for every selected entry, so crossover order such as A1/B2 and
B1/A2 is stored in the accepted seed sequence rather than inferred from UI order.

A missing seed may form a legitimate bye only when more than half of the bracket
is populated. The entry advances through an audited `bye` advancement; no event,
game, score or player statistic is fabricated. An incomplete first round is
explicitly typed as play-in. Later rounds depend on prior match winners. The
optional third-place match depends on semifinal losers.

Pre-play structural changes append a revision and archive the prior stages.
Earlier revisions, seeds, matches and decisions remain immutable. Reseeding is
rejected after any linked game starts.

## Scheduling and official results

Tournament management presents only already-authorized Calendar/Game Center
candidates whose sport and participating entry teams exactly match the resolved
bracket match. Calendar remains authoritative for date, time, timezone, venue,
resource conflicts, recurrence changes and cancellation. Minimum rest is explicit
per bracket: disabled with zero minutes, warn, or block. When disabled no rule is
invented; when enabled the configured interval is evaluated against canonical game
times. Existing Calendar supports multi-day and multi-venue scheduling.

Game Center remains authoritative for roster, operators, scoring, sport rules,
statistics, finalization and correction epochs. The tournament engine reads only
the current official final, winner side and finalization epoch. A tie without a
canonical winner cannot advance. The tournament engine never replays sport facts.

Repeated processing of the same final epoch is idempotent. A corrected final
before downstream play appends a reconciliation advancement and refreshes the
dependent slots. Once a downstream game has started, automatic participant
replacement fails closed and an elevated explicit ruling is required. Played
history is never erased. Rebuild derives the same current projection from seeds,
dependencies, advancement history and rulings.

The championship winner derives the champion. Runner-up derives from the final
loser. Third and fourth derive only when the optional third-place match has an
authoritative outcome. Boss does not invent remaining placements.

## Authorization and privacy

Phase 6D reuses `competition.view`, `competition.manage` and
`competition.policy_manage`; it adds no role or permission key. The Phase 6B
competition manager remains exact competition/edition scope and receives no fake
organization or team membership. Every mutation rechecks current authority after
its row lock, preventing an operation that was blocked during revocation from
continuing with stale authority.

Coaches and current guardians receive only safe team-level bracket facts through
the existing competition-view relationship rules. Household membership alone is
not authority. A bracket projection never exposes roster rows, athlete profiles,
guardian/household data, documents, communications or prior-team history.
Cross-organization entries share only safe competition/team results; they create
no foreign administration or correction authority. Anonymous execution is not
granted. The read contract is suitable for a future explicitly published fan
projection, but Phase 6D does not enable public publication.

## Notifications and communications

Calendar and Game Center keep their existing schedule, reschedule, cancellation
and final-result notifications. Phase 6D adds low-volume advancement, champion
and corrected-advancement events to the existing bounded notification processor.
Recipients and visibility are requalified through current tournament/team/
guardian/manager relationships. Safe payloads contain only a team and source
version. Tournament announcements reuse Phase 4A scoped communications; no
tournament chat system is added.

## UI and responsive behavior

`/app/tournaments` provides edition overview, explicit stages, accepted seed
snapshot, bracket progression, match status/details, standings or manual seeding,
canonical game linking, result processing, rulings, rebuild, champion and safe
placements. Unknown slots remain truthful dependency placeholders. Desktop and
tablet use bounded round columns. At 390px and 320px the layout becomes stacked
round and match cards with no page-level horizontal overflow.

## Future extensions

Double elimination, consolation, multi-flight and round-robin finals can add new
finite bracket types and dependency kinds while retaining stable match identity,
immutable revisions and official Game Center consumption. Auditable random draw
would require recorded inputs, actor, timestamp and deterministic evidence; it is
deferred. Future public registration links Phase 3B Registration to Competition
entries, and future fees use existing Charges/Fees. Awards, payments, commerce,
livestreaming, SMS and push providers are outside Phase 6D.

## Completion evidence

Phase 6D is complete. The canonical project has 73 migrations. Fresh validation
passes 15,429 SQL/bootstrap assertions, 195 races, typecheck, zero-warning lint,
420 application tests and production build. One controlled hosted tournament
verified manual seeds, a real bye without a fabricated game, Calendar/Game Center
linkage, official-result advancement, configured rest warning, explicit ruling,
champion projection, rebuild stability and all four required responsive widths.

Hosted standings-snapshot seeding and restricted coach/family/competition-manager
contexts were not fabricated without safe scoped fixtures; those cases retain
SQL/runtime evidence. The hosted upstream result correction occurred after an
explicit championship ruling had already completed the bracket, so Game Center
correction/refinalization is hosted verified while the distinct pre-start
reconciliation and downstream-start lock cases retain SQL/runtime evidence.
Cleanup ended all temporary authority, restored exact module configuration,
archived the controlled resources and preserved immutable history before the
fixed target. No future bracket format or Phase 6E work began.
