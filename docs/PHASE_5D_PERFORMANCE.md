# Phase 5D Football performance

## Final closure evidence

The final hosted native scenario completed creation, ordinary operations,
projections, four period transitions, first finalization, reopen/correction and
refinalization without `57014` or a repeatable database timeout. Responsive Game
Center rendering had no horizontal overflow at 768, 390 or 320 pixels. These are
bounded acceptance observations, not a hosted load test or formal SLA.

The post-fix focused 1,000-play disposable run kept every measured request below
the unchanged eight-second bound. Its largest observed requests were play-by-play
2,668.609 ms, detail 2,520.619 ms, period completion 2,736.923 ms and finalization
3,392.586 ms; maximum ordinary append was 168.096 ms. The complete historical
suite rerun provides the final regression evidence recorded in validation.

Disposable PostgreSQL 17 measurements are local runtime evidence, not a hosted
load test or production SLA. JIT matches the verified canonical setting. The
existing eight-second request/race bound is retained; no timeout was increased.

The preliminary growing-ledger append benchmark exposed repeated reconstruction
on ordinary new facts. It was interrupted with exit 130 after providing actionable
evidence; the runner stopped and removed the disposable cluster. No live database
or acceptance window was involved.

The narrow correction computes new typed facts/control state from the accepted
closed canonical field/score state. Corrections and reversals still prospectively
replay the full history; reads and immutable final seals still reconstruct the
accepted facts. The canonical transaction, sequence, receipt, authorization and
immutable facts remain the same. No separate score system was introduced.

The final complete frozen-source 1,000-play run measured:

| Operation | Maximum/complete request milliseconds |
| --- | ---: |
| Ordinary append | 37.080 |
| Full accepted-play replay | 770.966 |
| Field projection | 0.509 |
| Box projection | 823.356 |
| Drive projection | 792.128 |
| Play-by-play request | 2,437.830 |
| Game Center detail | 2,497.609 |
| Period completion controls | 3,084.898 |
| Finalization | 3,460.352 |

All measured calls stayed below eight seconds. Exact full zero-yard rush/downs
totals survived display limits of 500 plays and 100 drives. Finalization preserved
sixteen immutable player/team rows for the fourteen-athlete synthetic fixture.
The complete frozen-source historical run passed; hosted measurements remain
pending. The preceding focused run measured append 72.194ms, replay 959.244ms,
box 861.374ms, drives 797.880ms, PBP 2,607.829ms, detail 2,619.558ms,
period controls 2,890.560ms and finalization 3,424.284ms; these are retained as
earlier observations, not substituted for the final run.

The versioned sack/net-yardage and try-stat separation are supported by the
[official NFL statistician guide](https://www.nflgsis.com/gsis/documentation/stadiumguides/guide_for_statisticians.pdf).
Boss does not claim universal NFL/NCAA/NFHS conventions: recorded-only defensive
attribution, explicit full sacks, configurable kneels and overtime policy remain
documented bounded engine choices.

The single October 5 hosted window could not confirm native Football game
creation, even after its one idempotent retry. No game was created and there are
no hosted Football append/read/seal timings to report. The available evidence
does not establish whether transport, application or database runtime caused the
unconfirmed outcome. It is not classified as a measured performance defect or
covered by the disposable timings above. Recovery completed before the cleanup
target; no timeout, provider, infrastructure or security change was made as a
workaround. See [hosted acceptance](PHASE_5D_HOSTED_ACCEPTANCE.md).
