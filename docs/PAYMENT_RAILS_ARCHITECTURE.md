# Phase 7D payment rails

Status: IN PROGRESS. Starting head `dc55c6cb2f9dc11c0b111b5783a4ec174721c361`.
Canonical baseline was 95; six tested migrations are applied, history 101. No operational processor account or private worker is provisioned.

## Historical pre-resolution checkpoint

The following checkpoint description predates the binding financial resolution.
Current local execution, settlement, corrections, signed UI and worker contracts
are implemented and undergoing final release validation. No operational payment
worker/account is provisioned.

This was a local design/checkpoint, not a completed execution implementation.
Only processing/checkout schema, private reservation/authority helpers and
provider contract adapters exist so far. Financial commit, settlement ledger,
refund/dispute integration, signed projections/UI and operational worker remain
unfinished. Later paragraphs describe the proposed design to be validated.

Main Boss Chat financial direction is required before implementing the
fundraising success bridge or releasing Phase 7D. The existing Phase 7A contract
requires a real settled timestamp and an unexpired intent/reservation, while
card capture precedes settlement and ACH/unknown outcomes may outlast expiry.
The requested decision covers capture-versus-settlement success, preservation
or expiry of pending eligibility, and late-success refund/review versus completion
from pre-expiry eligibility. No capture is relabeled as settlement; no expired
intent/tile authority is extended. See [checkpoint](PHASE_7D_CHECKPOINT.md).

Boss charges, payment allocations, fundraising intents, trusted successes,
Money Board claims and Boss Bucks journals remain canonical. Provider adapters
execute finite operations and return allowlisted evidence. They never decide
tenant authority, fees, allocation, wallet recovery or organization payable.

Processing accounts explicitly identify organization, provider, environment,
country/currency, merchant owner, settlement mode and verified capabilities.
Versioned exact organization/campaign/team/unit routes are selected from current
canonical context. No name matching, descendant inheritance or cross-organization
fallback. Secrets remain in approved server infrastructure; private database
bindings contain handles and verification metadata only. No secret, worker login,
production environment variable or merchant account is created by this release.

Checkout is a durable attempt, not a payment. One primary provider operation is
persisted and marked dispatched before the external call. A timeout is UNKNOWN;
no automatic redispatch or new operation identity is allowed. Provider request
references correlate polling/webhooks; they are not claimed to provide native
provider idempotency. Bounded reconciliation must resolve uncertain outcomes.

At preparation, exact canonical charges and FEFO grant slices are reserved under
the existing charge/wallet fences. Reservations have a fixed expiry, do not post
wallet debits or count as charge payments, and reduce competing availability.
Failure/cancellation/expiry release them. A late/unknown success is always retained
as provider evidence and one canonical payment; if current authority, due, source
validity or reservation cannot support full commitment, it remains captured and
unallocated for authorized refund/reconciliation. It never overpays or invents
replacement value. ACH acceptance remains pending; no canonical successful tender
or permanent Boss Bucks debit is committed merely from submission acceptance.

Private completion uses the same Phase 7C accounting implementation and original
actor/context. It checks current identity/relationship/module validity without
constructing a JWT or storing/extracting a browser session. Signed requests keep
the existing live Auth/session and same-origin checks. Worker routines are closed
to public, anon, authenticated and service_role; a NOLOGIN worker role receives
only finite routine execution. Operational worker credentials remain unconfigured.

Guest fundraising uses its existing intent/donor identity, not a fabricated Boss
person. Card/ACH extensions allow that context while preserving non-null signed
actor/payer requirements for prior cash/check/Boss Bucks records. Provider success
feeds the existing private trusted-success function exactly once. Expired or
changed campaign/tile context is held for reconciliation, not bypassed.

Refunds explicitly select original tender/allocation legs. No arbitrary refund,
unattached credit or automatic tender choice. Each external leg has one durable
dispatch; its verified effect appends canonical payment/allocation reversals.
Boss Bucks legs use the Phase 7C original/replacement-grant recovery-release rule.
Mixed refunds are a durable saga, with unresolved legs visible rather than an
assertion of network-wide atomicity. Disputes and ACH returns are separate evidence
types and share canonical source invalidation and settlement adjustment paths.

Saved methods are revocable provider/account/person-or-donor references. Raw PAN,
CVV, routing/account numbers, authorization headers, full provider bodies and
collection nonces are neither stored nor logged. Recurring work references existing
occurrences and explicit consent; automatic scheduling/autopay is inactive.

Evidence levels remain LOCAL CONTRACT/RUNTIME, PROVIDER SANDBOX and PRODUCTION
CONTROLLED. Without an approved provider account, positive provider evidence is
unavailable. Deployment alone never authorizes real money movement. Phase 7E and
membership/merchant products are out of scope.

## Binding continuation decision, October 7, 2026

Main Boss Chat resolved the earlier holds recorded above. Those paragraphs are
historical checkpoint context, superseded by this section and the amendment in
[FUNDRAISING_ARCHITECTURE.md](FUNDRAISING_ARCHITECTURE.md). Verified card capture is
payment/fundraising success before settlement; authorization is not. ACH pending
and unknown outcomes hold resources durably after short expiry, never create
success or trigger a new charge automatically. Submission commits immutable
eligibility, exact account/attempt/routing/settlement and reward/earning revisions.
Natural expiry preserves that in-flight eligibility; explicit terminal
invalidation/cancel/release routes later money to canonical unallocated review.

Local dependent execution, settlement and correction implementations are under
validation. Settlement sources are exactly once per canonical tender. Missing
policy/actual fee evidence holds attribution. Provider settlement never duplicates
payment, fundraising progress or earnings; direct-provider sources cannot request
a second Boss payout. Refund-before-settlement uses remaining principal/gross,
not the original already-refunded economic amount. Source corrections preserve
original capture chronology and the existing Phase 7C earning recovery chain.
No live-provider or release-completion claim is made by these local checks.
