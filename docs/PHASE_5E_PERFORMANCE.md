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
