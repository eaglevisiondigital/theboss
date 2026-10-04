# Basketball engine: Phase 5B

Basketball extends the closed Phase 5A Game Center foundation. Calendar still
owns the scheduled event and occurrence; Game Center owns the one game identity,
roster snapshots, current operators, lifecycle, score, version, request receipts
and finalization epochs. The Basketball engine adds typed game state and accepted
play facts to that game. It does not create a parallel schedule, score ledger or
identity system. Actual validation, migration, deployment and hosted results are
recorded in the Phase 5B completion report.

## Records and ordering

`game_basketball_states` stores the configured regulation format, period lengths,
overtime length, lineup policy, current period and server-clock anchor. Configuration
is explicit: two halves or four quarters; bounded regulation/overtime durations;
lineup size from one through five; optional lineup enforcement. A game can adopt
this engine only before it starts, with a current roster revision, zero scores and
no prior manual-score operation. Existing manual-score history is never interpreted
as Basketball plays.

Every Basketball command enters the existing authenticated `boss_games_mutate`
dispatcher. It uses the same caller-bound receipt, expected game version,
transaction, operation sequence and `game_operations` row as core operations.
`game_basketball_events` is a typed, immutable extension linked one-to-one to that
operation. There is no second event counter or mutable statistical ledger. The
accepted operation updates the canonical core score from the active typed facts.

Commands lock the Calendar event, then game, then current actor authority and
sorted operator assignments. They recheck the live Auth identity, current role and
relationship, exact resource context, module state and operator expiry after locks.
A replay reauthorizes before returning the existing receipt and appends nothing.
Stale versions, removed authority and forged references fail closed.

## Plays, statistics and corrections

The finite play types are made/missed two-point shots, three-point shots and free
throws; offensive/defensive rebounds; assists; steals; blocks; turnovers; and personal
fouls. Player attribution refers to the sealed game roster revision. No new athlete
identity is created for an opponent. Permitted team-unattributed facts remain team
facts, including an external opponent whose athletes are not Boss records.

Current player and team projections derive points, rebounds, assists, steals,
blocks, turnovers, fouls and shooting makes/attempts from accepted plays. Offensive
and defensive rebounds sum to total rebounds; made three-pointers contribute to
field goals; points reconcile as `2 × FGM + 3PM + FTM`. Percentages are presentation
calculations, with zero attempts displayed without inventing accuracy. Team totals
also include unattributed facts. Period foul counts use the active accepted personal
fouls in each period.

An assist links to an active same-side made two- or three-point shot by a different
athlete. Only one accepted assist can attach to that scoring context. A dependent
assist must be reversed before its score is corrected or reversed. Corrections
append a replacement linked to the current leaf of the chain; reversals append a
referenced reversal. Neither overwrites history. Existing elevated `games.correct`
authority and a reason are required; a scorekeeper gains no correction capability
merely from operating the game.

## Periods, clock and lineups

Period start/end are explicit operations. Regulation periods precede bounded
overtime periods. A period must end before the next starts. Ending a period stops
the clock at zero. The server stores the settled remaining milliseconds and a
`clock_timestamp()` anchor while running. Reads derive the effective remaining
time from that anchor, clamped at zero; browsers never own canonical clock time.
Clock stop, controlled adjustment and each accepted play capture server-observed
game time. Pause, suspension, finalization or Calendar cancellation freezes a
running clock in the same core transition. No background timer writes are needed.

Lineup changes and substitutions use the current game roster, exact side,
configured size, unique slots and the current operator's authorized team. Optional
enforcement requires attributed players to be on court. When enforcement is on,
disabling the lineup feature also disables operation rather than bypassing the
policy. Lineup history is immutable. Playing minutes and plus/minus are deliberately
deferred; elapsed clock and lineup history are a foundation, not a verified minutes
or plus/minus product.

## Finalization and engine ownership

A configured Basketball game permanently reserves its core score and roster:
legacy manual score set/reverse and roster refresh are rejected even when Basketball
flags later turn off. Feature disablement cannot restore a second score authority.

Finalization requires the regulation boundary to be reached, the period ended,
clock stopped, current roster revision unchanged and derived score reconciled to
core. The same transaction creates the existing core finalization epoch plus
`game_basketball_finalizations` and normalized immutable
`game_basketball_final_stats`. The seal records the typed-history cutoff and finite
engine/period context. Replay creates no additional seal. Reopening requires
existing elevated core correction authority; later corrections and refinalization
produce another epoch. Prior score, roster and statistical seals stay immutable and
are marked historical in projection rather than silently replaced.

## Authorization and privacy

Existing `games.manage`, `games.operate`, `games.finalize` and `games.correct`
permissions remain potential capability. Exact organization/team scope, current
relationship, participating side, live feature state and resource context still
authorize each action. Ordinary entry, clock, period, lineup and substitution actions
require a current exact-game operator. No new statistician role or broad team
permission is introduced.

An operator may receive only minimal entry identities for its explicitly assigned
participating team; an independent exact-side `team.roster.view` permission is the
other permitted entry-roster path. Entry identities contain snapshot ID, side,
display name, jersey and active status. They contain no person/participant ID,
Attendance status, DOB, contact, guardian data or private absence reason. Opponent
private identities do not become visible merely because shared team totals can be
operated.

Family and ordinary private projections intersect player identities with the core
roster already authorized for that viewer. An operating staff viewer can additionally
use its authorized minimal entry identities. Play-by-play masks athlete names and
references outside that set. Family views contain no entry roster, lineup controls,
operator/audit authority or historical statistical epochs. Only elevated correction
contexts receive superseded play history. Public-only viewers receive the authorized
core summary and finite clock/period summary, without player boxes, lineups or
play-by-play. Anonymous raw APIs remain closed.

All Basketball tables have RLS enabled with no authenticated raw-table policy or
grant. Private helpers are not Data API endpoints. Mutations and reads pass through
the existing server-enforced Game Center RPC contract.

## Features, integration and bounds

Four independent default-off Sports booleans are added to the existing five:
`basketball_live_scoring`, `basketball_stats`, `basketball_play_by_play` and
`basketball_lineups`. Existing dated Sports activation and Game Center permissions
remain required. Configuration accepts only these nine finite boolean names,
preserves unrelated configuration and advances the existing monotonic module
version. A configured game keeps an engine-lock marker when flags turn off, with
unavailable operating capabilities.

Calendar and Family Hub reuse the existing authorized game links. Existing lifecycle
and operator notification hooks remain; individual plays do not create high-volume
score notifications or enable a new delivery provider. Scoreboard refresh uses
authorized server reads. No broad Realtime subscription, SMS, push provider or public
statistical feed is introduced.

Heavy box, play-by-play and epoch projections are detail-only. Play-by-play returns
at most 500 entries with an explicit truncation indication; epochs return at most
100; periods are bounded at 30. Tenant/game/sequence, roster, operator and epoch
indexes support exact-game paths. Season/career aggregation, leaderboards, another
sport engine, fan engagement and statistical awards remain outside Phase 5B.

## Client recovery after an unknown outcome

The selected game owns one in-memory Basketball intent controller shared by
quick entry and Basketball forms. It retains an immutable command, original
expected version and request ID after a lost or unrecognized response. Canonical
refresh and version-keyed form remounts preserve that intent; computed default
date ranges do not remount the game console. New Basketball changes remain closed
until **Retry unconfirmed change** resolves the original request. A confirmed next
play receives a new ID. Context navigation or a full browser reload creates a new
page context; no browser credential/session storage is read or written by this
mechanism. Server receipt replay still rechecks current resource authority.

Regression coverage includes committed-response loss followed by refresh, original
correction/substitution/clock/period/configuration retry, definitive denial cleanup
and distinct subsequent identical plays. This is a client transport correction;
the canonical game/event/stat architecture and security policy are unchanged.
