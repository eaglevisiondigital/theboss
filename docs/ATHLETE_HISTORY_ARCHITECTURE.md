# Athlete history portability foundation — Phase 5D

This foundation reads an athlete's existing sealed Basketball, Soccer and
Football player statistics through the persistent Boss person and participant
identity. It adds a private projection and one caller-bound RPC; it creates no
second identity, roster, finalization, stat table or copied historical record.
It does not implement season/career aggregates, exports, recruiting, public
profiles or sharing grants.

## Audited source identity and provenance

The pre-migration audit traced each sport seal through
`game_*_final_stats.roster_id` to the immutable
`game_roster_snapshots` person/participant pair, originating team, organization,
game and roster revision. The sport header shares the canonical
`game_finalizations` ID, epoch and roster revision. Each sealed stat row has a
stable UUID. Foreign keys, fixed sport-engine versions and immutable-source
triggers preserve that association without depending on a current roster.

The safe canonical count-only audit found six Basketball and ten Soccer sealed
player rows across one game per sport. It found no missing identity/context
links, mismatched organization/game/revision/sport or missing seasons in those
existing rows. This is an audit of existing provenance, not a new hosted
acceptance result. Football uses the same canonical finalization and immutable
roster contract.

Game season and the athlete's originating team season are distinct provenance.
A game captures its primary team's season. An athlete on the opponent team may
have a different originating team season. Both nullable values are returned
separately. A source NULL stays NULL; the foundation invents no season or
personal data. Team season and game identity are protected against rewrite.
Organization/team/season display labels are current labels attached to their
immutable IDs, not claimed historical name snapshots.

## Read and authorization contract

`public.boss_athlete_history_read(p_query jsonb)` is a SECURITY INVOKER wrapper
around a private SECURITY DEFINER reader with an empty search path. Only
`authenticated` may execute the authorized reader/wrapper. The private
source-row helper, raw tables and original sport helpers remain inaccessible
to ordinary callers, anonymous users and service-role table access.

The native authenticated identity/session and active Boss account/person must
remain valid. A subject must be the caller or a current active, verified
guardian dependent according to the established `games_person_related`
relationship rule. Guardian confirmation, start time, end time and person
status are evaluated against current time. Household membership, organizational
membership, staff/coaching roles and platform administration give no substitute
authority over another athlete's history.

The reader locks relevant person and guardian rows, then checks live identity
and subject authorization after the lock wait and immediately before returning
data. This serializes relationship revocation with the read and prevents a lock
wait from extending natural guardian/session expiry. A later request after
revocation cannot use an earlier selected child or cursor to retain authority.
Current subject choices use the caller's guardian/self relationships directly;
they do not use the Attendance or current-team child list.

Athlete-owned historical access does not require the original organization,
team, unit, season, participant, module, feature flag or membership to remain
active. Those original records still provide provenance. Moving the same
person/participant to another team/organization leaves the source records
unchanged and does not give the new team's staff access to the old history.
The existing organization-context Game Center RPCs retain their current
membership/module and operational authorization rules.

## Bounded query and safe result

The finite query accepts `child_person_id`, `sport_key`, `season_id`,
`limit`, `before_sealed_at`, `before_finalization_id` and `before_stat_id`.
An explicit unauthorized subject returns PT403; malformed or unknown inputs
return PT422. The sport filter accepts Basketball, Soccer or Football. The
season filter selects the originating athlete-team season, not the game season.
The default limit is 20; the maximum is 50. All three cursor fields must be
present together. Ordering is descending sealed timestamp, finalization UUID
and stat UUID. The private projection returns at most limit + 1 rows per page.
A cursor confers no authority. Subject choices are bounded at 100 and always
include an explicitly selected authorized subject.

The `athlete-history-v1` result contains safe subject choices, the selected
person, bounded per-game player records, `has_more` and a cursor only when
another page exists. Each record identifies the persistent person/participant,
organization/team, both seasons, sport/engine, event/occurrence/game,
roster/revision, stable stat/finalization IDs, epoch, seal timestamp and source
event/operation sequence. It contains only that subject's finite whitelisted
sport totals. Soccer reliability NULLs and nullable goalkeeper clean-sheet
state remain intact; Football's absent longest made field goal remains NULL.
Signed Football yardage remains signed.

No teammate/opponent person details, roster display names, birth dates,
contacts, household IDs, operator identities, private audit/request data,
engine-state payloads, live play-by-play or team aggregate rows are returned.
The private union selects only player-stat rows bound to the selected person,
matching source organization/game, sport, epoch and roster revision.

All immutable sealed epochs remain readable. `latest_sealed` identifies the
game's most recent sealed epoch. `current_authoritative` additionally requires
the canonical game to be final. After reopening, the previous seal remains
history and is not presented as the current final result; after refinalization,
only the new epoch is current. No statistics are recomputed from mutable
current engine state.

## Future sharing boundary

History persistence is independent of future sharing. A later approved sharing
contract must explicitly identify the athlete, authorized consent giver,
recipient, finite historical resource range, expiry and revocation/audit
behavior. Team transfer, coaching role, knowledge of a stat/game UUID or public
game publication must not create such a grant. Phase 5D implements none of
these grants or public disclosures.

## Validation scope

The rollback-only history SQL acceptance suite exercises real Basketball,
Soccer and Football seals for the same persistent athlete, identity/provenance
preservation, transfer and archived-origin
access, exact-subject privacy, current guardian revocation/expiry, bounded
keyset pagination and reopened/refinalized authoritative state. Two independent
connection races verify that committed guardian revocation and natural expiry
deny a reader waiting on the guardian row lock. Football compatibility uses the
same finalization/player-stat contract and its prepared runtime fixture. Test
execution counts and hosted results belong in the Phase
5D validation/completion record; this architecture document does not claim
unexecuted tests passed.

The focused disposable PostgreSQL 17 run on 2026-10-04 applied all 44 prepared
migrations to a fresh private cluster, then passed 69 history SQL assertions
and both guardian concurrency races. The runner removed the ephemeral cluster.
This verifies the local history contract; the complete platform/database
regressions and hosted acceptance remain separate release requirements.

## Phase 5E Volleyball coverage

Volleyball final stats join the existing athlete-history projection through the
canonical finalization, original game/team/organization, roster revision and
persistent person/participant identity. No second history store exists.
Stat values carry tracked/not-tracked/partial coverage from the immutable epoch
seal; untracked values remain null. Guardian authority is evaluated independently
of current team membership. A new team relationship supplies no private prior-team
history or original-team correction authority. Older sport epochs stay intact
and receive only an honest legacy/unknown-coverage annotation.

October 5 controlled native evidence: after the original Falcons membership ended
and the same persistent Child1 moved to Wildcats, the existing verified guardian
relationship displayed both Volleyball sealed epochs plus preserved Basketball,
Soccer and Football records. Original provenance and legacy coverage warnings
remained visible. Child2 was denied. Restoring the guardian to its original
inactive state made Child1 history restricted despite the new Wildcats membership
and the still-active administrator assignment; history does not use an admin
override to substitute for the subject/guardian relationship. This is separate
from a pure Wildcats-only private-game correction test. No household/organization
membership or registration/document/payment/communication capability was broadened.


## Phase 6A prepared statistical intelligence

Phase 6A adds authorized season/career summaries alongside the existing immutable athlete history, without replacing it. Statistical season uses GAME season provenance, while existing history retains its original season fields. Persistent person/participant identity, origin team/organization, roster revision and epoch survive transfers. Roster is not GP: finite accepted participation/fact predicates confirm appearances; partial/unknown coverage remains visible. Guardians retain permitted historical summaries after team membership ends. A new team obtains no prior private history or correction authority.
