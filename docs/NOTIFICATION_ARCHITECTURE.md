# Boss notifications core

Phase 4A uses one canonical notification pipeline for Calendar, Registration,
offline fees and Communications. It implements no fundraising, Boss Bucks,
processors, SMS or push transport. Deployment and acceptance evidence belong in
CURRENT_BUILD_STATE.md.

`notification_events` holds the source module/entity, event type, revision,
occurrence/scheduling context and fixed-template reference. It never copies chat
bodies, medical answers, private document paths, review reasons or check references.
`notifications` holds one recipient projection and read timestamp per event/person.
`notification_deliveries` holds independent per-channel state. The original message
or business record remains canonical. The private type catalog provides generic
safe title/body templates without youth/contact or document content.

Source integration happens inside the original authorized transaction. A whitelist
audit trigger captures event create/material change/cancellation, registration
submission/approval/denial/waitlist, document approval/rejection, offline recording
and charge creation. A communication-message trigger captures one new message or
announcement. Existing operation-receipt replays do not repeat these changes.
Unrecognized audit actions generate no work. A narrow Calendar trigger records
only a material-change Boolean for fields missing from historical audit projections.
It captures no descriptions, instructions or private content.

Material Calendar changes include start/end, timezone, arrival, venue/resource,
recurrence, status and target-set changes. Title/description-only edits do not
generate reschedule alerts; reordering the same target set is not material.
Occurrence exceptions compare their effective time/status. Rescheduling/cancellation
cancels superseded scheduled reminder work. Configured reminders retain the actual
reminder identity, offset and original occurrence key; enabled state, configured
audience and effective occurrence time are checked again before receipt.

Ingestion creates a private expansion job. Each processing operation examines at
most 100 candidate people and ten jobs, using `FOR UPDATE SKIP LOCKED`; continuation
stores a UUID cursor. Each recipient branch seeks after that cursor, qualifies active
authenticated identities before its own 100-person limit and combines the bounded
pages with UNION deduplication before the final page limit. Tenant/person indexes
support these seeks. Platform-only roles are not a subscription branch. Unique event/source/revision and event/person constraints
deduplicate one underlying change even through two children, multiple teams or
roles. An initial bounded page runs during source mutation; a protected signed
`delivery.process` command continues pending work. Inbox GET never performs worker
mutations. This is an operator-driven foundation, not an installed scheduler or
privileged external worker.

Current source visibility and relationship windows are enforced at expansion and
every inbox/unread projection. Tenant-role recipients must have an actual matching
organization/unit/team assignment that existed by the source time. Global read
capability alone never subscribes someone to every tenant. Direct/group recipients
need explicit current thread membership present by source time. Guardians need the
new explicit communications-receive capability for chat/calendar; the existing
registration/payment capabilities authorize their corresponding transactional
receipts only. Household membership is never substituted. Account status,
confirmed nonanonymous identity and current person state also qualify recipients.
Role, membership and guardian records must also have been created by source time;
backdating a newly inserted starts/verified window cannot grant older queued work.
This is not complete historical authorization reconstruction: prior mutable flag
values are not reconstructed. Dated windows and record creation, together with
current capability and source context, authorize pending work. Generic updated_at
is not treated as capability provenance because unrelated metadata edits do not
break continuous authority.
Removing authority hides prior private inbox entries and unread counts immediately.
Calendar CTAs include canonical timezone and original finite occurrence key; the
date follows the current effective exception start, preserving the correct identity
when a recurring instance moves onto another day. Forged CTA URLs still pass through
the destination route's source authorization.

Missing-requirement/deadline reminders recheck current registration status and
requirements. Fee due/upcoming/overdue reminders recheck active charges, current
balance and due date. Reminder generation is bounded to a seven-day requested
window within a 32-day horizon, 50 event/configuration combinations, 20 occurrences
per combination and 100 scheduled source events per command. Canonical date/recurrence
and active exception windows filter reminder configurations before their source
limit, so expired events do not consume the bounded current-window scan.

Preferences support channel/category with global, organization and exact-team
context. Exact team overrides organization, then global; absence defaults enabled.
All currently integrated alerts are optional. A private, fixed mandatory-policy
path can preserve an operational/security notification if a future approved policy
requires it; no current category is invented as legally mandatory and clients
cannot supply that flag. SMS and push are displayed as future availability only.

Raw public tables have RLS and no authenticated mutation/read grants. Public
invoker RPCs delegate to private caller-bound projections/mutations. Arbitrary-
recipient helpers and expansion functions are closed to API callers. Reads provide
recent bounded inbox, aggregate unread count, self preferences and scoped safe
delivery history. Summary availability reflects actual currently authorized enabled
organizations/current source receipts, so disabled modules hide the drawer and
notification navigation. Global self preferences remain a callable foundation.
History requires organization delivery-history permission and
omits emails, provider references, private payloads and bodies. Mutations use
verified identity, finite fields, same-source authority, transaction/advisory lock,
input hash and request receipt. Processing and reminder commands are audited with
operation IDs only.

Indexes cover recent inbox/unread predicates, tenant history, ready work and all
foreign keys. Unread counts are database aggregates, not UI-derived guesses. A
failed expansion page rolls back that page, persists safe attempt/backoff state and
stops after five failures. Successful bounded pages reset the failure counter; they
can continue a finite large audience without treating pagination as a failure.

See EMAIL_DELIVERY_ARCHITECTURE.md for the truthful unconfigured email boundary and
provider-independent idempotency/retry contract. The test suite uses synthetic
people, `.invalid` addresses and local PostgreSQL only.
