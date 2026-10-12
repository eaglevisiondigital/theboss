# Registration architecture: Phase 3B

This document describes the implementation contract. Deployment, acceptance and
advisor evidence is recorded in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).
It does not authorize a later module or add product rules beyond Phase 3B.

## Canonical records and context

An offering belongs to one organization and immutable organization, exact unit or
exact team scope. It can reference an existing same-tenant season and Calendar
event. `registration_type` is a reusable label rather than a sports-specific table;
`participant_type` must match the actual canonical participant. Dates, age/grade
bounds, capacity, waitlist, approval, visibility and assignment prerequisites are
finite configuration. Organization-unit scope reaches only the exact unit and its
directly attached teams. Offering/event association confers no scheduling power.

Registration reuses a persistent `participants.id`; returning participants are
confirmed rather than copied. A participant need not have Auth credentials.
Actual self authority or current verified guardian `can_register` is required to
start/save/submit. Optional household context requires both actor and participant
to be current household members; membership alone cannot authorize a dependent.
Staff capability cannot impersonate a family response or consent.
Restricted offering start additionally requires scoped `registration.create`.
Member offerings require actual current organization membership of the actor or
participant, or that scoped capability. Seeing a published offering is not itself
permission to start it.

Start freezes offering settings, linked form/waiver/document versions, required
active fee rules and participant/family identity context. It creates a saved draft
and required document metadata, without a roster or payment. Later published
versions affect future registrations. Draft context is bounded to grade and the
payment-plan/travel-team Boolean selections. Canonical identity remains separate
from the frozen registration evidence.

## Workflow and capacity

Registration statuses are `draft`, `submitted`, `under_review`, `approved`,
`denied`, `waitlisted`, `withdrawn`, `canceled` and `archived`. Forms, waiver,
document, eligibility, approval and roster have independent states. Payment status
is computed from financial records. Submission requires finalized required forms
and signatures; documents and payment can remain pending.

An offering defaults to approval required. Explicitly disabling that setting can
approve a complete submission, but still creates no team membership or role.
Review records canonical reviewer, time and optional reason. Eligibility changes
require review permission and a reason. Assigned registrations must undergo an
explicit roster removal before withdrawal, denial, waitlisting or cancellation.
There is no submitted-response rewrite or automatic correction/reopening workflow.

Submitted, under-review and approved rows reserve capacity. Drafts and waitlists
do not. One offering lock serializes submissions, review transitions, promotion,
releases and capacity changes. A physical owner-row update forces stale
REPEATABLE READ/SERIALIZABLE transactions to fail safely instead of counting an
old snapshot. Capacity cannot be lowered below existing reservations. Waitlist
positions are monotonic under that same lock; promotion rechecks current capacity.
Required obligations are created at submission, including a waitlisted submission;
this does not collect money or automatically refund/cancel an obligation later.

`registration.assign_team` requires offering `registration.manage` plus actual
`team.roster.manage`, same tenant and authorized exact target, applicable season
and configured approval/eligibility/document/payment prerequisites. The default
policy is manual with approval required. It inserts the existing canonical athlete
team relationship, never a role. Current team/participant anchors and duplicate
checks prevent concurrent duplicate assignment. `registration.remove_team` ends
the exact relationship and retains registration/history; retries reauthorize the
original audited team context.

## Authenticated interface

`boss_registration_read(p_query jsonb)` returns finite authorized projections for
family/admin lists, offerings, definitions, contextual selectors and one drilldown.
Organization, offering and registration filters narrow existing authority. Lists
contain workflow status, label and date information; detailed amounts/receipts,
forms and documents require their independent authority. Medical answers are
suppressed in ordinary detail and retrieved only through audited `form.access`.

`boss_registration_mutate(p_request_id uuid, p_command jsonb)` accepts
`{operation,input}`. The public function is an invoker wrapper around a private
dispatcher that verifies the current confirmed non-anonymous Auth user, live owned
session and active canonical identity. Every command checks current module,
feature, tenant, exact scope and applicable guardian capability inside PostgreSQL.
Strict fields and types reject caller/role/tenant authority supplied in payloads.

| Command family | Implemented actions |
| --- | --- |
| Offering/configuration | Upsert fixed-scope offering, publish, finite feature settings |
| Definition/version | Publish form/waiver; append document requirement version; configure fee/coupon |
| Family | Start/save/submit/withdraw, draft/final form answer, actual waiver signature |
| Review/roster | Decision, eligibility, explicit assignment and removal |
| Documents/sensitive | Session-bound intent/completion, review, audited document/form/emergency access |
| Finance | Explicit charge/create/adjust/cancel, cash/check allocation, plan create/cancel |

Mutation JSON is bounded to 65,536 bytes. Mutable registration/offering/document/
answer configuration uses optimistic versions; stale input returns a safe conflict.
Successful generic results contain request/resource identifiers and version.
Private actor/request receipts compare canonical input hashes, serialize retries
and reauthorize before returning the original result. Sensitive reads audit each
access and bypass receipt storage. Failure rolls back records, receipts and audits.

Hosted mutation, binary upload/download and sensitive routes use verified user
clients and same-origin checks; no service key is needed. Upload/download/sensitive
operations use dedicated routes, whose result projections do not pass private
paths or medical bodies through a generic mutation response. Authenticated pages
and responses retain the existing private cache boundary.

## Bounded foundation

There is no automatic team assignment, role granting, age-derived consent policy,
payment-plan collection, waiver PDF generation, reminder delivery, wallet debit,
processor settlement or automatic discount engine. Feature/role catalog mappings
are potential capability only. Registration does not implement Fundraising,
Money Board, commerce, messaging or a later phase.

See [Permissions](PERMISSIONS_MODEL.md), [Forms/waivers](FORMS_WAIVERS_ARCHITECTURE.md),
[Private documents](DOCUMENT_SECURITY.md) and [Finance](FEES_CHARGES_ARCHITECTURE.md).
