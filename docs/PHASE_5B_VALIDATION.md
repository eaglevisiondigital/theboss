# Phase 5B validation

**MIGRATED AND SQL/RUNTIME VERIFIED; DEPLOYMENT AND HOSTED ACCEPTANCE PENDING.**
This October 4, 2026 UTC entry records completed disposable validation. Local
results do not establish hosted acceptance or Phase 5B completion. Starting SHA:
`1f3e44dd40e6d0aab18545965de5140ae65e5f75`; branch
`build/boss-platform-v1`; PR #3 remains open, draft and unmerged.

## Completed final local validation

The final integrated PostgreSQL **17.11** run exited **0**, applied all **37**
migration bodies to a new disposable database, passed **33 SQL suites** and the
actual-source administrator bootstrap, passed **73 real two-connection races**,
and removed the private cluster. The fresh harness binds no TCP interface; its
Unix socket and run directory are private to the operating-system user. It
copies no production environment files and uses synthetic fixture identities.

The distinct assertion total is **8,616**: **8,588 SQL assertions + 28 bootstrap
assertions**. Of those SQL assertions, **366** belong to the five new Basketball
suites. The race total is **56 retained historical races + 17 new Basketball
races**. Counts describe executed assertion ledgers and coordinated races; they
are not an inferred target or a replacement for missing hosted scenarios.

Canonical migration bodies validated in that run:

| Migration | SHA256 of tested body |
| --- | --- |
| `20261004140729_phase5b_basketball_core.sql` | `1bfdfe987806ba89dac76439ff32494fc7f6b7bc829dcc54519afb71eeef1104` |
| `20261004140736_phase5b_basketball_operations.sql` | `2f8a7f8ab907fda7328615218b437101daac2828a16154d09c53c53d949a2aea` |
| `20261004140744_phase5b_basketball_integration.sql` | `03ddb55c0f11b42b74a1e591d410c19584f11e0f1b52fa435e7dc4ad83b5112a` |
| `20261004141529_phase5b_final_stats_identity.sql` | `3e12ab5fe4e60f01ecaf605205cfcad5610fcda1819c22c7cd126e4101a1d88d` |

All **37 canonical migration versions/names match** local history. Normalized
stored canonical statements match all four reviewed local migration bodies,
with one statement record per migration. The final live read-only verifier
passed **114** assertions and reported zero Basketball fixtures before hosted
acceptance. Canonical TypeScript database types were regenerated; application
checks are recorded separately below.

The initial three-migration run passed 8,612 distinct assertions, including 362
Basketball assertions, and all 73 races. Its initial live verifier passed 113.
The first performance-advisor review identified one informational missing-primary-
key finding on sealed final stats. The narrow fourth migration adds a generated,
non-null UUID row primary key while preserving subject uniqueness, RLS, raw
grants, immutable guards, event derivation and architecture. Final runtime
coverage adds four assertions: the primary key, generated row IDs, stable
original rows across refinalization, and owner identity rewrite denial. The
37-migration full/recovery reruns and canonical application all passed; the
missing-primary-key finding is resolved. No preceding migration body changed.

## SQL assertion ledger

Each SQL suite's assertion ledger is counted once. A grouped summary contributes
the sum of its categories; repeated displays of the same ledger do not add new
assertions.

| Executed SQL suite | Distinct passed assertions |
| --- | ---: |
| `phase2a_authorization.sql` | 1,272 |
| `phase2a_live_verification.sql` | 962 |
| `phase2b_live_verification.sql` | 1,007 |
| `phase2b_operations.sql` | 838 |
| `phase3a_acceptance.sql` | 208 |
| `phase3a_live_verification.sql` | 300 |
| `phase3a_recurrence.sql` | 106 |
| `phase3a_security.sql` | 36 |
| `phase3b_acceptance.sql` | 769 |
| `phase3b_live_verification.sql` | 731 |
| `phase3b_security.sql` | 44 |
| `phase3b_storage_managed.sql` | 1 |
| `phase4a_communications.sql` | 151 |
| `phase4a_communications_live.sql` | 21 |
| `phase4a_notifications.sql` | 87 |
| `phase4a_notifications_live.sql` | 25 |
| `phase4a_security.sql` | 354 |
| `phase4b_attendance.sql` | 88 |
| `phase4b_integrations.sql` | 100 |
| `phase4b_performance.sql` | 56 |
| `phase4b_security.sql` | 355 |
| `phase4b_volunteers.sql` | 151 |
| `phase5a_calendar.sql` | 25 |
| `phase5a_configuration.sql` | 31 |
| `phase5a_games.sql` | 47 |
| `phase5a_live_verification.sql` | 189 |
| `phase5a_notifications.sql` | 15 |
| `phase5a_security.sql` | 253 |
| `phase5b_basketball.sql` | 59 |
| `phase5b_formats.sql` | 39 |
| `phase5b_live_verification.sql` | 114 |
| `phase5b_performance.sql` | 9 |
| `phase5b_security.sql` | 145 |
| **SQL total** | **8,588** |
| Actual-source bootstrap | **28** |
| **SQL + bootstrap** | **8,616** |

The new Basketball suites cover independent hand-calculated player/team oracles
for every required play family, attempts and points; two halves, four quarters
and overtime; authoritative clock start/stop/correction and pause/delay/Calendar
cancellation; per-period team fouls; exact roster and lineup/substitution rules;
linked assist semantics; immutable correction/reversal; sealed final epochs and
reopen/refinalization; finite history summaries; and bounded projection volume.

Security cases verify the unchanged 21-role/59-permission/446-mapping/14-module
catalog; all six raw tables closed under RLS with no client grants or policies;
fixed-path private helpers; FK/index support and immutable evidence guards;
wrong sport, tenant, game, side, roster and bench-player denial; exact scorer
entry identity; coach authority denial; family/household masking; ended mapped
role, team membership and exact operator denial; duplicate receipt revalidation;
feature-off denial; and malformed/injected command fields. Configured-engine
start and paused-to-live commands retained before disabling either live-scoring
or statistics must receive **PT403**, with unchanged canonical state/version and
frozen pause clock. UI capability masking is checked separately.

## Historical count reconciliation

The retained Phase 5A report states **8,721** SQL/bootstrap assertions. An
independent recount of its archived successful run yields **7,990 distinct
assertions**. Its Phase 3B live verifier prints the same **731**-assertion ledger
twice; **7,990 + 731 = 8,721**. Both printed summaries describe the same executed
cases. Historical reports and acceptance history are preserved unchanged.

This run uses the distinct-ledger method consistently:
**7,990 + 260 expanded existing checks + 366 Basketball checks = 8,616**.
The 260 additional existing checks come from raw-table/RLS/ACL sweeps over the
new closed tables and private helpers: Phase 2A authorization +60, Phase 2A live
verifier +66, Phase 2B live verifier +66, Phase 2B operations +30, Phase 5A schema
verifier +6, and Phase 5A security +32. There is no removed behavioral suite.
The legacy 51/63/73-table inventory assertions exclude exactly the six new
Basketball tables, preserving their original expectations. The historical
finite default-flags assertion subtracts exactly the four new Basketball flags,
while the Basketball verifier separately proves that all four default off.

## Real concurrency evidence

| Executed two-connection harness | Passed races |
| --- | ---: |
| `phase2a_hierarchy_concurrency.sh` | 3 |
| `phase2b_mutation_concurrency.sh` | 2 |
| `phase3a_mutation_concurrency.sh` | 3 |
| `phase3b_mutation_concurrency.sh` | 8 |
| `phase4a_communications_concurrency.sh` | 5 |
| `phase4a_notifications_concurrency.sh` | 3 |
| `phase4b_attendance_concurrency.sh` | 3 |
| `phase4b_volunteers_concurrency.sh` | 7 |
| `phase5a_games_concurrency.sh` | 22 |
| `phase5b_basketball_concurrency.sh` | 17 |
| **Total** | **73** |

The 17 Basketball races exercise simultaneous baskets; refreshed retry of the
optimistic-version loser; duplicate same-request free throw; score versus
substitution/foul; period end versus score in both winner orders; finalization
versus a waiting late event; reversal versus new event; simultaneous
substitutions; clock collision; operator, role and membership revocation while
the signed caller waits; feature disable while blocked; and duplicate foul,
substitution and correction. The writer's uncommitted change is observed, the
other connection must be observed waiting on a PostgreSQL lock, then the writer
commits. Assertions verify exact winner, SQLSTATE, receipt/fact count, complete
canonical sequence, reconciliation and absence of partial losing writes.

A first integrated run completed SQL and historical races, then exposed a test
fixture namespace collision because the historical Game Center race retains
its committed synthetic evidence. The Basketball harness now copies the
reviewed fixture into the same private run directory with isolated, fixed
synthetic identity/email/slug namespaces. It preserves historical evidence and
security controls. The focused Basketball run and the subsequent complete
integrated run both passed all 17 new races. This was a test-harness defect.

The prepared controlled recovery procedure also passed **22** separate focused
assertions on its final bytes against all 37 migration bodies; its private
cluster was removed. Those recovery assertions are reported separately
and are excluded from the 8,616 full-suite total. They do not establish live
cleanup or authorize a new acceptance window.

## Application and deployment gates

The preceding application snapshot passed **273/273 tests**, typecheck,
zero-warning lint and production build using the clean private pinned runtime.
Independent review before deployment then identified a client retry issue:
refreshing after an unknown mutation outcome changed the expected-version
signature instead of retaining the original command/request for an idempotent
retry. The focused correction now retains one immutable command/request ID in
a stable page-scoped provider shared by all Basketball controls/forms, preserves
selection during canonical refresh and blocks new changes until explicit original
retry resolves. Four additional regressions passed; final focused **59/59**, full
application **277/277**, typecheck, zero-warning lint and production build **PASS**.
No database source changed; completed SQL/concurrency evidence remains valid.

Hosted scoring/stat reconciliation, correction/finalization/reopen,
role/family isolation, desktop/tablet/390px/320px interaction, navigation,
notifications and controlled cleanup remain subject to the approved hosted plan.
The controlled hosted window remains closed at this checkpoint.

Post-migration security advisors report **70 informational closed-RLS findings**
and **one preexisting Auth warning**. Performance advisors report **143 unused-
index informational findings** and **one existing Auth connection configuration
informational finding**, with no warning/error and no remaining missing-primary-
key or missing-FK-index finding. Required indexes remain intact. No Auth/security
setting or timeout was weakened to obtain these results.

Final application validation is **PASS**; deployment and hosted acceptance remain
**PENDING** at this checkpoint. Record actual live outputs as available. No local
result is promoted to HOSTED VERIFIED. No later sport engine or module was started.
