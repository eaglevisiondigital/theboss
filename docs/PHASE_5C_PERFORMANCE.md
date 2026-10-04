# Phase 5C performance

## Actual hosted responsiveness and operational incident — October 4, 2026 UTC

The Soccer implementation is deployed as READY `6ac28b6f641ca7000a2287bb`
(**17:23:26 UTC**, source `ce48206b3025210e8a677826e7f52d477b0fe7ee`). Its
three exact tested canonical migrations are versions **20261004172028/31/34**;
all 40 migration entries match. Final canonical-type app validation passed
304/304 tests, typecheck, zero-warning lint and production build; both CI jobs
passed. The existing disposable measurements below remain unchanged and retain
their functional-test limits.
Final read-only performance advisors reported unused-index and existing Auth
connection INFO groups, with no WARN/ERROR; no final per-group count is inferred.

**HOSTED VERIFIED:** the LIVE detail gate survived two full reloads and Home
navigation; native controlled scoring, clock/added-time, cards, substitutions,
keeper changes and two final epochs completed before **17:43:59 UTC**. Actual
document width equaled viewport at **1280, 768, 390 and 320px** in the created
test tab. Native reopen/correction/refinalization controls were exercised at
320px. The original user tab remained at an untouched 689px viewport; the
first-final interaction is not claimed as a 320px confirmation. These observations establish
usable hosted rendering/navigation for the performed scenarios; no production
latency percentile, concurrent-user capacity or SLA is inferred.

The fixed window began **17:24:28.466723 UTC**, with stop-new deadline
**17:59:28.466723**, cleanup target **18:09:28.466723**, and hard expiry
**18:24:28.466723**. After a **17:43:59 UTC** clock observation, the next confirmed
clock was **21:04:47 UTC**. There is no established cause for this observation
gap and no evidence here attributing it to an application/database timeout.
Guardian activation was refused by the expired-window guard before mutation;
family/guardian hosted acceptance therefore remains unverified.

**Explicit cleanup missed its target and hard deadline.** Temporary bounded
permissions auto-expired at the hard deadline, but that is not on-time explicit
restoration. Immediate recovery restored authority at **21:05:09.183417**, archived
the controlled resources with two immutable epochs at **21:05:15.804037**, restored
the synthetic memberships at **21:05:19.658853**, and restored modules at
**21:05:24.046832 UTC**. Independent residual checks subsequently passed with zero
temporary authority/pending work and valid original administrator access.
Phase 5C remains pending Main Boss review of this incident and the unverified
family case. No additional acceptance window, timeout increase or later phase
is started. Historical Phase 4B performance/remediation and proxy-exposure records
are preserved.

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
