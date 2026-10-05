# Phase 5D controlled hosted acceptance — incomplete, safely restored

The single approved window ran on October 5, 2026 UTC against the existing Boss
platform and canonical Supabase project. **Phase 5D is not complete.** Native
Football game creation remained unconfirmed after its one idempotent retry.
No Football game existed in canonical state. New scenarios stopped and recovery
completed before the cleanup target. The transport/runtime cause is not established;
no product defect is claimed fixed or ruled out. No second window was opened.

The controlled run was `a3736b29-993b-4dae-8231-6120dd22dfc5`. Implementation
source was `8e15df6059f9cb07d0d8ada3a364fba5d063082c`; the current readiness
branch head was `6c86e1daa0398072944546cba654c9bb8c8276f7`. Both CI runs passed
for that head. PR #3 stayed OPEN / DRAFT / UNMERGED.

## Fixed timeline and actual recovery

All timestamps below are UTC. Audit timestamps are evidence of transactions;
they are not independently measured commit instants.

| Item | Exact time/result |
| --- | --- |
| Captured server start | 2026-10-05 00:24:52.457079 |
| Stop new scenarios | 2026-10-05 00:39:52.457079 |
| Cleanup target | 2026-10-05 00:44:52.457079 |
| Hard expiry | 2026-10-05 00:54:52.457079 |
| Independent recovery controller | Armed after capture and before module activation; retired after verified immediate recovery |
| Sports / Calendar preparation audit | 00:25:36.177135; observations 00:25:36.189191 / 00:25:36.192663 |
| Synthetic Calendar event created | 00:26:18.893365 |
| Native Game Center configuration audit | 00:28:38.446459 |
| Administrator restored independently | 00:31:23.365169 |
| Selected authority restoration observation | 00:31:27.072475 |
| Guardian baseline restoration observation | 00:31:31.760797 |
| New-team cleanup observation | 00:31:37.610349; zero created membership rows |
| Original Child1 membership restoration observation | 00:31:41.182563 |
| Controlled resource cleanup observation | 00:31:47.206412 |
| Full module baseline restoration observation | 00:31:54.988898 |
| First complete recovery/result received | 00:32:00.037, orchestration timestamp |
| Repeated canonical strict read-only verification | 00:35:39.763783 |

The fixed deadlines were never extended. Full explicit restoration observation
preceded the cleanup target by **12 minutes 57.468181 seconds** and hard expiry
by **22 minutes 57.468181 seconds**. There was no cleanup-deadline overrun.
Natural authority expiry was not substituted for explicit restoration.

## Activated scope and preparation finding

The approved two Wildcats memberships were **not created**. Their activation,
expiration and explicit-ending times are therefore **not applicable**; the
prepared creation stage was never executed. No new role, organization membership,
guardian capability, household authority, identity or platform assignment was
created. No game operator or guardian stage was activated. The existing Child1
original-team membership was not ended because the history stage was not reached.

Sports and Calendar availability were temporarily bounded to the fixed hard
expiry. The prepared module step activated availability but retained the existing
empty Sports configuration, so native Game Center initially reported disabled.
Within the already authorized controlled configuration scope, its existing native
settings form enabled only Game Center, protected operations, Football live
scoring, Football statistics and Football play-by-play. Public publication,
coach/team administrator management, Basketball/Soccer features and Football
lineups stayed off. This was a private preparation omission, not an application
or schema change. Exact configuration and module-window baselines were restored
by the frozen recovery.

## Hosted outcomes and remaining cases

**HOSTED VERIFIED:** authenticated native Calendar access; exact controlled
Falcons event creation with the existing Wildcats opponent; native finite feature
save; retained signed game-create retry presented the same unconfirmed outcome;
new authenticated administrator Home request after restoration. Prior deployed
history-section/filter/reload smoke remains valid, but is not guardian proof.

**HOSTED UNCONFIRMED:** native Football `game.create`. The UI reported
“The change could not be confirmed. Retry to safely check the same request.”
The one native idempotent retry reported the same outcome. Canonical read-only
checks found zero Football games, engine states, typed facts and seals. Available
safe evidence does not establish the exact HTTP/transport or database error.

**SQL/RUNTIME VERIFIED; HOSTED NOT EXECUTED after the game-creation blocker:**

- The full deterministic rush/pass/incomplete/TD/XP/tackle/sack/interception/
  fumble-recovery/punt-return/kickoff-return/FG/penalty/fourth-down/quarter script.
- Independent hosted score/player/team-stat reconciliation.
- Hosted corrections, finalization, reopen, correction and refinalization.
- Exact-game operator activation/revocation and stale signed mutation denial.
- Football wrong-sport, roster-side, restricted-resource, feature/version denials.
- Actual Football console actions at 1280, tablet, 390 and 320 pixels.
- Old-team membership ending with Basketball/Soccer/Football history preservation.
- Current guardian's history after old membership ends, and natural guardian
  expiry through a fresh hosted request.
- The two approved Wildcats membership activations, new-team private-history
  denial and origin-correction isolation. Existing administrator powers must
  still be distinguished from authority contributed by a team relationship.
- Football halftime/final notification behavior and hosted performance.

No SQL result becomes HOSTED VERIFIED. No next scenario or acceptance window was
started after the failure. The approved portability and origin-authority
architecture remains unchanged; the hosted blocker requires resolution before
closure can be declared.

## Cleanup and final evidence

The frozen admin-first recovery completed and its strict residual/baseline
assertions passed twice. Final state: original administrator valid; zero temporary
person/operator/role/membership/guardian authority; unchanged guardian/household
and selected membership baselines; exact Sports/Calendar/Game Center/Football
configuration and version baselines; zero pending controlled notification work.
There are **zero** new Wildcats rows and zero membership row-count delta.

One expected synthetic Calendar resource remains as archived/unpublished audit
history: event `7e407db7-552c-427e-b3e1-7bad5161167a`. No game or stat seal was
created. The historical seven games and six older unarchived controlled events
were preserved. Exact baseline equality refers to all touched pre-existing
records; the expected archived event and audit evidence are retained, not deleted
to simulate an unchanged total database row count.

Safe audit examples:

| Evidence | Audit ID |
| --- | --- |
| Fixed run baseline | 9447c6ea-f917-4148-8a26-093a911a4aee |
| Native configuration | cb574b5a-2201-4d10-85f6-c9cdd77dbeb0 |
| Independent administrator restoration | e55f9c9c-4bfe-4408-9a38-6a4d4f0daa02 |
| Explicit new-team cleanup | 8390952b-ba90-4961-abb6-299d843584db |
| Resource archival | 2befc6d6-e72a-4a4b-a775-230693483e86 |
| Full module restoration | 2a3c9f3b-d26d-435c-829e-abe279244db3 |

Post-cleanup canonical checks: all **44** migration versions/names unchanged;
**157** read-only schema assertions PASS; generated types remain exactly
**205,474 bytes**, SHA256
`171985c339c0e27240f7c2286cee931f3160ae5913cc08ea677db19bb3a09e63`.
Security advisors retain 80 closed-RLS INFO findings and the existing one
leaked-password-protection WARN. Performance retains 156 unused-index INFO
findings and one Auth connection-allocation INFO; no new WARN/ERROR. No Auth or
security policy was changed.

No password, Auth token, session value, privileged key or credential material was
requested, entered, read, printed, exposed, stored or committed in this hosted
work. Existing browser authentication was used without reading its values.
The historical Netlify proxy credential was not reused or reproduced. No real
youth/customer data or invented DOB was used. Private recovery scripts remain
outside Git and reports. No later sport, aggregation or module was started.

See the [81-point report](PHASE_5D_COMPLETION_REPORT.md) and
[validation record](PHASE_5D_VALIDATION.md). **STOP after this window; Phase 5D
closure remains blocked by incomplete hosted acceptance.**


## October 5 subsequent read-only investigation — addendum

The original unknown-cause record above is preserved. Subsequent safe RPC/SQL
metadata proves both submissions reached PostgreSQL and failed
`PT422: Invalid game context`: the internal opponent was not a Calendar target,
but the candidate read path incorrectly offered that event. No canonical game
was created and later removed. The narrow fix was subsequently directly
authorized, applied as canonical
`20261005110330_phase5d_game_candidate_validation`, released and verified. This
release did not open another acceptance window or create a game or authority.

Reporting correction: configurations, statuses and windows were restored, but
revision counters remained monotonic as recorded by the restoration audit:
Calendar 10 -> 12, Sports 15 -> 18. Earlier wording claiming version equality
was incorrect. This does not change the on-time cleanup or zero temporary
authority result. No new window or temporary relationship was created.
See [the complete investigation](PHASE_5D_CREATION_INVESTIGATION.md).
