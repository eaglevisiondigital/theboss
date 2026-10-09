# Boss core database tests

## Phase 5D Football and athlete-history suites

`phase5d/fixture.sql` extends the reviewed Phase 5A Game Center fixture exactly
once, adding six synthetic athletes to each existing side for seven athletes
per team. Its `ff_create`, `ff_game`, `ff_roster`, `ff_play`, `ff_op`, and
`ff_finish` helpers support Football and athlete-history acceptance without
copying canonical identity, roster, schedule, or operator systems.

`phase5d_football.sql` records one deterministic four-quarter game and checks
literal values for every finite stat key across both teams and all fourteen
athletes. The independent score is 25–16 after receiver attribution correction;
an authorized reopen and made-to-missed XP replacement produces 24–16 and an
additional immutable epoch. The oracle documents Football-v1 sack, kneel,
spike, conversion, assisted-tackle, recovery, return-yard, and first-down
conventions. It never derives expected answers from production projection code.

`phase5d_formats.sql`, `phase5d_security.sql`, `phase5d_corrections.sql`, and
`phase5d_cross_sport.sql` cover bounded formats and overtime foundations,
remaining server clocks, normalized field/down state, lineups, closed raw
tables, exact operators, independently masked entry/family views, current
features, immutable correction chains, safe dependent replay, and both-direction
Football/Basketball/Soccer denial. Historical table inventories exclude only the
exact five new Football tables; historical feature inventories subtract only
the exact four Football flags and retain their prior counts and assertions.

`phase5d_athlete_history.sql` covers the bounded sealed-history provenance and
guardian access foundation independently of current old/new team membership.
It does not implement season or career aggregation or grant new-team sharing.
`phase5d_live_verification.sql` is a read-only structural verifier without
synthetic fixtures, Auth reads, or writes. Canonical use requires the separate
authorized infrastructure workflow.

`phase5d_performance.sql` measures every append, reporting the slowest individual
call as well as volume totals. It separately times field state, full accepted
play replay, the authorized PBP read, box, drives, Game Center detail, remaining
period controls, and finalization with 10, 100, and 1,000 zero-yard scrimmage
plays. Each measured call must complete below eight seconds; database timeouts
are not increased. Literal full totals must survive the 500-play and 100-drive
display limits. These disposable measurements do not establish hosted load
capacity or a production SLA.

`phase5d_football_concurrency.sh` uses the proven FIFO writer/observed-lock-wait
wrapper with a distinct Phase 5D namespace, preserving historical committed
fixtures. Its 25 prepared races include all nine requested collision families,
operator/role/membership revocation, natural operator/role/session deadlines, and
same-request replay for rush, pass, TD, interception, fumble, tackle, kick,
return, correction, substitution, and state change. Every participant retains
the fixed eight-second timeout and requires the private no-TCP runner socket.

```sh
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test5d
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test phase5d_football.sql
```

The focused options apply every canonical migration. `--test5d` includes the
Football race helper; a single `--test` omits races. Both retain the requirement
to complete the full historical run. Prepared sources and planned race counts
are not passing runtime evidence; actual validation belongs in the Phase 5D
completion record.

## Phase 5B Basketball suites

`phase5b_basketball.sql` checks a hand-computed synthetic two-sided scoring/stat
scenario, typed assists and their dependencies, team-only rebounds/turnovers,
clock corrections, substitutions, immutable correction evidence and two distinct
final-stat epochs. `phase5b_formats.sql` covers bounded halves/quarters/overtime,
pause/clock integration and per-period fouls. `phase5b_security.sql` checks current
exact-game operators, wrong sport/roster/side, role and relationship revocation,
disabled features, family masking, deny-by-default raw tables and idempotent
replay. All reuse the unchanged Phase 5A fixture with additional synthetic roster
depth in `phase5b/fixture.sql`; no DOB, real user or credential is used.

`phase5b_live_verification.sql` is compatible with separately authorized canonical
READ ONLY verification. It creates no fixture/schema objects, reads no Auth or
person data, and reports structural checks performed rather than a preset pass
count. Its transaction-local assertion count is discarded at rollback.

`phase5b_performance.sql` records bounded append and projection timings at 10,
100 and 1,000 accepted synthetic plays. Full totals must remain correct beyond
the 500-play display cap; Basketball plays must not create notification spam.
These local timings do not establish a hosted SLA or production capacity.

`phase5b_basketball_concurrency.sh` uses actual independent PostgreSQL connections,
observes a contender blocked on a lock before releasing the writer, and checks
the resulting ledger/stat/clock/lineup state. Its races cover baskets, duplicate
requests/free throws/fouls/substitutions/corrections, scoring versus substitution,
foul, period transition and finalization, competing substitutions/clock edits,
and operator/role/membership/feature revocation during a lock wait. Participants
retain the eight-second timeout and require the runner's private Unix socket.

```sh
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test5b
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test phase5b_basketball.sql
```

The focused option applies every migration and runs only the Basketball SQL
suites and real race helper. It does not replace the full historical run.
Execution counts, timings and hosted/canonical results belong in the completed
validation record; prepared test sources alone do not certify a PASS.

Run from the repository root with PostgreSQL 17 binaries installed:

```sh
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh
```

On Linux, set `PG_BINDIR` to the PostgreSQL 17 bin directory, for example
`/usr/lib/postgresql/17/bin`. If unset, the runner uses `pg_config --bindir`.
Run as an unprivileged operating-system user. No database URL, password,
Supabase key, Docker daemon or network service is required.

The runner initializes a fresh cluster under a private temporary directory,
binds only a Unix socket with permissions `0700`, rejects host connections,
applies every canonical migration in order and runs the Phase 2A/2B SQL tests.
It then runs the hierarchy concurrency helper against that same disposable
cluster. The helper coordinates two independent sessions and removes its local
synthetic hierarchy records after the checks.
It fails on the first SQL error, stops PostgreSQL and removes the cluster on
completion or interruption. If shutdown fails, it preserves the temporary
directory and reports failure instead of removing an active data directory.
Transactional fixtures roll back; the runner never connects to
the canonical hosted project. No fixtures belong in production migrations.

Repetitive assertion output is captured in the private temporary directory.
The runner displays the assertion count, category totals and fixture cleanup
result produced by SQL; SQL errors remain visible on stderr. It does not hard-code
a passing count. The historical Phase 2A fresh-cluster run passed 911 SQL assertions: 642
across categories A–P and 269 in `phase2a_live_verification.sql`. Its three
coordinated hierarchy checks also passed:
READ COMMITTED rejected the unsafe edit with `23514`; REPEATABLE READ and
SERIALIZABLE rejected it with `40001`. No cycle formed. The run verified
transactional fixture rollback and cluster removal; the concurrency helper also
verified removal of its committed local fixtures. Hosted and CI evidence is
recorded separately in
[CURRENT_BUILD_STATE.md](../../docs/CURRENT_BUILD_STATE.md).

The live-verification SQL creates no schema objects. Its synthetic DML fixtures,
Data API role assertions and request claims are transactional, and it verifies
fixture removal after rollback. After authorized canonical migration application,
it separately passed 269 assertions against the Boss project and verified zero
remaining synthetic fixtures. The local runner still never connects remotely;
remote execution belongs to the separately authorized canonical verification
workflow.

`local-bootstrap.sql` supplies the minimal managed Supabase surfaces used by
the migrations and fixtures: the `auth.users` UUID primary key, non-secret
fixture fields, `auth.uid()`/`auth.jwt()` request-claim lookup, `anon`/`authenticated` roles
without RLS bypass, and the explicitly privileged `service_role` role. It also
reproduces the previously audited broad public defaults so grant hardening is
tested against an unsafe starting ACL. Bootstrap execution uses a separate local
cluster administrator. Migration and fixture execution use a `postgres` role
with RLS bypass and role creation privileges, but without superuser access,
matching the relevant managed-project privilege boundary. Authorization
assertions switch to actual Data API roles.

This is a PostgreSQL constraint, privilege and RLS test environment. It does not
emulate hosted Auth, JWT signature verification, PostgREST routing, session
cookies, Storage or managed extensions. Canonical project migration verification,
advisors and separately documented hosted checks complement these tests.
Never apply the local bootstrap to a managed project.

## Phase 5A Game Center test suites

`phase5a_games.sql`, `phase5a_security.sql`, `phase5a_calendar.sql` and
`phase5a_notifications.sql` use only synthetic rollback-only fixtures from
`phase5a/fixture.sql`. They cover canonical singleton/recurring identity, finite
lifecycle transitions, roster history, exact operator authority, role/membership/
session revocation, correction history, finalization seals, Calendar changes,
safe family projections and the existing bounded notification pipeline.

`phase5a_games_concurrency.sh` coordinates actual blocked PostgreSQL sessions for
linkage/start replay, distinct-request starts, operator assignment collisions,
score sequences, finalization versus operation, reopen/refinalization, Calendar
cancellation, operator revocation/replay, concurrent transitions, Auth session/
verification changes during resource-lock waits, current role/membership/module
revocation and simultaneous correction reversal. The new race
participants retain an eight-second statement timeout. They use the disposable
runner socket and never accept a remote connection.

For focused iteration, run:

```sh
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test5a
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh --test phase5a_games.sql
```

The focused option applies every migration and runs the Phase 5A SQL suites plus
its concurrency helper. A selected SQL file omits races. Both options explicitly
retain the requirement for the full historical run. Historical inventory checks
exclude only the newly added Game Center tables and `games.*` keys; their prior
counts and behavioral assertions remain intact. Execution evidence and actual
assertion/race totals belong in the Phase 5A validation record after a completed
runtime run. Merely preparing these files does not certify a passing result.

Phase 5A includes finite configuration/version/merge/revocation coverage; exact
singleton and recurring Calendar identity; immutable snapshots, score corrections
and final seals; current scoped roles/relationships/operators; masked family and
Attendance projections; closed raw access; and low-volume notification hooks.
Its races confirm real lock waits before committing a winner. Natural deadline
cases let a fixed synthetic session expire while blocked on event, target-role
or operator-row locks without rewriting that session during the wait. Other
races cover configuration versus scoring, duplicate linkage/start, stale versions,
final/reopen and authority revocation. Each participant retains an eight-second
timeout. Safe diagnostics show primary SQLSTATE/message or source-file errors.

The historical trusted-owner audit truncation assertion uses `TRUNCATE ...
CASCADE` inside its expected-error subtransaction. This reaches the unchanged
immutability trigger despite new ledger foreign keys, still requiring `23514`;
raw client privilege-denial assertions remain unchanged.

The completed fresh-cluster run on October 4, 2026 passed all 33 migrations,
8,721 SQL/bootstrap assertions and 56 coordinated races: 522 Phase 5A assertions
(including its 183-assertion read-only verifier), 22 Phase 5A races and 34
historical races. Exit was zero and the private cluster was removed. This is
local/runtime evidence; canonical and hosted outcomes are recorded separately in
the Phase 5A validation and acceptance documents. An independent private control
suite also passed 17 recovery assertions using actual connector-compatible SQL
and synthetic copies of the reviewed anchors; its fixtures/controls remain
outside this public repository.

## Phase 2B operational coverage

The final fresh-cluster run passed 1,776 SQL assertions: the unchanged 642 Phase 2A
assertions and 269 Phase 2A live-verifier assertions, 314 Phase 2B live-verifier
assertions, 523 Phase 2B operation/read assertions, and 28 actual bootstrap-source
assertions. Categories A–R cover authorization, exact scope, isolation, guardian
separation, direct-write denial, audit, rollback, forged resource IDs, revoked
sessions and retry reauthorization. Read tests include 2,000 unrelated canonical
people, guardian deduplication, inactive dependents and contextual/global search.

After transactional SQL tests, `phase2b_bootstrap.sh` executes the real trusted
bootstrap source with isolated identities; it does not maintain a test copy of
the procedure. `phase2b_mutation_concurrency.sh` coordinates two RPC writers at
READ COMMITTED and REPEATABLE READ. Exactly one succeeds; the other receives a
safe conflict, and one membership/audit/receipt remains. These two checks and the
three original hierarchy checks pass. All fixtures and the entire private cluster
are removed; append-only audit guards are never disabled.

`phase2b_live_verification.sql` uses DML-only transactional synthetic fixtures and
actual Data API database roles. It completed on the canonical project after all
three new migrations; seven prefix-scoped cleanup counts were zero. The MCP
response contains its final cleanup row rather than the preceding assertion-count
row, so evidence also retains the matching 314-assertion local runtime result.
This does not substitute for signed-JWT/browser acceptance or production load tests.

`auth.uid()` semantics and relevant Auth columns/role attributes were verified
read-only against the canonical project before implementation. Official references:

- [Supabase database testing](https://supabase.com/docs/guides/local-development/testing/overview)
- [Auth uid claim lookup](https://github.com/supabase/auth/blob/master/migrations/20211202183645_update_auth_uid.up.sql)
- [Supabase database roles](https://supabase.com/docs/guides/database/postgres/roles)

Canonical migration files were created with the checksum-verified official
Supabase CLI `2.118.0` using `supabase migration new <name>`.
The MCP migration API assigned server-side versions during canonical application.
The uncommitted CLI-created files were renamed to those observed versions so
repository and live migration history agree. SQL bodies remained byte-identical;
no remote history repair or duplicate migration was used.

| Applied version | Migration name |
| --- | --- |
| `20260930212353` | `phase2a_grant_hardening` |
| `20260930212410` | `phase2a_identity_organizations` |
| `20260930212417` | `phase2a_relationships_access_governance` |
| `20260930212421` | `phase2a_integrity` |
| `20260930212426` | `phase2a_authorization_rls` |
| `20260930212430` | `phase2a_catalog_seeds` |
| `20261001134826` | `phase2b_operational_mutations` |
| `20261001134845` | `phase2b_admin_read_projection` |
| `20261001140101` | `phase2b_scoped_people_projection` |

The CLI is not a runtime dependency and no CLI access token is required to
create migration files or run these local SQL tests.
