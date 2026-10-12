# Phase 5B controlled hosted Basketball acceptance

**COMPLETE — October 4, 2026 UTC.** Actual native signed-browser acceptance on
the existing Boss platform, followed by independently verified restoration.
SQL/runtime coverage and unavailable forged signed requests retain separate
classifications. No additional window or later sport engine was opened.

## Deployment and fixed window

Implementation `23e86382a0565f4d25770cefda034428f040f2bf` was published to
`https://thebossplatform.netlify.app` by the existing Git deployment workflow.
Boss platform site `cf09c44d-f28b-45aa-8a18-e4fa81e2008f`, deploy
`6ac261b0c882a50008b25a31`, was READY at **14:25:17.412 UTC**. Public website
production code/configuration was not changed. Existing GitHub PR previews are
separate from the platform production deployment.

Run `d23d41cb-75f8-4503-b326-a47d1c3d8606` captured its baseline at
**14:26:33.224999 UTC**. Fixed deadlines: stop new scenarios **15:01:33.224999**,
cleanup target **15:11:33.224999**, hard expiry **15:26:33.224999**. Cleanup
completed at **14:51:37.590726 UTC**, before every deadline. No extension or
second window occurred.

Only one synthetic Calendar event and one Basketball game were created through
ordinary hosted forms and recorded in the finite audit manifest:

- Event `c2cdf8ab-2f96-4a27-b6cd-11d00ca20b79`, October 4 at 15:00–16:00 UTC.
- Game `52070eaf-ce97-480c-ba83-c600a39f9d15`, controlled Falcons versus Wildcats.
- Existing roster snapshot 1: Child1 (A), existing synthetic Falcons athlete #7
  (B), and Child2 on Wildcats (C). No person, DOB or customer record was created.
- Exactly two short-lived game operator assignments, one existing administrator
  and one exact Falcons scorekeeper. Both are ended.

Six finite Sports/Game Center/Basketball flags were temporarily enabled from the
captured baseline. Public Game Center and automatic coach/team-admin scoring
remained off. Messaging/provider integration was not enabled for this window.
Quarter duration and overtime duration were 60 seconds; regulation had four
quarters. Lineup size was one with enforcement off for the three-athlete fixture.
This verifies bounded participation controls, not five-on-five competition,
precise minutes or plus/minus.

## Actual native results

| Scenario | Evidence/result |
| --- | --- |
| Explicit Basketball activation, pregame roster and Start | **HOSTED VERIFIED**; explicit sport key, existing canonical Calendar/game identity, snapshot 1 and ordinary Start confirmation. No sport inferred from the parent program's name. |
| Administrator LIVE-detail gate | **HOSTED VERIFIED**; controls, roster, operators and history survived two full reloads and Home/detail navigation without page error or unavailable fallback. Gate audit was recorded only after observation. |
| Period and clock | **HOSTED VERIFIED**; first-quarter start, server clock start/stop (56 seconds settled), reasoned set back to 60 seconds, legitimate end/start of all four quarters. Ended fourth quarter at stopped 0:00 before finalization. Two halves/overtime and invalid transitions retain **SQL/RUNTIME VERIFIED** coverage. |
| Required Basketball plays | **HOSTED VERIFIED**; all 19 oracle plays below entered through native scoring/stat controls. |
| Substitution | **HOSTED VERIFIED**; A out/B in, retained lineup history, 320px native controls. |
| Reconciliation | **HOSTED VERIFIED**; independent 6–3 score and all five player/team rows matched every expected statistic and derived percentage. |
| Double-tap request | **HOSTED VERIFIED**; native 320px double-tap on A's made free throw accepted exactly one extra free throw. Version 33, 7–3 score and 28 typed facts. Legitimate later identical actions remain separate requests; application recovery regressions cover an unknown response across server refresh. |
| Exact Falcons scorekeeper | **HOSTED VERIFIED**; A/B named entry, opposite side limited to legitimate team/unattributed facts; athlete-required steal disabled there. No correction, Finalize or Reopen controls. No automatic broader administration. |
| Unrelated Wildcats game | **HOSTED VERIFIED native GET/resource denial**; existing unrelated controlled game was restricted. This is not forged POST evidence. |
| Revoked operator retained mutation | **HOSTED VERIFIED**; exact operator ended while admin remained inactive, retained native Made 2 form submitted: permission denied. Version 33, score 7–3 and 28 typed facts unchanged. |
| Reversal and correction | **HOSTED VERIFIED**; restored admin reversed the double-tap free throw to 6–3, then corrected A's original made 2 to made 3, yielding 7–3 with original evidence retained. |
| First finalization | **HOSTED VERIFIED**; native confirmation after ordered regulation, epoch 1 at 7–3, version 43, 37 typed facts and five normalized sealed stat rows. |
| Final-game retained mutation | **HOSTED VERIFIED**; ordinary LIVE form retained in a separate tab before finalization submitted afterward. Stale game/authority denial; version 43, score 7–3 and 37 typed facts unchanged. Temporary tab then closed. |
| Reopen/refinalize | **HOSTED VERIFIED**; reasoned native Reopen, current-leaf made 3 corrected back to made 2, native refinalization to epoch 2 at 6–3/version 46. Both core/stat epochs retained, ten sealed rows total. |
| Epoch immutability | **CANONICAL READ-ONLY VERIFIED**; epoch 1 normalized-stat digest including row IDs remained `e59130694e9579c9abd44ca2cd605775` after refinalization. |
| Final box and chronological play-by-play | **HOSTED VERIFIED**; all five rows again match the oracle; 28 safe play-by-play projection rows are strictly sequence ordered. Typed control facts and displayed play-by-play are distinct counts. |
| Child1 guardian-only view | **HOSTED VERIFIED**; existing exact Child1 relationship temporarily active, all eight capability flags unchanged false, admin inactive. Score 6–3, team totals and Child1's 3 points/stats visible. Child2 and B identities masked, only Child1 roster shown; private operators, correction reasons/audit and historical stat epochs absent. Full reload remained correct. |
| Unrelated Child2 | **HOSTED VERIFIED native GET/resource denial** under Child1-only relationship. No unrelated child authority was added. |
| Guardian removal | **HOSTED VERIFIED**; after exact relationship revocation, Child1's former family game URL was restricted. |
| Archive and final navigation | **HOSTED VERIFIED**; ordinary Calendar editor archived the exact event and synchronized game schedule to archived/unpublished. Reload confirmed archival; administrator Home remained valid after module restoration and full reload, with temporary game card absent. |

### Independent scoring/stat oracle

The ordered accepted baseline plays were: A made 2; B made 3; A made FT; C made 3;
A missed 2; B missed 3; A missed FT; C missed 2; A offensive rebound; A defensive
rebound; C defensive rebound; A assist linked to B's made 3; A steal; A block;
A turnover; C turnover; Falcons unattributed team turnover; A personal foul;
C personal foul. No player attribution was invented for the team turnover.

| Row | PTS | ORB | DRB | REB | AST | STL | BLK | TO | PF | FG | 3PT | FT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| A / Child1 | 3 | 1 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 1/2 | 0/0 | 1/2 |
| B / Falcons #7 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1/2 | 1/2 | 0/0 |
| C / Child2 | 3 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1/2 | 1/1 | 0/0 |
| Falcons team | 6 | 1 | 1 | 2 | 1 | 1 | 1 | 2 | 1 | 2/4 | 1/2 | 1/2 |
| Wildcats team | 3 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1/2 | 1/1 | 0/0 |

All shooting percentages reconcile with those fractions; zero attempts display
`--`. Extra free throw plus later reversal did not change the final oracle.
Correcting A's 2 to 3 changed A to four points and Falcons to seven for epoch 1;
reopening/correcting back restored the original oracle for epoch 2.

### Responsive proof

Actual document width was measured after selecting the intended tab, not inferred
from viewport commands. No horizontal document overflow at **1280**, **768**,
**390** or **320** pixels. Desktop Start and later correction/final box, tablet
clock/entry/Reopen/box, 390px entry/refinalization/box, and 320px substitution,
double-tap, period advance and first-final confirmation were actually executed.
Common 320px play buttons measured 56–58px high. Saved synthetic screenshot
artifacts exist outside Git in the task's `phase5b-evidence` directory. An initial
tablet capture targeted the other tab; it was replaced by a measured 768px capture
after closing that tab. No pass is based on the mistargeted capture.

## Restoration and audit evidence

The original administrator was restored in its own committed transaction before
other cleanup, then native Home was verified. Its exact original role, identity,
scope and start were preserved. The second independently recorded restoration
was **14:50:26.281619 UTC**, audit `73664768-bd4e-45a0-9803-e92ed84d2f12`.
Original admin was also restored at 14:39:20 before elevated correction testing.

| Checkpoint | Safe audit evidence / UTC |
| --- | --- |
| Baseline and immutable fixed deadline | `5f79a6db-fa6d-4f65-b4cf-30096ef027f3`, 14:26:33.222270 |
| Administrator LIVE-detail gate | `7dc2a8c2-d24b-4d13-adc7-76c5e940a10b`, 14:32:19.243899 |
| Exact scorer preparation | `d7803d58-91cc-43a9-bda8-2ce8cf25dfaa`, 14:35:44.669282 |
| Scorer-only context | `83a312ef-5550-441f-a772-53125dd9f30b`, 14:37:31.578057 |
| Exact operator revocation | `9521174c-79f2-4cc9-9ffb-1e3cf60ae2e4`, 14:38:22.481608 |
| Child1-only context | `969065a3-955f-451d-bace-da82eccbf499`, 14:46:34.691985 |
| Child1 guardian revocation | `9cf54822-85e5-4ee8-8447-669503cf9364`, 14:50:10.130902 |
| Final person/operator restoration | `6f69181a-1e36-4854-b241-cbf14b997062`, 14:50:39.745827 |
| Exact resource cleanup checkpoint | `fc37c4fe-cc2f-48f9-af18-ff324a0f6b70`, 14:51:33.090475 |
| Exact module-baseline restoration | `5a8dea08-a339-405c-b947-1e8e1704057f`, 14:51:37.580957 |

The ordinary signed event archival succeeded. The reviewed exact-manifest cleanup
checkpoint then confirmed archival/preserved history and closed only any pending
run-source work; no emergency forced game cancellation or score rewrite was
needed. Resource history/stat seals remain intact, with game version 47 reflecting
the legitimate Calendar archival. Both operator assignments ended, the temporary
Falcons scorekeeper role is inactive, existing Falcons staff and Child1 guardian
records match their inactive baseline, and no guardian capability flag, household
membership, organization membership or unrelated record was broadened.

Read-only final restoration assertions passed:

| Final check | Result |
| --- | --- |
| Original administrator valid | true, also native Home/full-reload verified |
| Exact authority and module baseline restored | true |
| Active temporary person/operator/relationship authority | 0 |
| Active temporary module authority | 0 |
| Unarchived recorded events / active unexpected fixtures | 0 |
| Pending recorded notification sources/work | 0 |

Read-only final schema verification passed **114 assertions**: six closed
Basketball tables, ten helpers, one archived engine, 38 immutable typed facts
and two final epochs. All **37** migration names/versions match; final regenerated
database types are byte-identical (**182,318 bytes**). Final security advisors:
70 intentional closed-table RLS INFO and one pre-existing leaked-password WARN.
Final performance advisors: 140 unused-index INFO plus one pre-existing Auth
connection INFO, no WARN/ERROR. The pre-window 143 unused-index count remains
dated historical evidence. No advisor exception or Auth setting was changed.

## Evidence limits and security confirmations

Forged signed athlete/game/team/unit/tenant requests and native wrong-sport
mutation construction unavailable through approved tooling remain:
**SQL/RUNTIME VERIFIED; HOSTED FORGED-REQUEST EXECUTION NOT AVAILABLE THROUGH
APPROVED TEST TOOLING.** Native GET denial is not relabeled as POST denial.
Restricted correction/reopen controls were absent; their forged mutations are
covered by SQL/runtime tests. One allowed fixture was used, without adding an
extra wrong-sport or unrelated game to force hosted positives/negatives.

Notification hooks/no per-play spam retain source/SQL/runtime coverage; no Phase
5B positive notification recipient/provider-delivery claim is made. Public
publication remained off. Precise minutes and plus/minus remain deferred; no
five-on-five accuracy certification is claimed.

No password, Auth token, session value, privileged key, provider secret or
credential material was requested, entered, read, printed, exposed, stored or
committed during Phase 5B. Native browser requests used the already authenticated
session without extracting it. No real youth/customer data was used, no DOB was
invented, and no security policy was weakened. The historical Netlify proxy
credential was not reused or reproduced. Prior disclosures and acceptance history
remain preserved. No later sport engine/module started. **STOP after Phase 5B.**
