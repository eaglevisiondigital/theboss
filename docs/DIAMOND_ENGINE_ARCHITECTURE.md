# Boss Diamond engine — Phase 5F

Status: implementation and canonical migrations validated and deployed; hosted
acceptance/cleanup closure is recorded separately. Starting SHA
`8749f2df4bce553e7ca2a386532ef813655c4a86`. The design below remains the approved
shared-engine boundary.

## Shared engine and canonical ownership

Baseball and Fastpitch Softball use one `diamond-v1` reducer, command family and
storage model. `games.sport_key` retains `baseball` or `softball`; commands check
both engine and canonical sport. Calendar occurrence, Game Center game, roster
snapshot, operators, receipts, ordered operations, lifecycle, final epochs and
persistent person/participant identity remain the existing owners. No parallel
schedule, roster, score authority, operator role or athlete-history store exists.

## Facts and projection

Tenant/game-qualified Diamond state stores immutable versioned configuration and
a replayable bounded projection. Append-only Diamond facts reference canonical
Game Center operations. First-class plate appearances have an immutable start
identity, batting/defensive sides, batter/pitcher where known, starting state and
ordered pitch/play facts; correction replaces active evidence without erasing
the PA. Runner movements are ordered typed components of a play, preserving
origin, destination, identity, cause, pitcher responsibility and scoring order.

The projection includes inning/half, outs, score, batting/defensive sides,
batting-order cursor, current batter/pitcher/PA, optional derived count, three
bases, lineup revision, batting order/bench/defensive alignment and bounded
pitcher appearances with inherited-runner evidence. Anonymous game-local batting
slots/runner references permit Essential/Score Only opponent entry without
inventing a person or athlete. Known identities always reference the existing
same-game, same-revision, same-side roster snapshot.

Third out closes the half. Ordered scoring before a non-force third out may
count; a force third out or batter retired before first cancels runs for that
play. No run can be independently edited. Half transitions preserve completed
inning evidence; later facts must still replay after a correction. Extra innings
are explicit valid continuations. Game finality uses canonical lifecycle commands, including ordinary walkoffs
and a home team ahead after the last top half; eligibility never auto-finalizes.

## Finite versioned rule configuration

Configuration version `diamond-rules-v1` records sport, regulation innings,
batting-order size, continuous/traditional batting, re-entry, stealing policy,
dropped-third-strike policy, run cap and extra-inning runner policy. Pitch entry
availability comes from shared tracking snapshots, not a second stat setting.
Configuration cannot disable required score/outs/runner integrity.

Traditional and continuous orders, configurable youth sizes and ordinary
substitutions are bounded enforced policies. DH/DP-FLEX, courtesy-runner,
mercy/time-limit and pitch/rest-limit fields are explicit foundations/warnings;
they do not claim federation enforcement. Time or mercy warnings never silently
finalize. No MLB/NCAA/NFHS/association policy is a universal Boss rule. Additional
Softball variants require a reviewed finite rule extension, not duplicate engines.

## Plate appearances, pitches and scoring

Typed terminal results include single/double/triple/home run, walk/intentional
walk, HBP, strikeout, error, fielder's choice, sacrifice bunt/fly, interference,
configured dropped third strike and other out. A PA start fixes identities;
pitches derive balls/strikes in order. Fouls do not add a third strike except
configured foul bunts. Four balls/third strike require the corresponding terminal
result; no independently editable count exists. Scorebook Lite accepts valid PA
results without pitches. Pitch-by-Pitch uses the same PA/play path with declared
pitch coverage; Custom enables supported optional detail through shared profiles.

Runner movements consume an origin exactly once, prohibit duplicate occupied
bases/runner identities and preserve safe/out/scoring order. Walk/HBP forced
advances are checked. Standalone steal/caught stealing/pickoff/wild-pitch/passed-
ball/balk/indifference advances are typed facts, not free-text semantics. Pitcher
changes preserve inherited responsibility and append appearances at PA boundaries.
Mid-PA pitching changes with count-dependent batter responsibility are deferred;
the command rejects them rather than assigning responsibility by guesswork. Offensive,
defensive, pinch hitter/runner and pitcher substitutions retain lineup history.

## Statistics and coverage

Both sport-qualified catalogs use Phase 5E profiles, Quick Stats, per-side
snapshots, coverage intervals and seals from setup. Required PA/play state remains
common; optional pitches/fielding/attribution can be disabled independently.
Not tracked is not zero. Midappearance pitch enabling yields partial totals;
a server-owned observation-gap declaration also handles disable/re-enable within
a PA without fabricating missing pitches. Anonymous batting slots are initialized
at configuration so disabling optional lineup detail cannot block required scoring;
unknown participant attribution yields partial player statistics.

PA includes every terminal batter result. AB excludes walk, intentional walk,
HBP, sacrifice bunt/fly and interference. Hits are typed 1B/2B/3B/HR. Ordinary
hit/forced-walk RBI derives from scoring movement; ambiguous error/FC/double-play
attribution needs an authorized, reasoned correction. Pitching stores outs,
never decimal innings; display uses quotient/remainder. AVG/OBP/SLG/OPS, ERA,
WHIP and strike percentage are derived and null when denominator/coverage is
insufficient. ER is explicitly scorer-attributed with provenance; automatic
exhaustive official-scorer reconstruction is deferred. Runner origin/error/
pitcher responsibility remain available for a later reviewed implementation.

## Security, corrections and final epochs

All raw tables enable RLS at creation and deny direct client writes. Private
functions have empty search paths/explicit ACLs. Commands reuse current native
session, current exact-scope permissions/operators, authority locks, feature
checks after waits, optimistic game versions and caller-bound receipts. Optional
entry checks current side snapshot; profile management retains its separate
`games.manage` boundary. Initialized Diamond games never regain manual score
authority after a feature disable. Wrong sport/roster/tenant/expired or revoked
operator fails closed.

Corrections use append-only reversal/replacement and full prospective replay;
incoherent later facts reject the transaction. Finalization reconciles score,
state, lineup, PA/play facts, pitcher appearances and totals, sealing rule,
tracking/coverage and engine versions in the existing final epoch. Reopen keeps
old epochs immutable; refinalize adds another. Existing self/verified-guardian
history receives Baseball/Softball sources with original game/team/org identity.
New-team membership grants neither private old-team history nor correction.

## Console, practice and release evidence

The shared Live Stat Console receives a Diamond adapter: persistent score,
inning/half/outs, count when tracked, batter/pitcher, base diamond, profile-aware
Quick Actions and recent Undo/Correct. Lineup/substitution, Box Score, scorebook
and settings are secondary views. Action-first/player-first invoke the same
canonical command. Disabled optional attribution never prompts for input.
Practice stays synthetic in-memory with no official IDs/RPC/history or events.

Validation requires PostgreSQL 17 fresh historical and Diamond suites, independent
literal expected statistics, real two-connection command races, current generated
types, typecheck, zero-warning lint, app tests/build, and bounded-volume timing
without increasing statement timeout. Races cover pitch/PA/runner/substitution/
pitcher-change/correction/finalization, revocation/disable and profile boundaries.
Only after validation and deployment may one fixed controlled window begin, with
baseline/recovery prepared, fixed stop-new/cleanup/hard-expiry timestamps and
explicit removal of every temporary authority/configuration before deadline.
Only low-frequency existing start/suspend/final notification hooks are used.

No season/career aggregation, standings, public athlete stats, tournaments,
recruiting, livestream, financial module, commerce or messaging-provider work is
included. Phase 5F release/hosted status must be reported from actual evidence.
