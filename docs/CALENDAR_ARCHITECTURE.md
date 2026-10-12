# Events and calendar core

Phase 3A adds Calendar to the existing Boss identity, organization and exact-scope
authorization foundation. Calendar is enabled independently from Sports. One event
ID is canonical. Organization, exact unit, team and personal/family calendars are
projections. Assigning three teams creates one event and three associations.
Deployment and validation evidence is recorded in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

## Records and lifecycle

| Record | Responsibility |
| --- | --- |
| `events` | Tenant, title/description, type, start/end, timezone, all-day/arrival, status, visibility, publication, venue/resource, instructions, RSVP, audience, recurrence, actor/lifecycle fields and version |
| `event_types` | Centrally extensible catalog with twelve initial schedule types |
| `event_targets` | Organization, exact unit or one/many team associations to the same event |
| `venues`, `venue_resources` | Reusable facilities and courts, fields, rooms or other spaces |
| `event_game_details` | Same-tenant Boss opponent or external name, home/away/neutral and schedule status |
| `event_occurrence_exceptions` | Durable changes keyed by the original local occurrence time |
| `event_reminders` | Timing, audience and enabled configuration for future delivery |

Tenant-qualified foreign keys protect associations, facilities, internal opponents
and exceptions. All eight tables have RLS and authenticated SELECT-only access.
Anonymous table reads and all client table writes remain closed.

Statuses are draft, scheduled, confirmed, canceled, postponed, completed and
archived. Normal workflows retain canonical history. Event updates use optimistic
versions, including updates to one occurrence. Rescheduling updates every
permission-aware view of the same event. A whole-series draft, cancellation,
postponement, completion or archival takes precedence over older exception status;
an older scheduled exception cannot revive a canceled series.

Venue/resource publication is separate from event publication. Private facility
IDs, addresses and instructions are excluded from general published projections.
Precise coordinates, scoring, statistics and Game Center are absent.

## Recurrence and exceptions

Rules support daily, weekly with selected ISO weekdays and monthly recurrence,
interval 1-52, and either a count of 1-1,000 occurrences or an inclusive local end
date. The complete series must fit within five years. Stored rules contain an
explicit interval; weekly rules without selected days resolve to the anchor's ISO
weekday. These defaults are normalized before comparing a proposed series edit
with its stored rule.

Reads cover at most 93 days and 1,000 occurrences. Overflow requires a narrower
range rather than silent truncation. Duration is bounded to 31 elapsed days and
arrival to seven elapsed days before start. No future occurrence table is populated.

Expansion preserves local wall-clock start/end duration in the event's IANA zone.
Monthly dates that do not exist are skipped. DST gaps at either boundary are
skipped, and only valid emitted occurrences count toward a count limit. Ambiguous
times use PostgreSQL's post-transition offset, selecting the later instant in the
validated transitions. Tests cover Chicago/New York, Dublin's negative DST,
Lord Howe's half-hour transition, Kyiv's political shift and Kwajalein's date-line
shift. Recurring anchor inputs must agree with this interpretation. Arrival retains its elapsed lead.
One-time inputs carry explicit UTC offsets. All-day bounds, including single
occurrence changes, must be local midnight. Overlap uses half-open `[start,end)`
intervals and includes multi-day events that started before the requested range.

Count-limited rules rank at most five years of date candidates. End-date rules seek
from the requested range with duration lookbehind. Indexed tenant/date envelopes
select events before expansion; moved exceptions have a separate indexed overlap
path. This avoids loading all tenant history or persisting thousands of future rows.

An occurrence key is its original local timestamp, independent of rescheduled
start/end. One exception can change time, arrival, status, title or instructions
without copying the event. Active keys are unique. An exception start may fall
from 31 days before the series anchor through five years after it; its end may
extend a further 31 days. Internal expansion accepts a bounded five-year plus
95-day review range for duration/exception buffers; public and authenticated
calendar reads retain the 93-day limit.

With active exceptions, changing series start, end, timezone or recurrence requires
an explicit `reset_exceptions` choice. The transaction archives active exceptions,
retains their rows, updates the same canonical event and audits prior/new times and
the archived count. No silent reset occurs. Title, instructions and lifecycle
changes can preserve existing exceptions. Conflict preview uses effective canceled
and rescheduled occurrences; a title edit cannot falsely reserve a canceled slot
or miss a moved slot. “This and following” splitting is deferred.

See [PostgreSQL timestamp policy](https://www.postgresql.org/docs/17/datetime-invalid-input.html)
and [iCalendar recurrence conventions](https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10).
The supported finite subset is not a general RFC 5545 parser.

## Authority and projections

| Existing role | Added potential calendar capability |
| --- | --- |
| Super/platform administrator, organization owner/administrator | View, create, manage, publish and conflict override within actual scope and feature policy |
| Athletic director | View, create and manage within assigned organization |
| Program/sport administrator | View, create and manage within exact assigned unit |
| Head coach | View; create/manage for assigned team when head-coach management is enabled |
| Assistant coach, team administrator, team staff | View |
| Other existing roles | None |

Permission mapping defines potential capability. Every actual current and proposed
target must authorize a mutation, with active resource, role/window, tenant,
module and feature checks. Exact units do not inherit descendants. Creator
identity does not bypass mutation permission. Organization-wide read authority
can retain history attached to an inactive team/unit while its organization and
Calendar remain active. Draft/private history requires management authority.
Inactive unit/team scope cannot schedule or acquire relationship-based access;
calendar mutations require every target active, including for platform roles.
An inactive organization or Calendar activation closes the calendar runtime.

Personal views use active organization/team relationships. Family views add
active participant/team relationships reached through a currently verified,
active explicit guardian relationship. Household membership alone confers no
such authority. Shared events are deduplicated across children; a child filter
narrows actual authorized relationships. Existing canonical account policy governs
participant login. This phase creates no age or consent policy.

Audience labels describe intended attendees and grant no authority. They are
organization, unit, team, staff, coaches, guardians, participants and public;
reminder configuration excludes the public label.

| Visibility | Runtime boundary |
| --- | --- |
| `public` | General access requires explicit publication, active organization/Calendar and public-schedules feature; anonymous callers receive only the fixed safe projection |
| `authenticated` | Explicit publication permits a safe schedule projection to unrelated authenticated canonical Boss users; anonymous readers receive nothing |
| `member` | Relevant active organization/team or verified guardian-dependent relationship, or an applicable scoped read permission |
| `restricted` | Applicable scoped permission; a membership or audience label alone is insufficient |
| `private` | Management authority, or a creator who still holds applicable scoped view authority |

Drafts require stronger management/creator scope. General published access never
exposes private event instructions, arrival, descriptions, facilities, reminder
configuration, family records or private target labels. The full-row RLS boundary
remains stricter than general schedule visibility. Publication operations require
`events.publish` and the public-schedules feature for both public and authenticated
audiences. A UUID, URL, filter choice or public team label creates no membership.
Following is neither implemented nor used as authority.

## Trusted changes and conflicts

Public invoker RPCs delegate to private, caller-bound functions with empty search
paths. Sensitive reads, preview and mutation require a confirmed, non-anonymous,
current Auth user/session plus active canonical identity. The application uses its
existing authenticated user client, with no privileged credential.

`boss_calendar_mutate` accepts one finite `{operation,input}` command and request
UUID. Operations are event create/update/exception, venue create/update, resource
create/update and calendar configuration. Input allowlists, tenant-qualified
references, features and versions protect the event, associations, game/reminder
settings, private receipt and audit in one transaction. Separate calendar receipts
bind actor/request ID and the canonical input hash. Identical retries reauthorize
current resources and capability; changed input with the same ID fails safely.
`boss_calendar_preview` validates the same proposed event/exception before save.
Errors use safe authentication, authorization, conflict or validation responses;
raw SQL errors are not exposed.

Conflicts compare scheduled/confirmed effective occurrences across the complete
finite series, including conflicts beyond the visible 93-day calendar window.
The same venue resource or explicitly targeted team is actionable. Shared coach
or participant conflicts derive current active roster relationships across
explicit team attachments. A broad organization audience does not automatically
conflict with every team. Draft/canceled/postponed/completed/archived occurrences
do not reserve resources. Canceled original slots can be reused; moved slots are
checked at their effective time.

The UI previews warnings before finalization. Mutation rechecks under transactional
organization serialization, so stale previews cannot authorize concurrent occupied
resource writes. Explicit override requires `events.override_conflict` at every
proposed target and the organization's conflict-overrides feature. Hidden conflicts
return only a Busy marker and occupied times. Ordinary schedulers cannot override.
The audit records actual conflict references within the protected boundary.
Serialization or retry conflicts leave no partial event, receipt or audit writes.

Audits capture operation, actor, resource, scope, request, changed field names,
prior/new times, targets, visibility/publication/status, recurrence, exceptions and
overrides. The existing audit UI exposes safe metadata rather than unrestricted
before/after JSON. Normal event/exception history is preserved.

## Module controls and future integrations

Calendar activation uses the existing authorized module workflow independently
of Sports. `calendar.configure` accepts only these Boolean settings and requires
organization-wide `organization.manage`:

| Configuration key | Default after activation |
| --- | --- |
| `organization_calendar`, `team_calendar`, `recurrence`, `conflicts` | Enabled |
| `public_schedules`, `head_coach_management`, `conflict_overrides`, `attendance` | Disabled |

Disabled features close their relevant server paths and permission-derived UI
controls. Public-schedules gating closes the anonymous public projection and new
publication operations. Already published authenticated schedules retain signed-in
visibility after that setting is disabled; disabling Calendar closes both. Existing
recurrence history remains queryable when recurrence creation/editing is disabled.
Calendar configuration is distinct from the unfinished generic
feature-flag precedence engine. Attendance cannot be enabled in this phase.

RSVP supports not required, optional and required, without response endpoints or
analytics. Each event accepts at most eight reminder configurations, with offsets
from zero through 10,080 minutes before the event. No guardian response authority is inferred from profile/registration
flags. Reminder timing, audience and enabled state are configuration only; future
delivery belongs to one centralized notification system. Stable event IDs,
original occurrence keys, timezone and retained exceptions support later ICS
export/subscriptions. No export endpoint, private feed token, external calendar
write, following relationship or delivery engine is implemented.

The UI provides desktop Month/Week/Day/Agenda, mobile agenda/day navigation,
permission-derived creation/editing and allowed organization/unit/team/season/
child/type/location/date filters. Team names accompany colors. No later business
module is implemented by event-type labels, game details or Calendar activation.
