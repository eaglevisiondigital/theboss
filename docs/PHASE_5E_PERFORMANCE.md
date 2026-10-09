# Phase 5E performance

Disposable PostgreSQL 17, JIT off to match the verified Boss baseline. The
synthetic game had 80 canonical rallies plus set initialization, full primary
tracking, score-only opposing tracking and the complete protected detail read.

| Operation | Requests | p50 ms | p95 ms | Maximum ms |
|---|---:|---:|---:|---:|
| Canonical rally append | 80 | 12.50 | 14.37 | 26.62 |
| Full game detail | 12 | 51.59 | 58.30 | 63.43 |

Both p95 assertions passed the fixed three-second regression bound. These are
local timings, not a production scale/load benchmark or hosted latency claim.

Profile management choices are limited to the selected organization and explicitly
filtered program/team/current team-season. Configuration default edits take
per-sport/per-tenant advisory locks; ordinary scoring uses immutable game snapshots
and exact game locks. Canonical game projections cap plays at 500 and epoch
review at 100. Foreign-key context indexes and game/origin-sequence indexes support
protected joins. Shared catalogs are finite. History keeps existing bounded keyset
pagination. No aggregation, standings, leaderboard or public athlete query was added.

Hosted native creation, 15-rally match, both seals and complete history projections
completed against the deployed implementation. One tool response was delayed;
there is no instrumented hosted latency distribution or production scale claim.
Native 1280px reload/navigation remained stable. Requested smaller hosted viewport
overrides left actual width at 1280; local responsive measurements above are not
promoted to hosted evidence. No endpoint or security workaround was introduced.
