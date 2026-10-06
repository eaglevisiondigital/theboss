# Phase 6E validation

Status: local/canonical/application validation passed and deployed; hosted
acceptance INCOMPLETE after the fixed-window cleanup incident. Starting SHA is
`cc31206d4e851c4c5d81fc56526ef7a54b3c78dc`.

The four append-only migrations add the canonical honor extension, authoritative
source adapters, bounded operations and safe read/showcase/notification adapters.
The historical migration files remain unchanged. Historical catalog assertions
exclude only the three approved new permission keys and ten new tables; separate
Phase 6E security assertions check their complete live permission/RLS/ACL matrix.

## Local evidence

The focused suite has exercised canonical athlete honor reuse, idempotent
threshold crossing/rebuild, separate thresholds, immutable definition versions,
nomination/approval/revocation/restoration, private note boundaries, canonical
source correction, record co-holders/chronology, qualified/tied leaders, rate
coverage, explicit standings closure, authoritative championship placement,
sealed athlete eligibility, recruiting consent/selection and transfer isolation.

Nine coordinated two-connection races cover duplicate evaluation, source
generation invalidation, approval/revocation, actual showcase publication versus
correction, final tournament ruling versus recognition, definition revision versus
evaluation, guardian revocation versus display, transfer versus staff reads and
rebuild versus source correction. The full historical run passed, followed by a final focused run for context-bounded
reads. Together they verify 17,389 unique reported SQL/bootstrap assertions
(including 175 dedicated Phase 6E checks) and 204 coordinated races. Counts use
each suite summary once, include the 33 sealed-source checks and actual bootstrap,
and exclude duplicated JSON/NOTICE and category subtotals. Live-clock validity
expiration and context-free feed denial are covered.

The application currently passes **432/432 tests** and typecheck. Badge semantics
retain name, category, verification, date and state in text. Public badge rendering
does not create private history links. Canonical generated types, final zero-warning lint and production build pass.
Both read and mutation adapters now compile directly against canonical RPC types.

Local rendered management/cards/history/controls passed measured 1280, 768, 390
and 320 pixel layouts without page-level horizontal overflow. This does not yet
claim hosted profile, family or showcase evidence.

## Canonical and release evidence

Canonical `the-boss-platform` is verified ACTIVE_HEALTHY in `us-east-1`, PostgreSQL
17.6, with **73** migration rows before Phase 6E and **78** afterward. Four migration
versions are `20261006132819`, `20261006132827`, `20261006132830` and
`20261006132836`; their SHA-256 hashes match the four repository sources exactly.
All ten public tables are RLS enabled with closed raw client ACLs, helper search
paths are fixed/empty, all 45 foreign-key vectors are indexed and no definitions
were seeded. No temporary Phase 6E grant has been applied. The linked Netlify CLI site is the existing Boss platform;
the public website is a separate release and is untouched.

Post-migration advisors report intentional policy-free closed RLS INFO (149), the
pre-existing leaked-password-protection WARN (1), unused-index INFO (303) and the
existing absolute Auth-connection INFO (1). No new WARN/ERROR or unrelated Auth
configuration change was introduced. Deployment, CI and single-window cleanup
results will be appended after actual release/acceptance. Prior incident and acceptance
history is preserved; no credential-bearing value is reproduced.

## Security and scope

New automatic honors require authoritative complete facts; unknown values are not
zero. Definition rules are finite and typed, with no SQL/formula/artwork execution.
The legacy ad hoc issuance operation cannot bypass enabled definitions/approval.
Exact source-team authorization uses explicit function parameter references.

No password, Auth token, session value, privileged key or historical Netlify
credential-bearing URL is needed for validation. Use synthetic CONTROLLED TEST
data only. No Auth setting, timeout, public website or later module is changed.

## Pre-window manual-approval regression fix

Recovery rehearsal found that an earlier same-day human award date could silently
produce an approved nomination without a canonical honor. A fifth append-only
migration, `phase6e_manual_decision_timing` (canonical `20261006141110`, SHA-256
`d7b72b04520b61b1383704e76edc97d9733464e6ed728ee5805a79ba8f3aca4a`),
preserves explicit human award dates while retaining automatic effective-date
policy. Approval now rolls back atomically when the recipient becomes unavailable.
Five focused regressions pass. The complete rerun passes 17,389 SQL/bootstrap
assertions, 175 Phase 6E assertions and 204 races. Current canonical function ACLs
and empty search paths are unchanged; regenerated canonical types match exactly.
Administrator/guardian/transfer/manual-history recovery was rehearsed in one
rolled-back transaction: all five restoration/history assertions passed. No
temporary authority or acceptance window was committed by the rehearsal.

Application deployment `6ac4f9858ab5b9c1603eb964` is READY from `68a7bb3`;
432 application tests, typecheck, zero-warning lint and build pass. The fix changes
canonical RPC implementation and SQL coverage only; deployed application bytes
remain current. Original administrator and selected baseline remain intact.

## Actual hosted outcome and cleanup incident

The single fixed window executed core milestone, record, team championship and
manual-award scenarios, with guardian profile presentation and four management
viewport sizes verified. Explicit cleanup missed the fixed target and hard expiry.
Administrator-first restoration was committed at 15:20:52.017742 UTC; zero residual
temporary authority and zero controlled pending work are verified. Selected source
baseline equality is **not** complete: the synthetic Volleyball source remains
classified official in five current immutable contribution rows. No second window
or security/Auth bypass was activated. Outstanding scenarios remain SQL/RUNTIME
VERIFIED only, and the attempted showcase selection returned unresolved 403.
See PHASE_6E_CLEANUP_INCIDENT.md and PHASE_6E_HOSTED_ACCEPTANCE.md.
Both implementation/fix CI runs passed; final incident-documentation CI is reported
with its exact commit in the handoff. No complete/closure claim is made.

Final read-only canonical review after recovery: ACTIVE_HEALTHY, 78 migrations;
security INFO 149 and existing leaked-password WARN 1; performance unused-index
INFO 296 and existing Auth connection INFO 1. Earlier 303 unused-index count is
preserved above as its original observation, not overwritten.


## Subsequent source-baseline recovery validation — 2026-10-06

Recovery used existing deployed code/schema only. A disposable PostgreSQL
rehearsal passed **13 focused recovery assertions**, including immutable source
correction, record-holder removal, corrected recognition, history retention,
configuration cleanup and zero pending work. No full historical suite was redone
for the recovery. The rehearsal caught cleanup ordering: archiving record
configuration creates invalidation work, which must be settled through the existing
bounded worker before final definition deactivation.

One canonical recovery-only window appended pending classification revision 2 and
refinalized epoch 4 through native signed original-administrator controls. Read-only
canonical checks prove five current pending/zero official contributions, exactly
one current set, unchanged logical identities and all ten prior immutable rows,
fresh selection and five source summaries, no current record candidates/holders,
retained record history with source-correction invalidation, corrected milestone
and record recognition, retained recognition history, zero pending work and exact
selected semantic authority/configuration/resource baseline. No affected Volleyball
leaderboard scope exists; profile statistics use the refreshed shared summaries.

Original administrator remained active; native Home was verified after cleanup.
Explicit restoration at **16:33:18.060776 UTC** met target **16:41:05.237068 UTC**
and hard expiry **16:44:05.237068 UTC**. Final strict verification occurred at
**16:37:01.593760 UTC**. The original acceptance deadline failure remains intact.
No new acceptance stage, code/schema/Auth/security/deployment change, credential
inspection or later phase occurred. Phase 6E is still INCOMPLETE. See
[33-point recovery report](PHASE_6E_RECOVERY_REPORT.md) for counts and exact scope.

After factual documentation changes, typecheck, zero-warning lint, **432/432**
application tests and production build passed again using the existing non-working
CI compilation fixtures. No application source or generated type changed.
