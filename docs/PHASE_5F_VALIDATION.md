# Phase 5F validation

Status: INCOMPLETE; implementation, five canonical migrations, deployment and Baseball hosted validation verified; one controlled window explicitly cleaned and closed. Remaining hosted authorization gates were not completed.
Starting SHA `8749f2df4bce553e7ca2a386532ef813655c4a86`.

Fresh disposable PostgreSQL 17 runs use a private Unix socket, synthetic fixtures
and automatic cluster removal. No production data or credentials are used.

| Diamond suite | Assertions |
|---|---:|
| Commands, immutable seals, transfer/history privacy and runner-read regressions | 19 |
| Coverage and corrections | 10 |
| Structural/ACL verification | 49 |
| Realistic bounded performance | 3 |
| Pure reducer equivalents | 14 |
| Versioned rule profiles | 13 |
| Scope, wrong sport, receipts, protected tables | 22 |
| Total | 130 |

15 genuine coordinated two-connection races passed: simultaneous pitches,
pitch/PA, simultaneous PA, PA/runner, third out/half transition, play/final,
final/late play, pitcher/new pitch, substitution, correction/play, duplicate
receipt, profile/pitch, operator revocation, operator expiry, feature disable.
Actual lock waits synchronize participants; expiry and post-wait authorization
are tested. The full historical run passed 13,430 SQL/bootstrap assertions and 153 genuine races.
Totals are summed from the final per-suite assertion tables, including category
rows; new closed tables also expand earlier whole-schema privilege checks. Historical subset inventories
exclude the five new closed tables and eight new sport flags; former unsupported
Baseball fixtures now use unsupported Tennis. No earlier migration body changed.

Typecheck, zero-warning lint, 372/372 application tests and production build
passed with synthetic public build-format values. Canonical types regenerated from the validated 57-migration schema; final
application rerun uses those types. Actual local rendered 1280/768/390/320 console
widths equal page scroll widths; Quick Actions are at least 64px tall. This is
LOCAL evidence, not hosted viewport proof.

Four prepared migrations and one narrow hosted-defect repair applied to canonical Boss Supabase. Live read-only structural
verification passed 49 checks; history has 57 entries. Filenames align to canonical
application timestamps with contents unchanged. Security advisors: intentional
closed RLS INFO 96 and existing leaked-password-protection WARN 1. Performance:
unused-index INFO 177, existing Auth absolute-allocation INFO 1; no new missing
FK index finding. No Auth setting or timeout changed. At this earlier pre-hosted checkpoint, deployment, temporary
acceptance authority and hosted Diamond results were pending. Subsequent actual results follow. The fixed hosted plan and
independent literal score/stat oracle are prepared separately.


## October 5 hosted repair and release verification

Implementation `bef48600f0da29a9989f8db2f940d63211d33d39` published in Boss
production deploy `6ac3d2bacea46a00083aa7f3`. Hosted walk/steal facts revealed an
ambiguous SQL alias in `diamond_totals` only when a runner advance was present.
The fifth migration `20261005165247_phase5f_runner_projection_fix.sql` replaces
that alias without changing interfaces, permissions, engine rules or timeout.
Stolen-base and wild-pitch full-read regressions passed; focused validation now
has 130 assertions and 15 races. Repair commit
`cce4b41c52c9dca056e83034301683764a4aa974` passed full CI application and database
jobs in run 37344840869. The duplicate superseded run was canceled by concurrency
policy; the authoritative completed run is SUCCESS.

The final full-history CI count is 13,430, excluding the intermediate duplicate
731-assertion Phase 3B pre-cleanup summary. It includes final per-suite category
counts and the 28 bootstrap assertions. There are 153 genuine races overall.
Typecheck, zero-warning lint, 372 tests and build also passed locally after the
repair. Fresh canonical type generation is byte-identical to the committed
230,601-byte type file (normalized final newline).

Post-repair advisors: 96 intentional closed-RLS INFO findings; one existing Auth
leaked-password-protection WARN; 173 unused-index INFO findings and one existing
Auth absolute-connection-allocation INFO. Index counts may vary with observed
usage. No Auth configuration, privilege, security policy or timeout was weakened.
The live migration history contains all five Phase 5F entries.

Baseball native HTTP completed the independent 6–0 two-inning oracle, 20 terminal
PAs, 13 complete primary and 11 partial opponent pitches, substitutions/inherited
runners, fielding error, RBI 6→5→6 correction, final/reopen/refinalize and a stale
signed mutation denial after exact operator removal. Softball native two-team
Calendar/canonical creation passed, with one creation receipt; scoring remains unverified because
specific temporary operator authorization was not received. Portability
relationships were never activated; their direct authorization was not received.

A 320px hosted override still measured 1280px. Local rendered evidence is retained
separately; no hosted mobile claim is made. Native administrator-alone Child1 and
unrelated Child2 history denial passed. No controlled notification source was
queued at the read-only 17:14 UTC checkpoint; lifecycle hooks remain SQL verified.
See the hosted addendum for exact immutable epochs and cleanup evidence.

## Final controlled-window stop

Explicit restoration completed 17:18:23.605980–17:18:23.728901 UTC, before the
17:54:38.685596 cleanup target and 18:09:38.685596 hard expiry. All six selected
baselines equal; original administrator native Home valid; zero temporary
operators/memberships/profiles/pending controlled work; both games/events archived
and unpublished. Recovery retired after verification. The hosted addendum records
exact canonical audit/check timestamps. No extra window or later phase started.
Required Softball scoring and guardian/team-transfer/privacy hosted gates remain
unverified, and Phase 5F remains INCOMPLETE.

## Remaining hosted closure and minimum validation

The separately scoped resumption completed all remaining hosted gates and
explicitly restored baseline at 18:21:03 UTC, before fixed 19:30/19:45 deadlines.
Phase 5F is COMPLETE; the earlier INCOMPLETE checkpoint is historical.
Typecheck, zero-warning lint and 372/372 application tests passed again.
Read-only canonical checks verify migration history still 57, one Softball epoch,
three unchanged Baseball epochs and identical persistent/provenance rows after
transfer. No code/schema change; full SQL/concurrency/performance/build suites
were not rerun. Prior starting-SHA full CI remains PASS; documentation-only
closure uses `[skip ci]` to avoid the prohibited unchanged massive suites. This
is not a new final-head CI PASS claim. Exact evidence is in the
[remaining acceptance record](PHASE_5F_REMAINING_ACCEPTANCE.md).
