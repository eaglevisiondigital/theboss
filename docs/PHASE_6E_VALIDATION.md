# Phase 6E validation

Status: local and canonical schema validation passed; application deployed; hosted
acceptance remains pending. Starting SHA is
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
