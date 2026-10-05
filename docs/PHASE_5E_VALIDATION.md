# Phase 5E validation record

Status: local and canonical schema validation passed; deployment and hosted
acceptance pending. Starting SHA `83380a239fa3e6434a4b9d09f54852b1c0bc8597`.
Approved architecture preserved in commit `51ef9db`.

## Focused PostgreSQL 17 results

All tests use fresh disposable PostgreSQL 17 over a private Unix socket with no
TCP interface. Synthetic fixtures roll back or the entire cluster is removed.
The latest focused run passed **193 SQL assertions**:

| Suite | Assertions |
|---|---:|
| Commands / immutable epochs / guardian history | 14 |
| Read-only schema / ACL / sport identity verification | 71 |
| Bounded append / complete-detail performance | 2 |
| Profile permissions / partial coverage / raw RLS | 35 |
| Reducer formats / caps / rotations / libero / tracking | 36 |
| Exact scope resolution / no descendant inheritance | 10 |
| Wrong sport / forged IDs / replay / immutable resources | 25 |

**15 genuine coordinated two-connection races** passed: simultaneous rallies,
set completion, finalization/late fact, correction/finalization, duplicate request,
two profile edits, midgame profile/rally, profile/scoring start, coverage/finalization,
organization profile/snapshot creation, operator revocation, natural operator
expiry, simultaneous substitutions, feature disable, natural manager expiry.
Participants are synchronized through actual PostgreSQL lock waits and fixed
participant deadlines, not serial simulations.

The full historical run passed **13,066 SQL/bootstrap assertions** and **138
coordinated races**, including the new suites above. Earlier
attempts identified two missing composite indexes, historical public-table
inventories needing the 11 exact new tables excluded from prior subset counts,
and prior finite-feature inventories needing the four Volleyball flags excluded
from historical subsets. Each existing assertion is retained. The new structural
suite verifies the additional resources directly. No earlier migration body was
modified. The Phase 5D candidate filename was aligned to the canonical timestamp
`20261005110330` without changing its contents or replaying it.

## Application and layout checkpoint

Application tests: 351/351 passed at the local implementation checkpoint.
Typecheck and zero-warning lint passed. Production build passed using explicitly
synthetic public build-format values; no live backend request was required.
A fresh final run remains required after the latest accessibility/layout changes.

The actual rendered console on an isolated synthetic local preview was measured
at 1280, 768, 390 and 320 pixels: page scroll width equaled viewport width at all
four widths. Quick actions were at least 64 pixels tall. On phones the order is
persistent state, side/Quick Stats, athlete selection, recent entries, More Stats
and secondary console navigation. Arrow/Home/End key behavior and roving focus
are implemented for console tabs. These are LOCAL layout checks, not hosted
signed-session acceptance evidence.

## Release gates

All six Phase 5E migrations are applied; canonical history contains 52 entries.
The live structural/ACL verification passed 71 checks. Canonical types regenerated.
Advisors retain closed-RLS INFO (91), existing leaked-password-protection WARN (1),
unused-index INFO (172) and absolute Auth connection allocation INFO (1). No Auth
settings changed. No temporary hosted authority has been activated.
Required remaining gates: Boss platform deployment, one fixed controlled native hosted acceptance
window, explicit restoration before hard expiry, baseline equality and residual
checks, final documentation/commit/push and OPEN/DRAFT/UNMERGED PR #3 verification.
No later sport/module is authorized or started.
