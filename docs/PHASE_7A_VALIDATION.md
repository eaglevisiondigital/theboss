# Phase 7A validation

Status: Phase 7A COMPLETE. Local validation, canonical migration, deployment,
fixed hosted non-payment acceptance and explicit cleanup passed.
Starting SHA: `da001f8b9402b48ca74e80e133946fe2f62522ed`.

Focused SQL covers direct ACL/RLS, explicit scopes/guardian/current memberships,
module independence, safe public attribution/privacy, reservation lifecycle,
server tile amounts, immutable success/provenance, strict reward thresholds,
monthly schedules, board replacement/publication, opt-in leaderboards, notification
visibility/deduplication and cleanup. Genuine races observe blocked concurrent
transactions through separate connections, not serial simulations.

Measured focused local run: 100,000 tiles generated in ten bounded requests in
1.27 seconds; bounded public page 12.2 ms and 6,943 bytes. Realistic scope fixture:
100 additional organizations, 3,100 additional campaigns, 500 participants and
2,500 additional share links. A 50-campaign scoped read returned about 304 KB in
1.84 seconds. The original eight-second statement ceiling was not increased.
These are local synthetic measurements, not production throughput guarantees.

All 445 application tests pass; typecheck and zero-warning lint pass. Production
build passed with existing canonical nonprivileged public configuration. Actual
FundraisingConsole and SupporterBoard rendered locally at 1280/768/390/320 with
expanded forms: zero page overflow, named buttons and text tile states. These
renders use synthetic settled display props; they are not hosted paid evidence.

Dependency audit: the compatible source-map-js patch is pinned at 1.2.2. Four high
reports remain in the existing development-only Next ESLint glob chain rooted in
braces 3.0.3 (GHSA-vfj7-8cjw-p6xm). No patched braces release is published at this
check. Inputs are repository-controlled patterns; no supporter/customer pattern
input reaches that lint dependency. npm suggests a Next ESLint major downgrade,
which is not applied. This existing development dependency risk is disclosed,
not reported as zero exceptions. No runtime high/critical package is reported.

All 98 SQL suites passed, reporting 17,414 assertions. A separate fresh cluster
completed the actual trusted bootstrap (28), sealed sources (33) and all 217
coordinated races. Total reported SQL/bootstrap/sealed assertions: 17,475, including
209 new Phase 7A assertions; 13 new Phase 7A races. Catalog checks were extended
for the seven new permission keys and sixteen closed tables without weakening
authorization, RLS, ACL or relationship assertions. Two harness/catalog issues
were corrected before the fresh bootstrap/concurrency stage passed.

Canonical migration history is 83 (78→83), after applying only the five validated
Phase 7A migrations. Their local filenames match the actual canonical versions;
the frozen SQL bodies were unchanged. Canonical TypeScript types were regenerated.
Live schema checks pass: sixteen tables, closed RLS/client ACLs, two finite
anonymous helper functions, no anonymous private-schema usage, no PUBLIC helper
EXECUTE, pinned search paths, all FK indexes and owner-only success ingestion.

Post-migration advisors: security INFO 169 intentional no-policy closed tables;
existing leaked-password-protection WARN 1 remains. Performance INFO 331 unused
indexes and existing Auth absolute connection allocation INFO 1. No new warning
or error was introduced. Do not remove protective FK/access indexes to silence
unused-index notices on this pre-production dataset.

Production Git CD deploy `6ac58d58b1753f0008181990` published implementation
`e96370c547c9453c5a977a8d81ac114fa852839e` at 2026-10-07 00:08:32.108 UTC.
Both implementation-head GitHub workflows passed: push 37550325414 and PR
37550330439. The PR database job completed in 11m27s; application job in 1m05s.
Final documentation-head workflow results are a required release-handoff gate.

The single hosted window began at 00:20:55.232513 UTC. Campaign/selected teams,
participant/guardian, share reset, QR, Money Board publication, competing
reservation, release, natural expiry, non-payment intents, monthly plan,
anonymous/display choice, attribution and fee-cover preference passed. Native
org/team/family navigation and reload passed; public/family/team views showed
zero page-level overflow at actual 1280/768/390/320 widths. The $5 reservation
expired at 00:31:54.125596 UTC and returned available without deleting its history.
Unrelated-child family GET and stale signed share-reset after guardian removal
were denied. Raised/claimed value stayed zero; there were no hosted paid fixtures.

Guardian removal committed at 00:32:49.575572 UTC. Administrator-first full
cleanup finished at 00:33:20.798984 UTC, ahead of target 00:55:55.232513 UTC and
hard expiry 01:05:55.232513 UTC. Finite checks confirm zero temporary authority,
active controlled publications/resources and pending controlled work. Exact
selected baseline hashes match; prior immutable sports hash and pending 5 /
official 0 remain unchanged. No runtime defect or architecture contradiction was
observed. See PHASE_7A_ACCEPTANCE_ADDENDUM.md for safe audit timeline and explicit
SQL/runtime-only limitations. Preserve all prior phase/incident history.
