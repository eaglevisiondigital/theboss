# Volunteer coordination

Phase 4B adds configurable volunteer duties, exact scoped shifts and adult volunteer
commitments. These records use the existing canonical Boss person, organization,
unit, team and event identities. A volunteer duty is an organization configuration
record, separate from the security role catalog. No security role assignment or
module activation is created by a migration.

## Records and retained history

`volunteer_role_definitions` contains organization-owned duty names/descriptions and
an active, inactive or archived lifecycle. `volunteer_shifts` selects one duty,
organization and exact organization/unit/team scope. It stores title, start/end,
capacity, instructions, location, draft/open/closed/canceled/archived status,
members/staff visibility, optional signup deadline and a configurable reminder
offset. An event link uses a tenant-qualified event and its canonical occurrence
key. Recurring opportunities require an explicit occurrence; independent shifts
remain possible without creating artificial events.

`volunteer_assignments` represents one person per shift, active or canceled. A
unique shift/person key prevents duplicate commitments. Returning to a canceled
commitment increments its version rather than deleting history.
`volunteer_assignment_history` records each actual transition, actor, request and
assignment version. Row identity and append-only history are protected; lifecycle
changes retain prior records.

## Availability and authorization

Volunteers requires a current assignment of the existing Volunteers module plus
explicit `volunteers` configuration. Self signup, reminders, head-coach management
and assistant management are independent false-default features. Attendance and
Calendar RSVP settings do not activate Volunteers. An authorized organization
manager can configure an already current module even while Volunteers is disabled;
that settings projection contains no private shifts, people or commitments.

The four potential keys are `volunteers.view`, `volunteers.signup`,
`volunteers.manage` and `volunteers.assign`. Role mapping is only potential
capability. Every operation resolves an active actual organization, exact unit or
team and current role window. Exact unit reach includes directly attached teams,
without descendant inheritance. Team-scoped role authority also requires the
person's actual current team relationship. The existing volunteer coordinator
role remains team-scoped. Head-coach management requires the explicit feature;
head coaches gain no manual assignment authority merely from management.

Adult self signup requires the self-signup feature, known age meeting the
organization minimum (18 by default, configurable only upward), an open eligible
shift and current actual context. A currently verified guardian with a dependent's
current exact team relationship can establish the adult guardian's own team
context. Household membership alone cannot do so. The guardian does not sign up
the child or another adult. Unknown ages and minors fail closed for both self signup
and staff assignment. Staff assignment/reassignment separately requires the exact
`volunteers.assign` capability and current target-person context.

An existing owner may cancel their own active commitment even if signup is closed,
the deadline passed, the self-signup feature is disabled or the prior relationship
has ended. This minimal withdrawal returns only the known commitment identity and
status; it does not reopen private shift access. Current authority is still
required for fresh private projections and notification receipts. Staff cannot
cancel another person's commitment without exact assignment authority.

## Transactions and replay

All shift edits, signups, cancellations and reassignments lock the canonical shift
row. Capacity counts are checked under that lock. Every commitment transition
updates the shift version, making higher-isolation stale snapshots conflict safely.
Capacity cannot shrink below active commitments. An occupied shift cannot move its
scope, event or occurrence until those commitments are ended. Reassignment ends
the previous commitment and activates the new eligible person's commitment in the
same transaction. No oversubscription override exists.

Caller/request receipts bind the exact command hash. Same-request retries cannot
create another assignment, history transition or notification source. Distinct
requests for the already active same person also return the same commitment.
Every replay reauthorizes the current actor and actual resource before returning
its prior result. Stale edits and conflicting request bodies return a conflict.

## Event, family and communication integration

Attached shifts retain a material context stamp of their canonical occurrence's
time/status and event venue/resource. A material event change makes the context
changed; new signup closes until authorized staff reviews the shift. Shift times
are never silently overwritten. Canceled or invalid occurrences stop new signup
and reminders. Existing commitment history remains available to currently
authorized staff.

Family Hub receives only the signed adult's own commitments. A child filter does
not grant access to another household member's commitments. The authorized shift
projection includes its current canonical scope label and attached event label.
Navigation availability checks all currently authorized enabled organizations,
independently of the selected configuration-only context. Organization and editor
scope pickers return at most 100 ordinary choices, report `options_limited`, and
may append one explicitly selected authorized context. Staff views provide
filled/unfilled counts, scoped filters and bounded names-only assignment drilldown;
DOB, contacts and credentials are excluded. All raw volunteer tables enable RLS
and remain inaccessible to client roles. Public `boss_volunteers_read` and
`boss_volunteers_mutate` invoker wrappers enter private, finite, caller-bound
implementations that validate live Auth and the canonical person.

Safe audits use resource IDs, lifecycle/version and material-change metadata.
Shift creation and edits also record prior/current capacity and volunteer role
IDs; a newly created shift has null prior values. Private instructions and other
free text are excluded. Role or title edits mark assigned duties materially
changed for the existing notification pipeline; capacity-only edits retain audit
evidence without a volunteer change alert. Notification sources and delivery reuse Phase
4A. Current eligible assignments authorize confirmations, change/cancellation
receipts and bounded reminders; coordinator cancellation alerts require current
exact scoped management. Reminder preparation requires an enabled reminder feature
and authorized shifts within a finite window. Selected-volunteer announcements
reuse Phase 4A announcements and additionally require existing scoped announcement
permission and Messaging availability. They introduce no independent chat system.

## Bounded Phase 4B scope

There is no waitlist, mandatory volunteer quota, billing, capacity override, kiosk,
financial workflow or advanced reporting. Waitlist behavior is deferred because no
promotion/expiration policy has been approved. No scorekeeping, fundraising or
other later module is implemented merely because a duty can use a configurable
name.

## Validation checkpoint

The full disposable PostgreSQL run passed all 151 volunteer assertions. Seven
synchronized two-connection races passed for last-slot capacity at Read Committed,
Repeatable Read and Serializable isolation; same-person signup; same-request
retry; cancellation freeing capacity; and capacity narrowing. The integrated
attendance/volunteer notification and selected-volunteer communications suite
passed 100 assertions. All local fixtures are synthetic.

The volunteer migration is applied and read-only canonical schema checks passed.
Post-migration advisors report no new warning. Hosted restricted-role capacity
management was verified. Positive adult signup, assignment/reassignment and family
commitments remain SQL-only because approved adult candidates have unknown DOB;
no DOB was changed. Hosted selected-volunteer announcement/attachment checks and
the final post-fix retest remain incomplete. Final temporary-authority restoration
is verified with zero residual access and the original administrator restored.
These outcomes are tracked separately in
[Phase 4B validation](PHASE_4B_VALIDATION.md).
