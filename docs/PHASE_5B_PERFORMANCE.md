# Phase 5B performance evidence

**FINAL LOCAL RUNTIME, HOSTED INTERACTION AND POST-CLEANUP ADVISORS VERIFIED.**
Measurements below come from the final successful integrated PostgreSQL 17.11
run on October 4, 2026 UTC. The private cluster was removed. They are single-run
local observations, not production latency percentiles, network measurements or
an organization-scale load/SLA claim.

## Measured append and projection behavior

The fixture sends real Basketball made-free-throw commands through the canonical
mutation RPC with fresh request IDs and current optimistic versions. It records
10, 100 and 1,000 cumulative accepted plays. Each row times only its newly
appended batch; the per-event value is that batch's mean, not a percentile.
Isolated box projection calls the actual event-derived totals function. The full
Game Center detail read includes current authorization, safe roster/stat fields
and bounded play-by-play.

| Cumulative plays | New append batch | Batch append ms | Mean append ms/event | Box projection ms | Full detail read ms | Returned plays |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 10 | 1–10 | 86.600 | 8.660 | 0.679 | 63.539 | 11 |
| 100 | 11–100 | 806.696 | 8.963 | 0.988 | 60.766 | 101 |
| 1,000 | 101–1,000 | 11,301.619 | 12.557 | 3.662 | 84.617 | 500 |

The 11/101 early play counts include the period-start fact. At 1,000 accepted
scoring plays, the detail returns its bounded latest **500** chronological plays
and `more_plays=true`; score, FTM and FTA still derive from **all 1,000** active
scoring facts. Full totals are never derived from the UI tail. The nine
performance-suite assertions verify exact totals at each volume, the 500-row
bound, no high-frequency Basketball notification source and a contiguous
canonical operation ledger.

These measurements support the current bounded per-game projection design.
They do not establish costs for a large final-epoch history, many concurrent
production operators, season/career aggregation or millions of people. Those
later workloads were not implemented or claimed in Phase 5B.

## Structural evidence

All six raw Basketball tables are closed under RLS, and the 114-assertion
read-only verifier checks valid/ready indexes, validated constraints and index
support for every Basketball foreign key. The per-game state uses its canonical
game primary key; typed events preserve exact game/sequence and canonical
operation identity. Scoped roster, correction, assist-context and final-epoch
relations have supporting indexes. Live box/stat projection reads the complete
single-game fact set; play-by-play fetches at most 501 candidates to return a
500-row tail with a truthful continuation indicator. Finalization seals exact
per-game/player/team totals into immutable canonical epochs.

No statement timeout, Auth setting or security policy was increased or weakened.
No production credentials, environment files or real youth/customer data were
used by these local measurements. The existing historical Phase 4B timeout and
remediation evidence and Netlify proxy-exposure disclosure remain intact.

## Live verification checkpoint

All four Basketball migrations are applied canonically. All **37** migration
versions/names match local history, and normalized stored bodies match the four
reviewed local bodies. The final live read-only verifier passed **114** checks
with zero Basketball fixtures before hosted acceptance.

The initial three-migration advisor review identified an informational missing-
primary-key finding on `game_basketball_final_stats`. The narrow fourth migration
adds a generated UUID row primary key while preserving per-epoch/side/roster
uniqueness, closed RLS/grants and immutable guards. The final 37-migration
runtime verifies stable sealed-row IDs, unchanged original epochs across
refinalization and exact identity rewrite denial. The missing-primary-key
finding is resolved. The earlier successful measurements remain available in
the local run record: box projection 0.697/0.934/3.500 ms and full detail
41.909/39.100/50.623 ms at 10/100/1,000 plays. The table above uses the final run.

The pre-acceptance performance-advisor checkpoint reported **143 unused-index informational
findings** and **one existing Auth connection configuration informational
finding**, with **no warning/error**, no missing-FK-index finding and no remaining
missing-primary-key finding. The security advisor reports 70 expected closed-RLS
informational findings and one preexisting Auth warning. Fresh unused-index
information does not justify removing integrity or scoped-access indexes.

## Hosted interaction and final advisor checkpoint

The corrected implementation deployed from
`23e86382a0565f4d25770cefda034428f040f2bf` and reported READY at **14:25:17 UTC**
on October 4. Native controlled hosted scoring, box/stat reconciliation,
correction, finalization, reopen/refinalization and family reload completed. Real
**1280/768/390/320px** viewports completed meaningful actions with no horizontal
overflow. A native 320px double free-throw interaction produced one contribution;
retained signed forms after operator revocation and finalization were rejected
without changing their recorded version/score/typed-fact checkpoints. These are
functional hosted observations, not response-time percentiles or load results.

The controlled small roster used lineup_size=1 and three athlete rows plus two
team-total rows. Full five-player lineup, large-volume and wrong-sport/forged-
request cases remain SQL/runtime evidence. Minutes, plus/minus, season/career
aggregation and new sport engines remain outside this phase's displayed outputs.

Exact cleanup completed at **14:51:37 UTC**, before stop-new **15:01:33**, cleanup
target **15:11:33** and hard expiry **15:26:33**. Original administrator access is
valid; all temporary operator/role/staff/guardian/module authority is inactive or
restored to baseline; zero unarchived unexpected controlled fixtures and pending
controlled sources remain. Safe immutable history retains one archived engine,
38 typed facts, two final epochs and ten sealed stat rows. No application/schema
change occurred during hosted acceptance.

Final read-only checks at approximately **14:53 UTC** passed **114** assertions.
All **37** migration versions/names match and regenerated types compare exactly
at **182,318 bytes**. Final performance advisors report **140 unused-index INFO**
and **one preexisting Auth absolute-connection INFO**, **no WARN/ERROR**, no
missing-FK-index finding and no missing-primary-key finding. The pre-acceptance
143 unused-index findings above are retained as dated history; controlled usage
accounts for three indexes no longer reported unused. Required indexes remain
intact. Final security advisors retain **70 intentional closed-RLS INFO**, one
preexisting Auth leaked-password WARN and no ERROR.

The local timings establish no hosted latency or production-scale SLA. The
historical Phase 4B timeout/remediation record and Netlify proxy disclosure remain
unchanged. Native hosted evidence does not promote the unexecuted forged signed
request matrix or wrong-sport cases to HOSTED VERIFIED. See
[the validation ledger](PHASE_5B_VALIDATION.md),
[the controlled hosted plan](PHASE_5B_HOSTED_PLAN.md), and
[the completion report](PHASE_5B_COMPLETION_REPORT.md).
