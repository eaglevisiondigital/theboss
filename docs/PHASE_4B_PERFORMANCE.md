# Phase 4B bounded database performance investigation

## Subsequent Phase 4B closure

Main Boss Chat closed Phase 4B as COMPLETE after reviewing the full acceptance
record and accepting the residual forged-hosted-request tooling limitation.
The adult volunteer eligibility limitation remains approved. Neither limitation
is a known production defect or a new hosted pass.

The Decision A performance investigation and its original evidence below are
unchanged. The later restricted guardian acceptance recorded successful reads
without PostgreSQL `57014`; see [the final acceptance record](PHASE_4B_FINAL_HOSTED_ACCEPTANCE.md).
The eight-second limit was not increased. This documentation closure repeats no
investigation, opens no acceptance window and changes no implementation/security
policy. Historical timeout/remediation evidence and proxy exposure remain retained.

See [the owner closure decision](DECISIONS.md#phase-4b-closure-by-main-boss-chat).
All original investigation text below remains verbatim historical evidence.

Starting branch: `build/boss-platform-v1` at
`c6fcd4b41bde66ea95bdedfd9df9345c47bfac97`. This investigation follows the
confirmed October 3 PostgreSQL `57014` incident; the separately published
Notifications `PT403` display fix remains a different issue. Full restricted
hosted acceptance is not resumed by this assignment.

## Exact paths and measured repeated work

The authenticated layout concurrently loads Administration Home, Calendar
personal, Registration family, Communications summary, Notifications summary,
Attendance family and Volunteers upcoming. The Notifications page adds a filtered
inbox read. Calendar defaults to UTC midnight/14 days; Attendance and Volunteers
use now/30 days. The Notifications summary's existing SQL limit of eight rows
remains unchanged even though the client requests five.

Both Notifications reads enter `boss_notifications_read` → private
`notifications_read` → organization discovery, inbox and unread-count scans.
Recipient/event joins, active in-app module gates and
`notification_source_visible` reauthorize each source. Attendance sources enter
`attendance_notification_visible` → canonical `attendance_occurrence` → Calendar
`calendar_occurrences`/`calendar_expand` → `calendar_valid_timezone`. Source
visibility also checks context, status/expiry, source-dated roster/guardian
relationships, current `attendance_subject_authority`, features and responses.
Organization discovery, inbox and unread scans remain independent; unread counts
continue to ignore inbox category/pagination filters.

Attendance enters `boss_attendance_read` → `attendance_read` → current identity,
`attendance_organization_known`, team/unit/child options, canonical occurrences,
subjects, `attendance_subject_authority`/`attendance_permission`,
`attendance_guardian`, configuration/features and deadline/response projection.
Calendar relationship/target checks remain distinct from Attendance response
capability. Household membership and potential role capability do not substitute
for current exact scope and guardian authority.

Three specific expression-evaluation defects are proven by function counters and
exact-body plans:

- The flattened context expression invokes the same occurrence resolver three
  times for start, end and status. Source visibility first resolves the occurrence
  independently, yielding four expansions per source check.
- Configuration's flattened CTE performs sixteen identical coordination-module
  lookups per normalization. Each feature call normalizes configuration twice.
- Visibility already holds the canonical occurrence needed for its fingerprint,
  but resolves it again through the context helper.

In the four-owned-event baseline, a Notifications summary made 60 visibility
checks and 240 occurrence expansions. Timezone catalog scans consumed 4,935ms of
5,525ms. Attendance made 2,769 normalizations and 44,304 coordination lookups;
individual total time was approximately 2.93–3.00s. Recurrence generation is
bounded and the fixture contains only sixty occurrences; no unbounded recurrence
explosion, missing-index root cause or lock wait was established.

## Reproducible workload and timing

The private disposable PostgreSQL 17.11 fixture has three organizations, twelve
units and teams, 180 participants, seventeen synthetic Auth identities, 24 events
(12 recurring), sixty occurrences, 180 attendance sources and 24 existing
responses. One guardian has two children on two exact teams. Eight relevant
events represent four weekly four-occurrence series plus four singles: twenty
monthly appointments, sixty guardian notifications and 180 other-recipient
notifications. One canceled exception leaves nineteen Attendance occurrences.
Fifty-five notifications remain visible; five read rows leave fifty unread.
There is no canonical test grant or copied customer dataset.

Baseline and candidate run sequentially with JIT disabled and an unchanged
8-second statement limit. Each has twelve individual reads and three batches of
eight concurrent shell/page reads. Other module resources are empty in this
fixture: their requests measure shell completion, not module-volume performance.

| Read | Baseline individual ms | Candidate individual ms | Baseline concurrent ms | Candidate concurrent ms |
| --- | ---: | ---: | ---: | ---: |
| Notifications summary | 8,004–8,017, canceled | 5,100–5,297 | 8,008–8,025, canceled | 5,864–5,932 |
| Notifications inbox | 8,001–8,016, canceled | 3,033–3,178 | 8,012–8,019, canceled | 3,882–3,921 |
| Attendance family | 3,338–3,435 | 1,771–1,906 | 3,671–3,822 | 2,013–2,057 |
| Calendar personal | 1,383–1,431 | 1,391–1,421 | 1,569–1,639 | 1,552–1,591 |

All twelve baseline Notifications samples canceled with `57014`; all 36 final
candidate reads succeeded. Concurrent batches completed in 5,893–5,964ms.
Previously successful baseline/candidate reads retain identical cardinalities.
Canceled Notifications have no completed baseline result; preservation is
supported by independently expected fixture counts and semantic regressions.
The unfiltered summary still performs 194 visibility checks; the fix reduces its
occurrence expansions to 194 instead of four per check. No persistent cache is
introduced. Residual timezone/authorization work remains measurable.

The first three-function prototype improved the smaller summary to 3,286ms and
Attendance to 1,548ms, but both larger Notifications reads still canceled. The
final visibility reuse is necessary; those prototype failures are not hidden.
A separate initial profiler startup failed because the cleared macOS environment
lacked a valid locale; the harness now supplies `LC_ALL=C`, and that cluster was
removed without running a workload. The final smoke summary's 5,499ms is retained
as an additional cold diagnostic sample outside the matched three-repeat table.

The local fixture reproduces Notifications cancellation, not the original
Attendance cancellation. It proves Attendance's independent multiplication and
cost reduction; the historical simultaneous Attendance failure is consistent
with shared expensive work and contention, but its exact incident scheduling or
resource pressure is not proven. These bounded measurements are not a production
SLA or unrestricted scale guarantee.

## Narrow remediation and constraints

One append-only migration adds a private, stable invoker fingerprint helper and
replaces four private functions. Materialized request-local CTEs evaluate context,
configuration and feature inputs once; source visibility fingerprints its same
canonical occurrence. All original hash fields, epoch conversions, feature rules,
source/current relationship checks, status/expiry gates and response predicates
are retained. The new pure helper has no table/auth lookup and no client/service
execute privilege. Existing interfaces, ownership, current authorization and
revocation behavior remain intact.

No historical migration, RLS policy, role mapping, index, timeout, persistent
cache, retry, recurrence rule, public RPC or application projection was changed.
Existing event/exception keys, source/recipient/delivery joins, unread filters,
roster and guardian indexes cover their predicates. No speculative index was
added; no additional write/storage consequence follows from an index change.

Deterministic rollback regression coverage includes 56 assertions: original
context/configuration/feature equivalence, moved/canceled/invalid/retained-single
occurrences, age/type boundaries, private ACL/volatility/search paths, one context
lookup, one coordination lookup per normalization, one normalization per feature,
zero normalization when Calendar is disabled and one occurrence per visible
source. Tests compare function-count deltas rather than elapsed-time-only limits.

## Final validation and canonical proof

Fresh disposable validation passed 7,202 assertions across 22 SQL suites plus
28 real operator-bootstrap assertions: 7,230 total. Phase 4B contributes 750:
Attendance 88, integrations 100, performance 56, security 355 and Volunteers 151.
The new private helper adds four existing dynamic security assertions beyond the
previous 351. All 34 two-connection races pass, including three Attendance and
seven Volunteers races. Full-validation and helper-plan clusters were removed.
Typecheck, zero-warning lint, all 218 application tests without skips and the
production build pass against 160 exactly matching application source files.

Exact-body EXPLAIN/BUFFERS proof records context 66.703→22.193ms with three→one
occurrence/timezone calls; configuration 0.924→0.202ms with sixteen→one module
lookups; feature 0.781→0.376ms with two→one normalizations. The feature comparison
uses the now-correct configuration helper on both sides to isolate feature
multiplicity. Materialized CTE scans evaluate one row; the configuration aggregate
uses one 24kB batch. No spill or lock contention was established. The small fixture
may select sequential scans; no evidence supports index changes.

Append migration `20261003175623_phase4b_read_evaluation_reuse.sql` was applied to
canonical `the-boss-platform` (`ilykgwgmxtrrikreacrz`) at October 3 17:56:23 UTC.
The CLI-created file was aligned to the version assigned by the managed migration
tool, without changing its SQL. All thirty versions/names match in order. Recorded
SQL MD5 `913c859b8cc213c76052b0b800b5b76b` and all five function-body hashes match
local source. Catalogs, public tables, role capabilities, four invoker bridges,
closed raw RLS tables, indexed foreign keys and source triggers remain unchanged;
the private coordination helper count becomes 73. Regenerated public database
types exactly match the checked-in 151,779-byte file.

Three read-only canonical context probes against one archived CONTROLLED TEST
event complete in 54.614–56.349ms and return only fingerprint-valid booleans.
Eight retained controlled attendance sources are currently invisible to the
controlled account. Before/after residual checks confirm exact module and
relationship baselines, original administrator restoration, zero temporary role,
coach, guardian, household or child organization authority, zero pending fixture
work and zero unexpected/unarchived Phase 4B fixtures.

Three ordinary hosted rounds of Notifications, Attendance and Calendar load;
Notifications reload and original administrator Home also pass. Value-free
aggregate logs for October 3 17:57:00–18:00:15 UTC show all HTTP 200:

| Canonical hosted RPC | Requests | Origin range ms |
| --- | ---: | ---: |
| Notifications summary/inbox combined | 16 | 62–294 |
| Attendance | 16 | 99–360 |
| Calendar | 15 | 1,582–3,211 |
| Administration | 13 | 230–1,004 |

Browser navigation/observation includes automation overhead: Notifications
2,213–5,511ms, Attendance 2,146–3,199ms, Calendar 3,040–3,990ms and Notifications
reload 2,259ms. These are distinct from origin timings. Post-migration PostgreSQL
logs through 18:00:15 contain zero `57014`; final disposable reads likewise have
zero cancellations. Historical and baseline/prototype cancellations remain
reported above.

Hosted Notifications/Attendance use the restored feature-disabled baseline;
they do not test positive restricted guardian performance under active modules.
Calendar includes legitimate existing controlled schedules. No restricted
acceptance window or temporary canonical authority was created. Local positive
load, canonical shared-helper proof and normal restored hosted reads are the
explicit evidence boundary; every outstanding signed acceptance case remains
open.

Fresh advisors retain 57 intentional closed-RLS informational notices and one
existing [Auth leaked-password-protection warning](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
Performance advisors retain 114 [unused-index informational notices](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
and one existing Auth connection-allocation informational notice. No new warning,
Auth change or speculative index removal was made.

Decision **A: ROOT CAUSE PROVEN + REMEDIATED + READ STABILITY VERIFIED** applies to
the bounded evidence above, with the unreproduced original Attendance cancellation
and untested active restricted hosted session explicitly retained as limitations.
A separately authorized, narrow Phase 4B acceptance window is recommended to
validate the remaining signed scenarios. This investigation does not open it,
establish an SLA or declare overall Phase 4B acceptance complete.

No password, Auth token, session credential, privileged key or deployment
credential was retrieved or exposed in this investigation. Existing browser
authentication supplied normal signed requests without inspecting its material.
Only synthetic/disposable and existing CONTROLLED TEST records were used. The
historical Netlify proxy incident remains disclosed in the acceptance history;
its value was not reused or reproduced. No timeout/security limit was weakened,
no later phase was started, and work stops at this performance handoff.
