# Phase 5F bounded performance

Fresh disposable PostgreSQL 17, synthetic nine-inning games. Each completed
game has 109 terminal PAs and final score 28–27. The tracked game has 436 typed
pitches; Lite has no pitch facts. Complete detail includes replay/state,
box-score totals, profiles/coverage, appearances and bounded play feed.

| Path | Calls | p50 ms | p95 ms | max ms |
|---|---:|---:|---:|---:|
| Tracked complete detail | 5 | 586.73 | 597.91 | 599.97 |
| Lite complete detail | 5 | 318.14 | 319.87 | 320.07 |
| Pitch append | 436 | 16.29 | 19.02 | 22.94 |
| Tracked PA/play | 109 | 16.47 | 19.27 | 33.22 |
| Lite PA/play | 109 | 16.17 | 17.61 | 22.54 |
| Tracked correction | 1 | 103.83 | 103.83 | 103.83 |
| Lite correction | 1 | 60.72 | 60.72 | 60.72 |
| Tracked finalization | 1 | 590.21 | 590.21 | 590.21 |
| Lite finalization | 1 | 304.94 | 304.94 | 304.94 |

These are local SQL/RUNTIME timings, not production HTTP latency. The three
performance assertions passed. Complete reads and mutations remain below the
3-second acceptance budget. No database statement timeout was increased.
Composite indexes cover the new tenant/game/PA foreign keys. Full historical
performance and canonical advisor gates remain separately recorded.
