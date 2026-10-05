# Phase 5F Baseball + Softball Diamond Engine — completion record

Status: INCOMPLETE; implementation/release and safely authorized hosted work are
validated, and the single controlled window is closed with verified cleanup.
Required Softball scoring and guardian/team-transfer hosted gates remain unverified.
No additional window or later phase is authorized by this record.

1. **Starting SHA:** `8749f2df4bce553e7ca2a386532ef813655c4a86`.
2. **Final SHA:** the documentation handoff commit containing this record (see branch/PR head); validated repair is `cce4b41c52c9dca056e83034301683764a4aa974`.
3. **Architecture:** shared versioned `diamond-v1`, immutable typed facts plus replayable projection; canonical Game Center owns lifecycle and score.
4. **Shared boundary:** Baseball and Fastpitch Softball retain distinct sport keys/catalogs/rules while sharing commands, reducer, state, PA, runner and final-stat storage.
5. **Migrations:** four reviewed migrations plus narrow runner-projection alias repair applied; canonical history 57. No prior migration body rewritten.
6. **Rule profiles:** finite `diamond-rules-v1`; validated configuration, immutable after initialization where required, no universal association-compliance claim.
7. **Stat catalogs:** both sports use shared profile-aware batting, pitching, baserunning and fielding catalogs.
8. **Tracking integration:** existing per-side resolution/snapshots, Quick Stats, intervals and epoch seals; optional disables do not disable required scoring.
9. **Scorebook Lite:** terminal PA/ordered runner results require no invented pitches; SQL and Baseball hosted verified.
10. **Pitch-by-Pitch:** same PA/result path with ordered optional pitches; SQL and Baseball hosted verified.
11. **Game state:** inning/half, sides, score, outs, PA/count, runners, lineup and pitcher appearances replay from canonical facts.
12. **Innings/halves:** explicit transitions and completed-half history; hosted two innings/four halves verified; extra innings/walkoff bounds runtime verified.
13. **Outs:** bounded ordered outs, force/batter-before-first third-out run cancellation; native force third out verified.
14. **Lineups:** immutable roster revision, known athletes plus honest anonymous slots, current batting cursor/bench/positions; native six-slot orders verified.
15. **Plate appearances:** immutable PA start identity, sides and batter/pitcher where known; 20 native terminal Baseball PAs reconciled.
16. **Pitch model:** typed ball/called/swinging strike/foul/foul bunt/in-play; observed counts derive from facts.
17. **Count:** no independent editable count; native four balls/three strikes and typed terminal result verified; foul/count rules runtime verified.
18. **Pitch coverage:** complete, partial and not-tracked are distinct; native primary 13 complete and opponent 11 partial pitches verified.
19. **Batter results:** full typed supported results runtime verified; native BB, single, HR, SO, error, FC and other-out positive proof.
20. **Runner state:** three bases, immutable runner identity/origin/responsible pitcher; no duplicate base or identity.
21. **Runner advances:** ordered typed moves; native lead-runner advancement and vacating-base force sequence verified.
22. **Baserunning:** steal/caught stealing native verified; pickoff/wild pitch/passed ball/balk/indifference runtime verified. Full advance read regression covers steal/wild pitch.
23. **Batting stats:** native primary 12 PA/10 AB/4 H/2 HR/6 R/2 BB/2 SO/1 SB; opponent 8 PA/7 AB/1 H/1 BB/1 SO/0 R.
24. **Derived batting stats:** native primary AVG/OBP/SLG/OPS .4/.5/1/1.5; opponent .142857/.25/.142857/.392857; missing denominator/coverage remains null/not-tracked.
25. **Pitcher appearances:** native initial 1 out/3 BF/8 pitches, successor 5 outs/5 BF/5 pitches; zero-work interim appearance and inherited runners preserved.
26. **Pitching stats:** native primary 6 outs/8 BF/1 H/1 BB/1 SO/0 R/13 pitches; opponent 6 outs/12 BF/4 H/2 BB/2 SO/6 R/11 partial pitches.
27. **Pitch integrity:** uncollected pitches never fabricated; server-owned gap/coverage declarations and disable/re-enable races runtime verified.
28. **ER foundation:** explicit scorer attribution/provenance, runner responsibility and error origins. Exhaustive automatic official-scorer reconstruction deferred; opponent ER native Not tracked.
29. **Fielding:** optional putout/assist/error/double-play attribution with accepted same-game play and enabled coverage; native team-only/reversed/recredited putout epochs verified.
30. **Errors:** native one explicit Child2 defensive error tied to reached-on-error; unrelated ordinary-hit error credits denied in runtime.
31. **Score:** derived solely from accepted scoring movements. Native final 6–0; initialized Diamond never regains manual score authority after feature disable.
32. **RBI:** ordinary movement derivation plus reasoned correction; native 6→5→6 with unchanged 6–0 score.
33. **Substitutions:** current roster/lineup and PA-boundary enforcement; native Child1→existing #7 and pitcher changes retain identity/history. Mid-PA pitcher change is explicitly deferred and rejected.
34. **Baseball config:** two-inning controlled youth rule profile; no MLB/NCAA/NFHS assumptions.
35. **Softball config:** canonical native Fastpitch creation and one-inning six-slot initialization verified; full sport-specific rule validation runtime verified.
36. **Youth rules:** continuous/traditional order size, reentry, stealing, dropped-third-strike, run caps/tiebreak foundation. DH/DP-FLEX/courtesy/mercy/time/pitch-rest foundations do not claim exhaustive enforcement.
37. **Console:** Diamond adapter in existing shared Live Stat Console; persistent score/inning/outs/bases/count/profile and secondary lineup/Box/PBP/settings.
38. **Quick Actions:** supported profile-aware result/pitch actions, ordered saved plays and synthetic practice; local targets at least 64px.
39. **Context:** typed runner/third-out/ER, current-side pitcher and eligible substitution forms; required state remains valid with optional detail off.
40. **Action/player-first:** same canonical command boundary, known roster validation and honest unattributed paths; application/runtime verified.
41. **Scorebook/PBP:** native recent ordered feed and audit-preserved correction facts; chronological view shares canonical facts.
42. **Box Score:** native independent batting/pitching/rates/error/coverage reconciliation passed; zero remains distinct from Not tracked.
43. **Corrections:** append-only reasoned reversal/replacement, dependent-play replay and fielding dependency guards; native RBI/putout changes verified.
44. **Finalization:** canonical state/score/lineup/PA/appearance/stat reconciliation and rule/tracking/coverage seals; three actual Baseball epochs preserved.
45. **Reopen/refinalize:** native paused reopen, explicit return to Live before new appended fielding, refinalization. Epochs retain team-only credit, reversal-only credit, then #7 replacement; no refused fact represented as accepted.
46. **Athlete history:** new Baseball/Softball sealed sources runtime verified; original-admin-only Child1 and unrelated Child2 native history denial verified. Positive guardian hosted evidence UNVERIFIED; the scoped authorization was not received before closure.
47. **Team change:** persistent person/participant and original game/team/org provenance runtime verified; temporary transfer never activated; the scoped authorization was not received before closure.
48. **New-team privacy:** exact-team staff grants no prior private history/correction in SQL/runtime. Pure Wildcats-only Phase 5F hosted negative remains unverified; original administrator has not been paused.
49. **Operators:** current bounded existing-role exact-game assignment; native stale signed mutation denied after operator ended at 17:11:50.925294 UTC. Softball operator creation rejected by automatic approval review; exact typed authorization was not received before closure.
50. **RLS/security:** deny direct client reads/writes on closed raw tables; empty search paths/ACLs, current Auth/session, tenant/roster locks and post-wait permission checks. 49 post-repair live structural checks passed.
51. **Wrong sport:** sport-key and engine-specific commands fail closed; runtime/forged-scope coverage passed. Forged signed hosted matrix unavailable through approved tooling is not HOSTED VERIFIED.
52. **Idempotency:** caller-bound request receipt, current-authority replay checks and real duplicate race passed; one native creation receipt for each controlled sport.
53. **SQL total:** 13,430 SQL/bootstrap assertions in final successful full-history CI, final summaries counted once.
54. **New assertions:** 130 Diamond assertions, including two hosted runner-read repair regressions.
55. **Concurrency total:** 153 genuine coordinated two-connection races.
56. **New races:** 15 Diamond races across pitches/PA/runner/third out/final/pitcher/substitution/correction/replay/profile/revocation/expiry/disable.
57. **Hosted Baseball:** VERIFIED native creation, two-inning deterministic scenario, independent 6–0 reconciliation, correction/seals and stale-operator denial.
58. **Hosted Softball:** creation/roster/rule initialization VERIFIED; scoring/seal/1–0 reconciliation UNVERIFIED because exact temporary operator authorization was not received before closure; not inferred from SQL.
59. **Hosted Lite:** VERIFIED top-one terminal results without pitch entry.
60. **Hosted pitches:** VERIFIED remaining tracked PA counts and 13/11 complete/partial totals.
61. **Hosted not-tracked:** VERIFIED disabled statistics display Not tracked and unknown attribution remains partial.
62. **Reconciliation:** literal pre-entry oracle matched native Baseball required batting/pitching/state/rates; actual corrected epoch attribution disclosed transparently.
63. **Responsive:** actual local 1280/768/390/320 render passed without horizontal overflow. Requested hosted 320px remained 1280px; mobile hosted tooling limitation retained.
64. **Performance:** realistic local 109 PA/436 pitches, nine innings: heavy detail p95 597.91ms/max 599.97ms, Lite max 320.07ms; pitch max 22.94ms, play max 33.22ms, heavy finalize 590.21ms. No timeout increase.
65. **Cleanup timing:** explicit restoration 17:18:23.605980–17:18:23.728901 UTC, before 17:54:38.685596 target and 18:09:38.685596 hard expiry. Recovery retired after strict verification.
66. **Residual authority:** ZERO temporary operators, memberships, active profiles and pending controlled work; all six selected baseline sections equal. Original administrator valid; both events/games archived/unpublished. No guardian/transfer/Softball operator ever activated.
67. **Types:** fresh 57-migration canonical generation byte-identical to committed 230,601-byte database types; no new repair interface.
68. **Typecheck:** PASS after generated types and repair.
69. **Lint:** PASS, zero warnings.
70. **Application tests:** 372/372 PASS locally and CI.
71. **Production build:** PASS locally and CI.
72. **Deployment:** Boss production implementation `bef48600f0da29a9989f8db2f940d63211d33d39` published as `6ac3d2bacea46a00083aa7f3`; narrow database helper repair applied live. Final release verification recorded in handoff.
73. **CI:** repair run [37344840869](https://github.com/eaglevisiondigital/theboss/actions/runs/37344840869) SUCCESS for both application/database; documentation handoff CI is recorded on the PR head; no local application/database rerun required for documentation-only edits.
74. **PR:** [#3](https://github.com/eaglevisiondigital/theboss/pull/3) OPEN/DRAFT/UNMERGED; title/body updated to accurately describe Phase 5F implementation and incomplete hosted acceptance.
75. **Limitations:** exact Softball operator and guardian/transfer approval gates; unapproved administrator pause for pure Wildcats-only hosted negative; hosted forged request/mobile tooling; explicitly deferred finite rule foundations. None is relabeled hosted PASS.
76. **Security exceptions:** existing leaked-password-protection warning retained, intentional closed RLS/unused-index INFO recorded. No new credential/session disclosure, historic proxy reuse, real youth/customer data, invented DOB, weakened Auth/security or timeout.
77. **Later phase:** none started; season/career totals, standings, later sports/providers/financial modules remain outside scope.
78. **Final Phase 5F:** INCOMPLETE. Required Softball scoring/seal/reconciliation, guardian historical access after transfer and Wildcats-only privacy/correction hosted acceptance remain unverified. Main Boss Chat must decide the next narrowly authorized acceptance action; this window is closed. No architecture contradiction is known.

See [hosted evidence](PHASE_5F_HOSTED_ACCEPTANCE.md), [validation](PHASE_5F_VALIDATION.md),
[performance](PHASE_5F_PERFORMANCE.md) and [architecture](DIAMOND_ENGINE_ARCHITECTURE.md).
Prior phase decisions and sanitized security/cleanup incident disclosures remain intact.
