# Soccer engine

## Current acceptance and closure status — 2026-10-04

**Phase 5C Soccer Live Scoring + Game Statistics: COMPLETE.** Main Boss Chat
accepted the canonical Soccer implementation and reviewed the hosted acceptance
and cleanup-incident reconstruction. This is a documentation-only closure; the
architecture and deployed implementation are unchanged. The original design
checkpoint below is preserved verbatim, including its historical validation
status.

The retained incident classification is
`EXPLICIT RESTORATION DEADLINE MISSED; NO USABLE TEMPORARY PHASE 5C AUTHORITY IDENTIFIED AFTER HARD EXPIRY.`
Hard expiry was `2026-10-04 18:24:28.466723 UTC`; first selected-authority
restoration has canonical audit timestamp `2026-10-04 21:04:29.585080 UTC`, and
full module-baseline restoration has timestamp `2026-10-04 21:05:24.046832 UTC`.
Maximum explicit-restoration delay was **2:40:55.580109**. The deadline breach is
accepted and permanently retained as an operational/process incident. Audit
timestamps are not asserted to be exact commit instants.

The bounded operator, Sports/Calendar and athlete windows were expired (A) at
hard expiry; scorer authority and the temporary staff relationship had already
ended or been restored. Changed Game Center/Soccer flags were configuration
residue granting no independent authority (C); the unpublished controlled
event/game was resource residue (D). No usable temporary post-expiry authority
(B) was identified. Guardian/household authority was never activated and public
Game Center remained disabled. There were no new Soccer/scoring facts,
finalizations or signed mutation receipts during the reviewed interval; the one
Game Center Calendar sync was recovery-only and preserved the 2–0 score. Related
notification sources/jobs/notifications/deliveries were zero. Available audits
cannot prove absence of all GET/read or session activity.

The accepted family evidence label remains
`SOCCER FAMILY/GUARDIAN PRIVACY: SQL/RUNTIME VERIFIED; PHASE 5C POSITIVE HOSTED GUARDIAN STAGE NOT EXECUTED.`
Inherited [Phase 5A Game Center](PHASE_5A_ACCEPTANCE_ADDENDUM.md) and
[Phase 5B Basketball family/Child1-only](PHASE_5B_HOSTED_ACCEPTANCE.md) hosted
evidence and shared current-authority projections support the design; they do
not become Soccer hosted proof. Soccer-specific SQL/runtime privacy/isolation
coverage remains distinct. Main Boss accepted this evidence limitation; neither
it nor the cleanup process incident is a known Phase 5C production defect.

Forged signed requests remain unavailable through approved hosted tooling;
positive individual keeper clean sheets, saved penalties and alternative
substitution policies remain SQL/runtime only. Exhaustive entry controls were
not exercised at every responsive viewport, and public Soccer publication was
not enabled. No new acceptance window or later sport/module is authorized.

Current recovery evidence records zero residual temporary authority, valid
original administrator access, exact baseline equality and archived/unpublished
controlled resources. Prior canonical migration/type and 304/304 application
test results remain the validation basis; final documentation SHA/CI are recorded
in the final handoff. See the [completion report](PHASE_5C_COMPLETION_REPORT.md),
[acceptance and incident record](PHASE_5C_HOSTED_ACCEPTANCE.md) and
[Main Boss decision](DECISIONS.md).

## Historical architecture checkpoint — preserved verbatim

Phase 5C extends the canonical Calendar occurrence, game, snapshot roster,
operator assignments, request receipts, sequence and finalization epochs. The
engine runs only for the explicit canonical `games.sport_key = 'soccer'`.
Implementation is undergoing validation; migration, hosted and cleanup results
are recorded separately. No team/program label supplies sport identity.

## State and match time

Five tenant-qualified tables contain bounded Soccer state, typed events, current
lineups, finalization metadata and normalized sealed stats. Accepted typed facts
bind one-to-one to canonical game operations. Participation snapshots live in
the typed event history rather than a copied Basketball history table. Immutable
event and seal rows reject update, delete and truncate. Stats have a generated
UUID primary key and unique epoch/side/subject from their first migration.

Configuration permits two halves or four youth quarters, 60..5,400-second
regulation segments, zero or two 60..1,800-second extra-time segments, one to
eleven players per side, explicit lineup enforcement, re-entry policy and an
optional zero-to-100 substitution limit. Null means unlimited substitutions.
Initial configuration requires an unstarted zero-score snapshot with no prior
manual-score history. Competition-wide knockout rules are not inferred.

The database reconstructs elapsed time from a stored ascending segment clock
and server anchor. Start/stop/correction and segment transitions append evidence.
Each segment has explicitly declared zero-to-1,800-second added time; shortening
below elapsed time fails. Segment completion requires its full declared duration.
Halftime is the completed regulation segment before the next segment begins.
Once extra time begins, both configured extra segments must complete before
finalization. A completed regulation or extra-time match may end in a draw.

Events retain segment elapsed milliseconds, nominal displayed match time and
actual participation time. Nominal time offsets use configured segment lengths;
actual participation includes completed added time. Forward clock correction
preserves known intervals. Backward correction or ambiguous participation makes
precise minutes unavailable. Browser interpolation affects display only.

## One outcome per shot

| Accepted outcome | SH | SOG | Attacking goal | Defending save |
| --- | ---: | ---: | ---: | ---: |
| Normal goal or match-play penalty goal | 1 | 1 | 1 | 0 |
| Saved shot or saved match-play penalty | 1 | 1 | 0 | 1 |
| Off-target, blocked shot or missed penalty | 1 | 0 | 0 | 0 |
| Own goal | 0 | 0 | 0 | 0 |

An own goal identifies the conceding side, optionally its known athlete, and
adds one to the opposite match score. It never credits a normal attacking player
goal or invented shot. Team goals equal match score, including opponent own
goals, so team goals need not be less than team SOG. A separate own-goal counter
retains attribution. Legitimate unattributed team facts remain available for
external opponents or unknown athletes.

A saved shot is the canonical opponent shot; no independent save event doubles
it. An attributed save must use the defending designated eligible goalkeeper.
Team saves need no invented opponent identity. A linked assist identifies one
accepted normal/penalty goal, the same attacking side and a valid assisting
athlete. It cannot equal a known scorer, attach to an own goal or duplicate the
initial one-assist contract. Resolve an active assist before correcting its goal.

## Discipline and participation

Yellow adds one YC. A known second yellow requires the preceding active yellow
and adds one YC plus one RC. Direct red adds one RC. An on-field dismissal ends
participation and keeps a blocked slot; another player cannot replace that slot.
A bench dismissal does not reduce the active lineup. Dismissed players cannot
return. Unknown team cards never invent an individual dismissal; an unknown red
makes precise participation unavailable. Reversing a card does not silently put
a player back on the field.

Initial lineup identity is sealed before the first segment. Substitution requires
an active outgoing player, eligible same-side incoming snapshot athlete, valid
resulting lineup, configured re-entry/count policy and no dismissal. Keeper
designation is at most one per side and belongs to the active lineup. Keeper
replacement retains interval history; missing designation never becomes guessed
keeper attribution.

Complete enforced initial lineups and monotonic authoritative history produce
per-player minutes from interval intersections with match time. Dismissal and
substitution end the correct intervals. An unused eligible bench player can have
an authoritative zero; incomplete history returns null rather than a guessed zero.
Keeper goals allowed derive from accepted scoring facts within reliable keeper
intervals, including own goals conceded during that interval. Missing/ambiguous
basis returns null. Team clean sheet uses final match score. Individual clean
sheet requires proven whole-match keeper participation and zero conceded goals;
partial keeper coverage returns null. A whole-match keeper who conceded receives
false, which differs from an unavailable result.

## Corrections and sealed epochs

Correction appends a replacement; reversal appends evidence identifying the
original. Original event time and sequence context remain reconstructable.
Named historic keeper attribution must match its original interval. Safe current
leaf keeper/substitution corrections may reconstruct current state; dependent
later play makes unsafe reconstruction fail closed. Ambiguous changed
participation invalidates precision instead of silently rewriting minutes.

Finalization seals canonical score, event cutoff, roster revision, bounded match
format, engine version, participation basis and player/team totals under the
existing core epoch. Reopen requires elevated correction authority and a reason.
Refinalization appends another epoch without modifying any preceding seal.
Future season/career products may resolve the latest authoritative epoch using
explicit supersession and engine-version rules; no aggregate is implemented.

## Authorization and interface

Existing game administrator and scorekeeper functions suffice; no new broad role
or permission mapping is added. Every command and retry checks the current live
caller, exact game/operator, current role/relationship, feature state, resource,
snapshot side and final status after canonical lock waits. First execution checks
optimistic version; replay reauthorizes and returns the exact original caller-bound
receipt rather than requiring that old version to remain current.
Private athlete references require actual side authority. A Falcons scorer may
record opponent unattributed shared-match facts without receiving Wildcats
private roster access. Corrections, reopening and sealing retain elevated gates.

Four independent default-off controls are `soccer_live_scoring`, `soccer_stats`,
`soccer_play_by_play` and `soccer_lineups`; core Game Center/operations and current
module/Calendar context still apply. Soccer does not activate Basketball or public
views. Engine ownership permanently closes legacy manual score/reversal and roster
replacement, including after feature disable. Cross-engine initialization fails.

Private `entry_plays` supplies at most 500 active correction/assist contexts to
currently authorized operators or correctors with independently authorized roster
scope. It does not depend on visible play-by-play being enabled. Identity fields
remain masked by current exact-side authority; family, ordinary readers and
disabled write contexts receive no entries. Visible recent plays and the timeline
continue to follow the independent play-by-play flag.

The existing Game Center gains fast Soccer goal/shot/save/assist/card controls,
segments, clock, added time, lineup/keeper/substitution, recent correction and
null-aware live/sealed stat cards. Shared intent recovery retains the original
request ID, payload and version during an unknown outcome across refresh, and
blocks either engine from issuing another unresolved command. Family projections
include only authorized child identity and safe match/stat context; no opponent
private identities, operator controls, correction/audit history, guardian data or
private Attendance reasons. Public projection remains a safe future summary;
anonymous access is closed and public Game Center is not automatically enabled.

Existing low-volume lifecycle notifications remain the integration. There is no
per-goal/card/shot notification spam, broad subscription or provider activation.
Current authenticated refresh/reload recovers state from the server. A future
near-live fan channel must use authorized minimal revision summaries, bounded
refresh, publication checks and tenant/visibility reauthorization before delivery.

## Deferred shootout contract

Shootout operation is deliberately deferred under the approved Phase 5C boundary.
Future implementation must bind the same game to a separate competition-policy
snapshot, distinct shootout epoch and ordered attempts with round, side, eligible
taker/keeper references where known, made/missed/saved outcome and reversal links.
Validate explicitly reviewed configurable attempt order, bounded sudden-death
pairs, player reuse,
early mathematical completion and winner according to explicit reviewed rules.
Use the existing operator, locks, optimistic versions, receipts and audits; do not
create another match identity. Shootout totals/winner are separate result fields.
They never enter normal goals, SH/SOG/saves, keeper GA, minutes or clean sheets.
Seal them alongside, but distinct from, regulation/extra-time stats. Reopening
must preserve prior epochs and resolve match corrections that invalidate the
shootout prerequisite. No shootout command, permissive fallback or UI is active.

Football, Volleyball, Baseball/Softball, season/career totals, records,
leaderboards, standings, brackets, livestream, payments, commerce and providers
are outside this phase. Validation and hosted evidence must be labeled separately;
SQL coverage does not establish an unexecuted hosted signed request.
