# Bounded Phase 4B read profiling

This optional diagnostic harness creates a private PostgreSQL 17 cluster with no
TCP listener, applies migrations, seeds synthetic data, measures reads and removes
the cluster. It never connects to canonical Supabase. It requires PostgreSQL 17,
Python 3 and an unprivileged operating-system user. Set `PG_BINDIR` if `pg_config`
does not locate PostgreSQL 17.

Run from the repository root:

```sh
bash supabase/tests/performance/run.sh --migration-limit 29 --evidence-dir /private/tmp/boss-perf-before
bash supabase/tests/performance/run.sh --evidence-dir /private/tmp/boss-perf-after
```

Evidence directories must be new and outside Git. Run baseline and candidate
sequentially, with unrelated heavy validation stopped. Both use the same
8-second statement timeout, JIT disabled and function tracking enabled. The
baseline records expected `57014` cancellations; candidate mode requires every
read to succeed. A bounded client watchdog also treats transport/harness failures
as failures. JSON evidence contains timings, SQLSTATE, scalar cardinalities and
function statistics; RPC payloads and synthetic claims are not printed. The
client disables startup profiles and points its password file at `/dev/null`.

The default fixture contains three organizations, twelve units/teams, 180
participants, seventeen synthetic Auth identities, twenty-four events (half
recurring), sixty occurrences and 180 attendance sources. One guardian has two
explicitly authorized children on two exact teams. Eight relevant events represent
four weekly four-occurrence series and four single events: twenty appointments
and sixty guardian notification rows, plus 180 other-recipient rows. One canceled
exception tests source suppression. Twenty-four existing responses vary pending
and reconfirmation state. No real person, password, token, session credential or
external delivery is used. Seeded delivery rows represent already-processed
sources and do not establish delivery acceptance.

Three individual samples cover Notifications summary, filtered inbox, Attendance
family and Calendar personal. Three parallel batches each reproduce the seven
layout projections plus the Notifications page read. The shell's actual default
windows are used: Calendar UTC midnight/14 days and Attendance/Volunteers now/30
days. Registration, Communications and Volunteers have empty module resources;
those requests measure shell completion and contention, not module-volume load.
Use `--owned-events 1|2|4|8`, `--repetitions 1..3` and `--batches 0..3` for bounded
follow-up measurements. The fixture's older anchor-relative helper query is not
the application-default query used by this harness.

Timings are investigation evidence, not a production SLA or wall-clock-only CI
assertion. The ordinary database runner includes `phase4b_performance.sql`, with
rollback assertions for context/configuration/feature equivalence, occurrence
bounds, helper-call counts and private privileges. Function counters persist
across transactions in one backend, so those assertions compare deltas.
