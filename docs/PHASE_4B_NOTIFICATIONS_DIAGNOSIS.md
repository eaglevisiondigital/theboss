# Phase 4B Notifications blocker diagnosis

October 3 follow-up: the authorized [bounded performance investigation](PHASE_4B_PERFORMANCE.md)
subsequently reproduced the Notifications timeout, validated narrow SQL evaluation
reuse, applied its append-only migration and verified bounded restored reads.
Historical investigation limits below describe the preceding checkpoint. Full
restricted hosted acceptance remains incomplete; no new authority window was
opened by the performance assignment.

This focused investigation starts from `ce4232fbb4df56dc31f80bb63c8ad66c3603aded`
on `build/boss-platform-v1`. It uses source review, bounded value-free incident
logs and the restored administrator's read-only hosted session. No new acceptance
window, role, relationship, module activation or attendance/volunteer mutation is
authorized or performed. Phase 4B hosted acceptance remains incomplete.

## Original incident: confirmed database statement timeout

On October 3, 2026, the incident batch started at approximately 13:36:42 UTC.
Both `boss_notifications_read` requests returned HTTP 500, with origin times of
8,135 and 8,124 milliseconds. The concurrent `boss_attendance_read` returned
HTTP 500 at 8,125 milliseconds. PostgreSQL recorded SQLSTATE `57014` at
13:36:50.924, .932 and .934. Value-free context checks associate those errors
with Attendance, Notifications, attendance notification visibility and Calendar
occurrence expansion. Role metadata confirms an eight-second statement timeout
for `authenticated` and `authenticator`; JIT is off. No timeout was changed.

Other reads in that batch succeeded: administration, Calendar, Volunteers,
Registration and Communications. The preceding 25-minute bounded window contains
29 successful Notifications reads, with a maximum origin time of 6,003 ms.
Twelve Auth user requests returned HTTP 200, with origin times of 28–138 ms.
This evidence identifies the original failure as a Supabase/PostgreSQL request
timeout. It does not establish a browser transport failure, Netlify render crash,
invalid session, incorrect organization authority or architecture contradiction.

The layout concurrently loads seven projections, including Notifications summary;
the Notifications page loads its own inbox. Notifications source visibility is
repeated during organization discovery, inbox selection and unread counting.
Attendance visibility expands recurring occurrences and resolves attendance
context. These are possible contributors to expensive reads, not a proved
function-level implementation defect. Isolated post-cleanup read-only probes of
the archived controlled event took approximately 97 ms for occurrence lookup and
154 ms for attendance context. Current restored baselines can short-circuit
checks, so these probes do not reproduce the former guardian workload or prove
the timeout fixed. No speculative SQL optimization or retry was added.

## Organization and header symptoms

`app/app/layout.tsx` authenticates the session before loading its independent
projections. The administration projection succeeded during the incident.
Notifications organization options come from the Notifications RPC, not a
separate default-organization lookup. The page forwards a valid organization
filter; the SQL projection authorizes the context against current features,
scope and relationships.

The original loader replaces any error with an empty unavailable projection.
That projection has no organization options, records or actions and sets
`availability.in_app=false`. The drawer then renders nothing. The unavailable
page, missing organization choices and absent drawer therefore share the failed
Notifications projection path. They do not demonstrate failure of the independent
administration/header projection.

The RPC uses POST. The pinned client does not automatically retry that method;
there is no additional application RPC deadline or retry. A network exception or
`57014` stays an operational unavailable state. Successful feature-disabled
data remains separate. No transient failure is classified as a policy denial.

## Separate current defect: restricted context displayed as an outage

After cleanup, a read-only restored-administrator request with the ended controlled
organization filter returned Notifications HTTP 403 in 235 ms, while the separate
unfiltered header summary returned HTTP 200 in 259 ms and all other shell reads
succeeded. The SQL explicitly raises `PT403` for a requested organization outside
the current authorized Notifications contexts. The original loader incorrectly
displayed that denial as temporary unavailability. Removing the organization
filter loaded the expected empty Notifications page, and a full reload succeeded.

The narrow application correction classifies exact `PT403` as an empty denied
projection and displays “Notifications are restricted in this organization
context.” Returned records, actions, private error details and organization
labels are discarded. Database cancellation, other codes, transport exceptions
and malformed projections continue to use unavailable handling. Independent
successful header summaries are preserved. No SQL, scope, feature policy, Auth
setting, timeout, retry, fallback organization or provider was changed.

Six new reader/render regressions cover denial without record/action disclosure,
non-denial errors, transport/malformed failures, successful projection, disabled
features and independent summary/inbox results. Two new regressions failed with
the original classification; all six pass with the correction. Final isolated
validation passes typecheck, zero-warning lint, all 218 application tests without
skips and the production build. All 160 source/config files match the validated
snapshot. The public login page returns HTTP 200. Production publication and
post-deployment read-only evidence follow below.

## Publication and restored-administrator verification

The correction is committed and pushed as
`8ac5527e0961fb66a07be2533924d5906023147d`. Dedicated Boss platform production
deployment `6ac131268ba1670008889049` is ready and published at
**2026-10-03 16:45:54.164 UTC**, on the existing `build/boss-platform-v1`
Git-based release path. No Netlify proxy credential or deployment-environment
value was retrieved or reused.

Read-only production checks with the restored original administrator verify:
the ended organization filter renders the corrected restricted-context text with
no records/actions; the unfiltered Notifications inbox loads with no unavailable
notice; a full reload preserves that result; navigation to Home loads the
controlled organization picker and administrator management tools; returning to
Notifications succeeds. The summary drawer remains absent under the restored
feature-disabled baseline, as expected; no positive drawer scenario is claimed
from these checks. Safe proof is retained outside Git. These checks exercise no
notification preference/read mutation and no attendance/volunteer mutation.

## Remaining acceptance and stop boundary

Still **UNVERIFIED DUE TO HOSTED ACCESS FAILURE**: canceled occurrence and canceled
Family Hub/reminder exclusion; guardian deadline/missing reminder receipt and
replay; remaining context-change/reconfirmation notification receipt; remaining
restricted-role/guardian isolation and forged event/occurrence/participant/team/
unit signed mutations; Calendar and remaining interactive 320px views; final
restricted-session navigation/reload stability. Restored-administrator smoke
checks do not certify those restricted scenarios.

Still **UNVERIFIED DUE TO POLICY/ELIGIBILITY LIMITATION**: positive adult volunteer
self-signup, duplicate/full-capacity signup, commitment cancellation, eligible
assignment/reassignment and resulting counts, shift-change recipient receipt,
selected-volunteer communication/attachment receipt and Family Hub commitments.
Both reviewed candidates retain unknown adult eligibility. No DOB, candidate,
role, policy exception or commitment was fabricated.

A further controlled acceptance window is not opened or recommended as a
repetition of the failed run. The current display correction does not remove the
original query-performance risk. A separately authorized bounded investigation
or reproducible performance test should establish adequate read behavior before
another restricted hosted window. The main Boss Chat retains that decision.

The four prior windows remain closed with their recorded cleanup proof. This
diagnosis introduces no temporary authority, controlled business fixtures or real
youth/customer data. No credentials, Auth tokens, session values or privileged
keys were retrieved or exposed. The historical Netlify proxy exposure remains
disclosed separately; its value was not reused or reproduced. PR #3 remains
OPEN, DRAFT and UNMERGED. No later phase is started.

Primary reference: [Supabase statement timeouts](https://supabase.com/docs/guides/database/postgres/timeouts).
