# Football engine

Phase 5D implementation is in progress. Live migration, deployment and acceptance
evidence will be recorded separately after execution. Earlier Basketball/Soccer
engines and Phase 5C closure history remain unchanged.

## Canonical boundary

Football commands require `sport_key=football` and use the existing Calendar
occurrence, game, roster snapshot, operator assignment, operation sequence,
caller-bound receipt and finalization epoch. Five closed tables hold Football
state, typed events, current lineups, finalization headers and stable player/team
stat rows. A configured engine owns the score and roster even when features are
disabled; no legacy score bypass is available. Wrong-sport commands fail closed.

## Format and state

Regulation has four bounded quarters and an authoritative server countdown.
Halftime is the boundary after quarter two. Overtime policy is explicit:
disabled, timed, or an operator-confirmed possession-format foundation with a
bounded number of periods. The engine does not impose an NFL/NCAA/NFHS winner or
possession rule. A separately configured play-clock duration is a foundation;
automated live play-clock and penalty enforcement are deferred.

Field position is a number from 0 to 100 measured from the possessing side's own
goal. Changing possession mirrors that coordinate. Physical primary-team
orientation is explicit. Down, distance, line to gain, goal-to-go and possession
are structured state. Ordinary play outcomes derive transitions; special-team
placement and accepted penalties require explicit bounded resulting state.
Touchdown, try and kickoff phases preserve the scoring sequence.

## Typed plays, drives and conventions

Rush, completed/incomplete pass, sack, kneel, spike, interception, fumble/recovery,
downs, kicks/returns, scoring and penalties have finite typed inputs. Whole-play
kick/return and fumble/recovery outcomes capture the original action once. Known
defensive attribution is entered explicitly; missing attribution remains unknown.
Drives retain side, starting/ending field and time, play count and result.

The versioned `football-v1` convention records a completed pass's yards once for
the team and equally for passer and receiver. A spike counts as a pass attempt.
Sack loss reduces team net passing yards and credits sacks taken; it contributes
no ordinary player pass/rush attempt or yardage. Kneels count as rushes only under
the explicit game policy; otherwise they have separate counts/yards. Conversion
attempts remain separate from ordinary scrimmage yardage and touchdown stats.

A primary tackler receives solo credit when no assistants are entered. With
bounded assistants, the primary and each assistant receive assisted credit;
the team receives one tackle outcome. Full-sack attribution is supported;
fractional shared sacks and quarterback-hit metrics are deferred. Targets exist
only when a receiver is captured. Accepted no-play penalties contribute no
ordinary play statistics. First downs require recorded line-to-gain/TD evidence
or an explicitly recorded accepted automatic first down.

Score derives from accepted facts: TD 6, FG 3, XP 1, conversion 2 and safety 2.
Kicking distance is captured independently. Return yards remain separate from
offensive yardage. Box scores use Passing, Rushing, Receiving, Defense, Kicking
and Returns sections, with reconciled team totals.

## Corrections and final epochs

Reversal/replacement facts preserve originals and origin order. Rebuilding active
facts validates later field/possession dependencies and rejects an incoherent
history. A final seal binds the canonical finalization, score, roster revision,
typed play cutoff, game/drive state, player/team totals and engine version.
Reopening preserves prior epochs; refinalization appends a new epoch. A reopened
game's old seal remains historical, without being represented as current final.

## Authorization and projections

Current identity, session, roles, exact game/team operator, features, occurrence,
version and roster side are checked server-side after serialization and before
writing. Raw tables have RLS and no direct client access. Retries share the
canonical receipt system and revalidate current authority. Private corrections,
operators and raw audit reasons never enter family/public projections. Player
identity references are masked independently in every secondary role.

Low-frequency notifications reuse Game Center start, delayed/suspended and final
lifecycle hooks. A finite `game.halftime` source records the quarter-two boundary
once through the same receipt, preference, visibility and bounded delivery
pipeline. Plays produce no per-play notifications. Public visibility remains
separately controlled; no external provider is added or activated.

## Persistent athlete history

Basketball/Soccer player seals already retain immutable person, participant,
roster, origin-team/organization, game, season and finalization provenance. The
history foundation projects those seals and Football seals without copying stats
or identities. A current verified guardian can read the child's safe history
after old membership ends. A new team receives neither automatic access nor
correction authority. See [athlete history](ATHLETE_HISTORY_ARCHITECTURE.md).

No full season/career aggregation, leaderboards, recruiting profiles, public
sharing, exports, additional sports or later modules are included.
