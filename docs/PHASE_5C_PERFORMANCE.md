# Phase 5C performance

Disposable PostgreSQL **17.11** measurements on October 4, 2026 against the final
frozen Soccer bodies. These are bounded functional measurements, not a production
SLA or a multi-tenant load claim. No database statement timeout was increased.

| Accepted shot/goal facts | Incremental append batch ms | Append ms/event | Box projection ms | Authorized detail + play-by-play ms | Returned plays |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 158.168 | 15.817 | 2.133 | 67.069 | 11 |
| 100 | 1,400.115 | 15.557 | 3.715 | 66.844 | 101 |
| 1,000 | 16,441.157 | 18.268 | 21.534 | 98.312 | 500 |

Each batch appends only the additional facts since the preceding measurement;
the per-event denominator matches that incremental count. The detail measurement
includes the current authorized match, bounded play-by-play, private operation
context, roster, operators and history. It does not execute a season/career scan.
Both play-by-play and private assist/correction context cap at 500 entries;
canonical stat derivation still reconciles every accepted event.

At 1,000 accepted goals, finalization took **91.696 ms** and sealed **26** stat
rows for the synthetic roster/team fixture. Independent assertions verify all
1,000 goals/shots/SOG, complete ordered canonical operations, bounded contexts,
and no high-frequency Soccer notification fanout.

Soccer stores typed facts and participation on the existing game identity. Current
server refresh projects that game's accepted events; future season aggregation
must consume latest authoritative sealed epochs asynchronously. There is no
broad subscription, per-play provider delivery, production load change or new
timeout policy. Prior Phase 4B timeout/remediation and historical proxy-exposure
records remain preserved in their original documentation.

Canonical advisors and actual hosted responsiveness will be recorded separately
after migration/deployment and controlled acceptance.
