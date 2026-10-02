# Attendance and RSVP

Phase 4B adds independently configured attendance to the existing Calendar
activation. Calendar-only organizations retain their existing behavior. Enabling
Calendar does not enable attendance, RSVP, participant self-response, guardian
RSVP, reminders or check-in. The finite `attendance.configure` command merges
prefixed attendance settings without altering Calendar scheduling policy.

## Canonical records

`event_attendance_settings` augments the canonical event's existing `rsvp_mode`
with participant/staff audience, optional absolute or relative deadline,
lock/allow-late behavior and keep/needs-reconfirmation change policy. Relative
deadlines apply to each occurrence's effective start. Absolute and relative
configuration cannot coexist. RSVP modes remain not-required, optional and
required; an event never requires RSVP solely because attendance is enabled.

`attendance_responses` has one record per canonical event, original occurrence
key, person and participant/staff subject kind. Participants retain canonical
identity independently of an Auth account. Staff availability is represented as
a distinct subject kind, with its own roster semantics. Attending, not-attending,
maybe, pending and unknown are response states. Optional private reasons/notes
and signed minute differences for arrival/departure remain bounded.

A response captures the canonical responder and, where applicable, the exact
authorizing guardian relationship. A current shared household may supply a
historical context ID; it never supplies authority. Response versions and
append-only `attendance_response_history` retain ordinary changes and material
context changes. Current relationships gate projections but do not destroy prior
responses when seasons, rosters or guardian relationships end.

`attendance_checkins` and append-only check-in history provide only expected,
checked-in, absent, late and excused states. No kiosk, biometric, location-tracking
or advanced check-in workflow is implemented. No attendance analytics, scoring,
statistics or Game Center is included.

## Authority

The public invoker RPCs delegate to private caller-bound functions with empty
search paths. A confirmed, current non-anonymous Auth session and active canonical
account are required. All six public attendance tables have RLS and no raw client
read/write grants. The private operation-receipt table is also closed with RLS.

Eligible subjects come from current active event-target relationships: exact team
rosters; teams in an exact unit; or participant organization membership/rosters for
an explicitly organization-targeted event. Inactive organizations, units, teams,
participants and ended membership windows close eligibility. Public schedule
visibility and knowing event, occurrence or person IDs do not authorize RSVP.

Guardians require the dedicated false-default `can_respond_attendance` flag on a
current verified explicit guardian relationship, the guardian-RSVP feature, the
exact eligible dependent and the current event/roster context. Existing register,
waiver, payment, document and communication flags confer no attendance authority.
Household membership alone never supplies guardian capability.

Participant self-response additionally requires an active canonical account, an
explicit feature and a known age meeting the configured minimum. The default
minimum is 18 and configuration cannot lower it below 18. Missing or malformed
age policy fails closed. Minor self-response requires a future reviewed product
policy; this phase makes no consent decision. Staff self-response requires the
exact current staff/coach/volunteer roster context.

Potential role permissions remain separate from actual resource authorization.
Staff summaries include only subjects reached through currently authorized exact
event targets. A coach viewing a multi-team event does not see another team's
roster. Mutations require authority at every event target. Program/unit scope
never implicitly includes sibling or descendant units. Head-coach and assistant
management are separately disabled by default; broad scoped organization/unit
administration and exact team-administrator authority remain permission gated.

Private absence notes and arrival/departure details are projected only to the
currently authorized subject/explicit guardian or staff with full event attendance
management. Scoped view-only staff receive counts, names and status without those
fields. Historical drilldown requires current attendance-view permission at every
canonical event target; private historical notes additionally require management.

## Deadlines, retries and event changes

Responses before a deadline behave normally. A lock policy returns a safe conflict
after the deadline. An allow-late policy accepts and records an explicit late
marker. Staff may request a deadline override only with current full event
management; the safe audit records the override marker and omits note content.

Operation UUIDs bind the canonical actor, complete normalized JSON command hash
and safe result. Same-input retries reauthorize current features, relationships,
occurrence, deadline and scope before returning a receipt. Changed input with the
same UUID conflicts. Event-row locking serializes RSVP versions with concurrent
Calendar changes; optimistic versions prevent lost updates. Response, immutable
history, receipt and safe audit write atomically.

The finite existing Calendar occurrence engine verifies original local keys,
including moved exceptions. Different recurring keys retain separate responses;
a canceled effective occurrence supplies no RSVP action. Material date/time,
venue/resource, lifecycle or occurrence changes compare a canonical context
fingerprint. `needs_reconfirmation` policy records a sticky marker and immutable
snapshot; moving back does not revive an old confirmation. `keep` preserves the
response deliberately. A non-recurring event preserves its canonical original attendance key across
rescheduling while displaying current effective times. Recurring series edits
that remove a key retain history and never reassign a response to another
recurring occurrence. Switching between single and recurring modes retires old
key pins while preserving responses and their immutable history; a retired key
cannot manufacture a new occurrence.

## Notifications and interfaces

`attendance_requests` supplies finite event/occurrence request sources for Phase
4A notification ingestion: requested, deadline, no-response and context-changed.
The source ID and revision deduplicate repeats. Recipients require current and
source-dated exact roster/guardian capabilities; multi-child/team paths union to
one canonical person. Broad administrator read power does not subscribe someone.
Current source/fingerprint and response state are rechecked before inbox/delivery.
Canceled occurrences generate no outstanding-response reminder. Notification
content never includes private absence reasons or notes. Provider delivery remains
under the existing independently configured Phase 4A controls.

`boss_attendance_read` supplies bounded family/staff occurrence projections,
authorized child filtering, missing-response/status totals and per-row capabilities.
`boss_attendance_mutate` supports only attendance configuration, event RSVP
configuration, response, light check-in and bounded reminder preparation. Reads
cover at most 93 days, 1,000 occurrences and 1,000 subjects per occurrence;
history is limited to 200 snapshots, exact units to 100 and exact
authorized team options to 200. The organization picker exposes its bounded first
100 plus an independently authorized explicit selection (at most 101), with an
`options_limited` marker; a platform administrator can operate a selected tenant
when the total tenant set exceeds the picker page. Overflow requires a
narrower filter instead of silently omitting records. Tenant/event/person indexes
support next-response and summary queries. Family Hub and coach views reuse these
same projections; client hiding is never the security boundary.

The full disposable PostgreSQL run passed all 88 `phase4b_attendance.sql`
assertions covering A-O, features, current Auth/scope, note privacy, raw mutation
closure, history and safe audit markers. Three synchronized two-connection races
passed for receipt retries, optimistic response conflicts and response-versus-
Calendar event-row serialization. These are database checks; they do not claim
hosted signed-HTTP acceptance. Local fixtures use synthetic people and require no
live grants, credentials or customer data.

The attendance migration is applied to the canonical Boss project. Read-only
verification confirms closed raw/RLS access, RPC/helper ACLs and search paths,
foreign-key index coverage and the non-null default-false guardian flag with zero
enabled flags at verification. Controlled hosted family/restricted-role actions
were partially verified; the remaining hosted matrix and post-fix retest are
incomplete after browser unresponsiveness. Final temporary-authority restoration
is verified with zero residual access and the original administrator restored.
See [Phase 4B
validation](PHASE_4B_VALIDATION.md) for the current checkpoint.
