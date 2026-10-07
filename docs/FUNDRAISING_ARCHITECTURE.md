# Fundraising core — Phase 7A

Status: Phase 7A COMPLETE. Canonical migration, release, full validation and one
controlled hosted non-payment acceptance window with explicit cleanup passed.
See PHASE_7A_COMPLETION_REPORT.md and PHASE_7A_ACCEPTANCE_ADDENDUM.md for evidence
classification and the financial execution boundary.
Starting checkpoint: `da001f8b9402b48ca74e80e133946fe2f62522ed`.

## Canonical ownership and modules

The existing `fundraising` catalog key controls organization availability.
`money_board` remains independently enabled and requires a live Fundraising
campaign. Neither enables Sports, Calendar, Messaging, Engage or Boss Bucks.
The existing live-auth guard is reused as a session check; it does not require a
Sports module. Canonical participants and people are reused for sports and
non-sport organizations. Seasons and athlete profiles are not prerequisites.

Campaigns retain organization, currency, integer goal, dates, publication, exact
selected targets, channels, branding and policy. One campaign can target several
teams or exact units. There is no descendant-unit inheritance. Multiple campaigns
can overlap, with one canonical fundraiser per participant/campaign. Campaign
creation, enrollment and consequential changes use caller-bound request receipts.
Enrollment batches contain 1–200 existing, context-eligible participants per RPC.

Lifecycle is draft, scheduled, active, paused, completed, canceled or archived.
Scheduled publication becomes effective only at its authoritative start time;
end time, paused/closed status and module expiry deny new supporter activity.
Archiving preserves immutable history and evidence, ends participation, revokes
shares, archives boards, releases reservations and cancels unpaid intents/planned
commitments. Already confirmed value remains historical evidence.

Executable channels are direct support and Money Board. Digital/physical card
channel references are future, nonoperational configuration. Public website
intake remains unchanged; campaign fields support organization/type, goals,
channels, launch timing and participation without making intake an authority grant.

## Identity, scope and family authority

A fundraiser records persistent participant/person identity and originating
organization, exact unit/team and optional household context. Contributions keep
that snapshot even after a participant moves. Household membership never grants
fundraising authority. `can_manage_fundraising` is an explicit guardian capability,
false for every preexisting and new relationship unless deliberately granted.
Accept/share operations require current verified authority and eligible campaign,
organization and team relationships. Existing medical, waiver, document, payment
and profile capabilities do not substitute. Communication receipt is separately
controlled by existing `can_receive_communications`.

Eligible adult self-sharing requires campaign opt-in and a verified canonical age
fact of at least 18; an Auth account alone or missing DOB grants nothing. No
production DOB is manufactured for acceptance. Family reads expose only authorized
child/campaign contexts, with Whole Family, child, campaign and organization filters.
The organization/team view separately checks real role scope and current membership.

Potential permission keys are `fundraising.view/create/manage/publish/financial_view`
and `money_board.view/manage`. Super/platform and organization owner/administrator
mappings supply management potential. Directors/program/sport/team leaders and
head coaches receive progress-view potential; team sharing additionally requires
campaign policy and a current accepted share. Finance mappings supply reporting
potential, with private contact/source reporting separately gated. Exact unit/team
assignments and relationship checks remain mandatory; names never authorize access.

## Public publication and attribution

Random 48-character share paths bind canonical fundraiser attribution. They are
separate from internal resource IDs. Reset revokes the old path for new activity
without changing previous intent/evidence attribution. QR is generated from the
canonical URL with an explicit QR source marker, not stored as authoritative
identity. Campaign and organization/team board paths support nonparticipant flows.
Participant shares remain nonindexable. Campaign indexing is explicit opt-in.
There is no public child directory or private profile projection.

Public RPCs expose only campaign/organization branding, approved fundraiser name,
team label, goals/confirmed progress, paged tiles and limited public supporter
presentation. They exclude private profile/DOB, guardian/household details,
internal IDs, donor contacts, source references and administration data. Branding
is plain text and controlled HTTPS URL configuration, never executable HTML/CSS.
The anonymous schema contains only narrowly defined projection/support operations;
PUBLIC execute is revoked and the established private schema stays private.

## Guest donors and contribution intents

Donors are separate guest identities: display name, optional email/mobile and an
anonymous-display preference. Contact matches never create or merge Boss accounts.
Any later account linkage requires a verified, explicit linking process.

An immutable intent binds campaign, participant/fundraiser, organization/unit/team,
share/QR source, optional board/tile/reservation, donor, amount/currency, fee-cover
preference and a reward-policy snapshot. The public path derives attribution;
forged participant/team/board identifiers are rejected. Tile price comes from the
canonical tile, regardless of a submitted alternate amount. Request receipts bind
input hashes and supporter capability hashes. Capability plaintext is not persisted
in database receipts, audit events, URLs or reports.

Current customer state is `awaiting_payment`, followed by explicit unpaid
cancellation/expiry behavior. There is no processor, automatic charge, card/ACH
field or customer-success endpoint. Future verified processing/failure/refund,
partial-refund/chargeback states require a reviewed trusted adapter. A pending,
reserved or abandoned intent is never raised value.

## Trusted success and financial provenance

`boss_private.fundraising_ingest_success` is closed to PUBLIC, anon,
authenticated and service_role. There is no browser mark-paid, simulation or test
payment endpoint. A future adapter must verify provider evidence before receiving
explicit execution authority. Current paid-state testing uses disposable SQL
fixtures only; hosted paid progress and reward qualification remain SQL/RUNTIME
VERIFIED unless separately reviewed trusted evidence is available.

Success requires exact intent amount/currency, unique source system/reference,
valid settled timestamp, current campaign context and an unexpired unpaid
reservation where applicable. Retries return the same immutable evidence; conflicts
fail. Campaign/participant/team/board progress derives solely from success evidence,
not editable balances or estimates. Goal/full-board events are deduplicated against
canonical evidence. Low-frequency publication, enrollment, trusted success and
milestone notifications reuse Phase 4A without enabling another module or provider.
Reservations generate no notifications.

Success retains originating identity/scope, donor, source, amount/currency,
fee-cover preference, reward policy and restricted-use organization. Intent events
provide immutable source-event and amount lineage for later verified refunds,
partial refunds, chargebacks and reversals. A later reversal must append trusted
adjustment evidence and explicitly recompute progress, reward eligibility, paid-tile
policy and any subsequently created wallet dependencies. Phase 7A implements no
processor refund execution or ordinary reopening of paid tiles.

Receipt metadata exists through donor, scope, amount, date and source evidence.
No payment receipt, tax deduction or charitable status is asserted without actual
payment execution and reviewed organization language.

## Recurrence and rewards

Monthly commitments span 6–12 planned occurrences. The chosen amount is per month;
the first authoritative successful installment claims a selected tile permanently.
Future unpaid occurrences are plans and never count toward raised totals. No
scheduler charges a donor. Fee cover is a preference only; no fee quote is invented.

A campaign can snapshot currency, integer threshold, strict `gt` comparison and
30/60/90-day trial duration. Under the approved USD threshold 2500, 2500 does not
qualify and 2501 does. Qualification records `not_qualified` or `gift_pending` with
immutable source provenance. No wallet credit, balance, entitlement fulfillment,
merchant discount, geography tier or physical inventory is created. A future
physical-card product may reference a 90-day digital trial without executing it.

Later wallet work must consume unique verified contribution/reward evidence,
preserve household/participant/origin/restricted-use scope and record dependency
lineage so reversals can be coordinated safely. Phase 7B remains unstarted.

## Transaction, security and scale contract

Locks proceed campaign → fundraiser → board → tile/reservation → intent. Module,
role and applicable membership/guardian rows are fenced, then authorization is
checked again against current clock time. Guest requests are canonically rate
limited, including direct Data API calls; same-tile contention has one winner.
Raw fundraising/donor/board/tile/intent/evidence tables have RLS and no direct
browser table privileges. Private receipts/rate/milestone tables are also closed.
Immutable source rows reject update, delete and truncate. Every new FK has an
index and every private/public helper uses an empty qualified search path.

Reads are paged and bounded; no donor PII is in public or coach views. Private
financial reporting requires its own permission. Initial operational ceilings
(200 enrollment items, 50 campaign page, 200 participant page, 100 public tiles,
10,000-tile generation batches, bounded page sizes and exact integer amounts) are
explicit request/storage safety boundaries, not inferred from campaign goals or
performance fixture size. No statement timeout is increased.


Generation uses at most 10,000 tiles per request and can continue the same
unpaid generation. Partial generations cannot publish. 100,000 is the validated
performance scale, not a product board-size ceiling. Integer storage and exact
JavaScript minor-unit projection bounds apply. Board configuration changes
create a new immutable generation only before settled claims/current reservations.
Leaderboards default off; public participants additionally require current
approved display/share and explicit guardian/adult opt-in. Exact program views
and participant cursors retain bounded payloads.


Authorized CSV/export handoff: explicit organization/campaign/team/unit filters,
role-authorized rows, cursor pagination and a bounded request. Default columns
are campaign, scope, approved participant display, currency, confirmed gross,
count/average and board state. Donor email/mobile/source reference require
`fundraising.financial_view`; finance reads audit the access. No raw public donor
export is supported. Escaping must quote CSV and neutralize spreadsheet formula
prefixes when a later downloadable exporter is enabled. Current reporting uses
bounded canonical JSON projections, not a bulk national scan.

Recurring schedule cancellation follows unpaid intent/campaign cancellation.
Planned installments are non-executable and do not count as financial value.
Intake creates canonical people/participants through existing approved workflows;
Fundraising enrolls those identities without replacing or copying youth profiles.


## Phase 7B wallet boundary

Phase 7B consumes typed trusted success evidence directly. Each new intent snapshots an immutable none/percentage policy and explicit authorized household binding. Unknown owners hold issuance; private exact-source owner resolution appends evidence without changing the captured policy. Unpaid intents, reservations and future recurring installments issue no value. Supporter trial/gift qualification remains separate; configured pages show only a finite may-earn indicator.

See [wallet architecture](BOSS_BUCKS_WALLET_ARCHITECTURE.md).

## Phase 7C integration (October 7, 2026)

Phase 7C source corrections use cumulative remaining authoritative gross and captured earning basis points, retaining immutable original success/policy/person/campaign/team/unit provenance. Original invalid source value is never resurrected by payment returns. Canonical trusted sources remain absent at release; no fake paid fundraising, wallet grant or provider evidence may be manufactured.

See [Boss Bucks payments and split tender](BOSS_BUCKS_PAYMENTS_SPLIT_TENDER_ARCHITECTURE.md) and [Phase 7C validation](PHASE_7C_VALIDATION.md). Historical phase statements above remain historical.
